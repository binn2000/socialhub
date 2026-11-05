<?php

namespace App\Support;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Finds videos on YouTube (YouTube Data API v3) for the "Video" tab. Only the video id and some text
 * are passed on: the clients play it with YouTube's own embedded player, nothing is downloaded.
 *
 * Quota (free tier, 10,000 units a day): a search costs 100 units, listing details or the most popular
 * videos 1 unit, so every answer is cached for an hour and the route is rate limited.
 */
class VideoCatalog
{
    private const API = 'https://www.googleapis.com/youtube/v3';

    /** A YouTube video id is exactly 11 URL-safe characters. */
    public static function isVideoId(string $id): bool
    {
        return (bool) preg_match('/^[A-Za-z0-9_-]{11}$/', $id);
    }

    /**
     * @return array{data: list<array{id: string, title: string, channelTitle: string, thumbnailUrl: ?string, publishedAt: ?string, durationSeconds: ?int}>, nextCursor: ?string}
     *
     * @throws VideoUnavailable
     */
    public static function search(string $query, ?string $cursor = null): array
    {
        $query = trim($query);

        return Cache::remember('video:'.md5(mb_strtolower($query).'|'.$cursor), 3600, function () use ($query, $cursor) {
            if ($query === '') {
                // No search words: what is popular in the configured country (1 quota unit instead of 100).
                $body = self::call('/videos', [
                    'part' => 'snippet,contentDetails', 'chart' => 'mostPopular', 'maxResults' => 20,
                    'regionCode' => config('services.youtube.region'), 'pageToken' => $cursor,
                ]);

                return ['data' => self::present($body['items'] ?? []), 'nextCursor' => $body['nextPageToken'] ?? null];
            }

            $found = self::call('/search', [
                'part' => 'snippet', 'type' => 'video', 'q' => $query, 'maxResults' => 20, 'safeSearch' => 'moderate',
                'regionCode' => config('services.youtube.region'), 'relevanceLanguage' => 'vi',
                'videoEmbeddable' => 'true', 'pageToken' => $cursor,
            ]);

            $ids = collect($found['items'] ?? [])->pluck('id.videoId')->filter(fn ($id) => is_string($id) && self::isVideoId($id))->values();
            // The search answer has no duration; one more cheap call adds it (and drops anything not playable).
            $details = $ids->isEmpty() ? [] : self::call('/videos', [
                'part' => 'snippet,contentDetails,status', 'id' => $ids->implode(','), 'maxResults' => 20,
            ])['items'] ?? [];

            return ['data' => self::present($details), 'nextCursor' => $found['nextPageToken'] ?? null];
        });
    }

    /** @return list<array<string, mixed>> */
    private static function present(array $items): array
    {
        return collect($items)
            ->filter(fn ($item) => is_string($item['id'] ?? null) && self::isVideoId($item['id'])
                && ($item['status']['embeddable'] ?? true) !== false)
            ->map(fn ($item) => [
                'id' => $item['id'],
                'title' => (string) ($item['snippet']['title'] ?? ''),
                'channelTitle' => (string) ($item['snippet']['channelTitle'] ?? ''),
                'thumbnailUrl' => self::thumbnail($item['snippet']['thumbnails'] ?? []),
                'publishedAt' => $item['snippet']['publishedAt'] ?? null,
                'durationSeconds' => self::seconds($item['contentDetails']['duration'] ?? null),
            ])->values()->all();
    }

    /** Only pictures hosted by YouTube are passed on. */
    private static function thumbnail(array $thumbnails): ?string
    {
        foreach (['medium', 'high', 'default'] as $size) {
            $url = $thumbnails[$size]['url'] ?? null;
            $host = is_string($url) ? parse_url($url, PHP_URL_HOST) : null;
            if ($host && (str_ends_with($host, '.ytimg.com') || $host === 'ytimg.com') && str_starts_with($url, 'https://')) {
                return $url;
            }
        }

        return null;
    }

    /** "PT1H2M3S" -> 3723. */
    public static function seconds(?string $iso): ?int
    {
        if (! $iso || ! preg_match('/^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/', $iso, $m)) {
            return null;
        }

        return ((int) ($m[1] ?? 0)) * 86400 + ((int) ($m[2] ?? 0)) * 3600 + ((int) ($m[3] ?? 0)) * 60 + (int) ($m[4] ?? 0);
    }

    /** @throws VideoUnavailable */
    private static function call(string $path, array $params): array
    {
        $key = config('services.youtube.key');
        if (! $key) {
            throw new VideoUnavailable('YouTube is not configured.');
        }

        try {
            $response = Http::timeout(8)->acceptJson()->get(self::API.$path, array_filter($params, fn ($v) => $v !== null && $v !== '') + ['key' => $key]);
        } catch (ConnectionException $e) {
            throw new VideoUnavailable($e->getMessage(), 0, $e);
        }

        // 400/403 cover a bad key, a disabled API and the daily quota; none of them is the user's fault.
        if (! $response->ok() || ! is_array($response->json())) {
            throw new VideoUnavailable('YouTube answered '.$response->status().'.');
        }

        return $response->json();
    }
}
