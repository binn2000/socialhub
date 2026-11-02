<?php

namespace App\Support;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Songs with a 30-second preview from the Apple Music / iTunes catalogue, plus the link to the same
 * song on Spotify when Spotify is configured. Everything a note or story shows is looked up here by
 * track id, never taken from the client, so only real catalogue previews can be attached.
 */
class MusicCatalog
{
    private const ITUNES = 'https://itunes.apple.com';

    private const SPOTIFY_API = 'https://api.spotify.com/v1';

    private const SPOTIFY_TOKEN = 'https://accounts.spotify.com/api/token';

    /** Hosts a preview, artwork or song link may come from. */
    private const TRUSTED_HOSTS = ['apple.com', 'mzstatic.com'];

    /**
     * @return list<array{id: string, title: string, artist: string, artworkUrl: ?string, previewUrl: string, appleMusicUrl: ?string, spotifyUrl: null}>
     *
     * @throws MusicUnavailable
     */
    public static function search(string $query): array
    {
        return Cache::remember('music:search:'.md5(mb_strtolower(trim($query))), 3600, function () use ($query) {
            $body = self::itunes('/search', [
                'term' => trim($query), 'media' => 'music', 'entity' => 'song', 'limit' => 20,
                'country' => config('services.music.country'),
            ]);

            return self::tracksFrom($body);
        });
    }

    /**
     * One song by its catalogue id, or null when it does not exist (or has no usable preview).
     *
     * @throws MusicUnavailable
     */
    public static function lookup(string $id): ?array
    {
        if (! preg_match('/^\d{1,20}$/', $id)) {
            return null;
        }

        $track = Cache::remember("music:track:$id", 86400, function () use ($id) {
            $body = self::itunes('/lookup', ['id' => $id, 'entity' => 'song', 'country' => config('services.music.country')]);

            return self::tracksFrom($body)[0] ?? false;
        });

        return $track ?: null;
    }

    /** The song with its Spotify link added when it can be found (never fails). */
    public static function withSpotify(array $track): array
    {
        $track['spotifyUrl'] = self::spotifyLink($track['title'], $track['artist']);

        return $track;
    }

    /**
     * The song on Spotify. When Spotify is configured but will not answer (its Web API needs the app
     * owner to have Premium), the link is a Spotify search for the song, which needs no API.
     */
    private static function spotifyLink(string $title, string $artist): ?string
    {
        $match = self::spotifyMatch($title, $artist);
        if ($match !== null || ! config('services.spotify.client_id') || ! config('services.spotify.client_secret')) {
            return $match;
        }

        return 'https://open.spotify.com/search/'.rawurlencode(trim("$title $artist"));
    }

    /** Presents the track columns of a note or story, or null when it has no song. */
    public static function present($model): ?array
    {
        if (! $model->track_id) {
            return null;
        }

        return [
            'id' => $model->track_id,
            'title' => $model->track_title,
            'artist' => $model->track_artist,
            'artworkUrl' => $model->track_artwork_url,
            'previewUrl' => $model->track_preview_url,
            'appleMusicUrl' => $model->track_apple_url,
            'spotifyUrl' => $model->track_spotify_url,
        ];
    }

    /** The columns that store a looked-up song on a note or story. */
    public static function columns(?array $track): array
    {
        return [
            'track_id' => $track['id'] ?? null,
            'track_title' => $track['title'] ?? null,
            'track_artist' => $track['artist'] ?? null,
            'track_artwork_url' => $track['artworkUrl'] ?? null,
            'track_preview_url' => $track['previewUrl'] ?? null,
            'track_apple_url' => $track['appleMusicUrl'] ?? null,
            'track_spotify_url' => $track['spotifyUrl'] ?? null,
        ];
    }

    private static function http(): PendingRequest
    {
        return Http::timeout(5)->acceptJson();
    }

    /** @throws MusicUnavailable */
    private static function itunes(string $path, array $query): array
    {
        try {
            $response = self::http()->get(self::ITUNES.$path, $query);
        } catch (ConnectionException $e) {
            throw new MusicUnavailable($e->getMessage(), 0, $e);
        }

        // iTunes answers with a javascript content type, so decode the body ourselves.
        $body = json_decode($response->body(), true);
        if (! $response->successful() || ! is_array($body)) {
            throw new MusicUnavailable("iTunes answered {$response->status()}");
        }

        return $body;
    }

    private static function tracksFrom(array $body): array
    {
        $tracks = [];
        foreach ($body['results'] ?? [] as $item) {
            $preview = $item['previewUrl'] ?? null;
            if (($item['wrapperType'] ?? 'track') !== 'track' || ! self::trusted($preview) || empty($item['trackId'])) {
                continue;
            }

            $artwork = $item['artworkUrl100'] ?? null;
            $apple = $item['trackViewUrl'] ?? null;
            $tracks[] = [
                'id' => (string) $item['trackId'],
                'title' => mb_substr((string) ($item['trackName'] ?? ''), 0, 200),
                'artist' => mb_substr((string) ($item['artistName'] ?? ''), 0, 200),
                'artworkUrl' => self::trusted($artwork) ? str_replace('100x100bb', '300x300bb', $artwork) : null,
                'previewUrl' => $preview,
                'appleMusicUrl' => self::trusted($apple) ? $apple : null,
                'spotifyUrl' => null,
            ];
        }

        return $tracks;
    }

    private static function trusted(mixed $url): bool
    {
        if (! is_string($url) || strlen($url) > 500) {
            return false;
        }
        $parts = parse_url($url);
        $host = strtolower($parts['host'] ?? '');

        if (($parts['scheme'] ?? '') !== 'https' || $host === '') {
            return false;
        }
        foreach (self::TRUSTED_HOSTS as $trusted) {
            if ($host === $trusted || str_ends_with($host, '.'.$trusted)) {
                return true;
            }
        }

        return false;
    }

    private static function spotifyMatch(string $title, string $artist): ?string
    {
        $id = config('services.spotify.client_id');
        $secret = config('services.spotify.client_secret');
        if (! $id || ! $secret) {
            return null;
        }

        return Cache::remember('music:spotify:'.md5(mb_strtolower("$title|$artist")), 604800, function () use ($id, $secret, $title, $artist) {
            try {
                $token = Cache::remember('music:spotify-token', 3000, function () use ($id, $secret) {
                    $response = self::http()->asForm()->withBasicAuth($id, $secret)
                        ->post(self::SPOTIFY_TOKEN, ['grant_type' => 'client_credentials']);

                    return $response->successful() ? (string) $response->json('access_token') : '';
                });
                if ($token === '') {
                    Cache::forget('music:spotify-token');

                    return null;
                }

                $response = self::http()->withToken($token)->get(self::SPOTIFY_API.'/search', [
                    'q' => "track:$title artist:$artist", 'type' => 'track', 'limit' => 1,
                ]);
                $url = $response->successful() ? $response->json('tracks.items.0.external_urls.spotify') : null;

                return is_string($url) && str_starts_with($url, 'https://open.spotify.com/') ? $url : null;
            } catch (ConnectionException) {
                return null;
            }
        });
    }
}
