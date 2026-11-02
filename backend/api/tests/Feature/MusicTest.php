<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class MusicTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        // The developer's own keys in .env must not leak into the tests.
        config(['services.spotify.client_id' => null, 'services.spotify.client_secret' => null]);
    }

    private function song(int $id = 111, array $overrides = []): array
    {
        return $overrides + [
            'wrapperType' => 'track', 'trackId' => $id, 'trackName' => 'Em Của Ngày Hôm Qua', 'artistName' => 'Sơn Tùng M-TP',
            'artworkUrl100' => 'https://is1-ssl.mzstatic.com/image/thumb/Music/a/100x100bb.jpg',
            'previewUrl' => 'https://audio-ssl.itunes.apple.com/preview/'.$id.'.m4a',
            'trackViewUrl' => "https://music.apple.com/vn/album/x/1?i=$id",
        ];
    }

    private function fakeItunes(array $songs): void
    {
        Http::fake(['itunes.apple.com/*' => Http::response(json_encode(['resultCount' => count($songs), 'results' => $songs]), 200, ['Content-Type' => 'text/javascript'])]);
    }

    public function test_search_returns_songs_with_previews_and_uses_the_vietnamese_store(): void
    {
        $this->fakeItunes([$this->song(1), $this->song(2)]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $response = $this->getJson('/api/v1/music/search?q=Sơn Tùng')->assertOk();

        $this->assertCount(2, $response->json('data'));
        $first = $response->json('data.0');
        $this->assertSame('1', $first['id']);
        $this->assertSame('Em Của Ngày Hôm Qua', $first['title']);
        $this->assertStringEndsWith('300x300bb.jpg', $first['artworkUrl']); // a bigger picture
        $this->assertStringStartsWith('https://audio-ssl.itunes.apple.com/', $first['previewUrl']);
        $this->assertNull($first['spotifyUrl']);
        Http::assertSent(fn (HttpRequest $r) => str_contains($r->url(), 'country=VN') && str_contains($r->url(), 'entity=song'));
    }

    public function test_results_without_a_trusted_preview_are_dropped(): void
    {
        $this->fakeItunes([
            $this->song(1),
            $this->song(2, ['previewUrl' => 'https://evil.example.com/a.m4a']),
            $this->song(3, ['previewUrl' => 'http://audio-ssl.itunes.apple.com/a.m4a']), // not https
            $this->song(4, ['previewUrl' => 'https://notapple.com/a.m4a']),
            $this->song(5, ['previewUrl' => null]),
            $this->song(6, ['wrapperType' => 'collection']),
            $this->song(7, ['artworkUrl100' => 'https://evil.example.com/p.jpg', 'trackViewUrl' => 'https://evil.example.com/x']),
        ]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $ids = array_column($this->getJson('/api/v1/music/search?q=abc')->json('data'), 'id');
        $this->assertSame(['1', '7'], $ids);

        $seven = collect($this->getJson('/api/v1/music/search?q=abc')->json('data'))->firstWhere('id', '7');
        $this->assertNull($seven['artworkUrl']); // foreign pictures and links are not passed on
        $this->assertNull($seven['appleMusicUrl']);
    }

    public function test_search_is_cached_validated_and_limited(): void
    {
        $this->fakeItunes([$this->song(1)]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->getJson('/api/v1/music/search?q=Hello')->assertOk();
        $this->getJson('/api/v1/music/search?q=hello')->assertOk(); // same search, other case
        Http::assertSentCount(1);

        $this->getJson('/api/v1/music/search')->assertStatus(422);
        $this->getJson('/api/v1/music/search?q=a')->assertStatus(422);
        $this->getJson('/api/v1/music/search?q='.str_repeat('x', 101))->assertStatus(422);

        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/music/search?q=hello')->assertUnauthorized();
    }

    public function test_search_is_rate_limited(): void
    {
        $this->fakeItunes([$this->song(1)]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        foreach (range(1, 30) as $i) {
            $this->getJson("/api/v1/music/search?q=bai$i")->assertOk();
        }

        $this->getJson('/api/v1/music/search?q=quanhieu')->assertStatus(429);
    }

    public function test_an_unreachable_catalogue_is_a_503_and_is_not_cached(): void
    {
        Http::fake(['itunes.apple.com/*' => Http::sequence()
            ->push('boom', 500)
            ->push(json_encode(['results' => [$this->song(1)]]), 200)]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->getJson('/api/v1/music/search?q=hello')->assertStatus(503)->assertJsonPath('code', 'music_unavailable');

        $this->getJson('/api/v1/music/search?q=hello')->assertOk()->assertJsonCount(1, 'data');
    }

    // ---- notes with a song

    public function test_a_note_can_carry_a_song_looked_up_by_the_server(): void
    {
        $this->fakeItunes([$this->song(111)]);
        $me = User::factory()->create();
        $friend = User::factory()->create();
        Friendship::create(['requester_id' => $me->id, 'addressee_id' => $friend->id, 'status' => 'accepted']);
        $this->actingAs($me, 'sanctum');

        $response = $this->putJson('/api/v1/me/note', ['text' => 'Đang nghe', 'trackId' => '111'])->assertOk();

        $response->assertJsonPath('data.text', 'Đang nghe')->assertJsonPath('data.track.id', '111')
            ->assertJsonPath('data.track.title', 'Em Của Ngày Hôm Qua')
            ->assertJsonPath('data.track.previewUrl', 'https://audio-ssl.itunes.apple.com/preview/111.m4a');
        // the friend sees the same song
        $seen = $this->actingAs($friend, 'sanctum')->getJson('/api/v1/notes')->json('data.0');
        $this->assertSame('111', $seen['track']['id']);
    }

    public function test_a_note_can_be_only_a_song_and_a_later_note_drops_it(): void
    {
        $this->fakeItunes([$this->song(111)]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson('/api/v1/me/note', ['trackId' => '111'])->assertOk()->assertJsonPath('data.text', '')->assertJsonPath('data.track.id', '111');
        $this->putJson('/api/v1/me/note', ['text' => 'chỉ chữ'])->assertOk()->assertJsonPath('data.track', null);
        $this->assertNull($this->getJson('/api/v1/notes')->json('data.0.track'));
    }

    public function test_a_note_needs_text_or_a_real_song(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson('/api/v1/me/note', [])->assertStatus(422)->assertJsonStructure(['errors' => ['text']]);
        $this->putJson('/api/v1/me/note', ['text' => '  ', 'trackId' => ''])->assertStatus(422);

        Http::fake(['itunes.apple.com/*' => Http::response(json_encode(['resultCount' => 0, 'results' => []]), 200)]);
        $this->putJson('/api/v1/me/note', ['trackId' => '999'])->assertStatus(422)->assertJsonStructure(['errors' => ['trackId']]);
        $this->putJson('/api/v1/me/note', ['text' => 'ok', 'trackId' => 'abc; drop'])->assertStatus(422)->assertJsonStructure(['errors' => ['trackId']]);
        $this->assertDatabaseCount('notes', 0);
    }

    public function test_the_client_cannot_make_up_a_preview(): void
    {
        $this->fakeItunes([$this->song(111)]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson('/api/v1/me/note', ['text' => 'x', 'trackId' => '111', 'previewUrl' => 'https://evil.example.com/a.m4a'])->assertOk()
            ->assertJsonPath('data.track.previewUrl', 'https://audio-ssl.itunes.apple.com/preview/111.m4a');
        $this->assertDatabaseMissing('notes', ['track_preview_url' => 'https://evil.example.com/a.m4a']);
    }

    public function test_a_catalogue_outage_while_attaching_is_a_503(): void
    {
        Http::fake(['itunes.apple.com/*' => Http::response('', 500)]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson('/api/v1/me/note', ['text' => 'x', 'trackId' => '111'])->assertStatus(503)->assertJsonPath('code', 'music_unavailable');
    }

    // ---- stories with a song

    public function test_a_story_can_carry_a_song(): void
    {
        $this->fakeItunes([$this->song(222)]);
        $me = User::factory()->create();
        $friend = User::factory()->create();
        Friendship::create(['requester_id' => $me->id, 'addressee_id' => $friend->id, 'status' => 'accepted']);
        $this->actingAs($me, 'sanctum');

        $story = $this->postJson('/api/v1/stories', ['text' => 'Hè về', 'trackId' => '222'])->assertCreated();

        $story->assertJsonPath('data.track.id', '222')->assertJsonPath('data.track.artist', 'Sơn Tùng M-TP');
        $this->actingAs($friend, 'sanctum');
        $this->assertSame('222', $this->getJson('/api/v1/stories')->json('data.0.track.id'));
        $this->postJson('/api/v1/stories', ['text' => 'không nhạc'])->assertCreated()->assertJsonPath('data.track', null);
    }

    public function test_a_story_with_an_unknown_song_is_refused_and_nothing_is_stored(): void
    {
        Http::fake(['itunes.apple.com/*' => Http::response(json_encode(['resultCount' => 0, 'results' => []]), 200)]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->postJson('/api/v1/stories', ['text' => 'x', 'trackId' => '999'])->assertStatus(422)->assertJsonStructure(['errors' => ['trackId']]);
        $this->assertDatabaseCount('stories', 0);
    }

    // ---- Spotify link

    public function test_the_spotify_link_is_added_only_when_it_is_configured(): void
    {
        config(['services.spotify.client_id' => 'id', 'services.spotify.client_secret' => 'secret']);
        Http::fake([
            'itunes.apple.com/*' => Http::response(json_encode(['results' => [$this->song(111)]]), 200),
            'accounts.spotify.com/*' => Http::response(['access_token' => 'tok', 'expires_in' => 3600], 200),
            'api.spotify.com/*' => Http::response(['tracks' => ['items' => [['external_urls' => ['spotify' => 'https://open.spotify.com/track/abc']]]]], 200),
        ]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson('/api/v1/me/note', ['text' => 'nghe', 'trackId' => '111'])->assertOk()
            ->assertJsonPath('data.track.spotifyUrl', 'https://open.spotify.com/track/abc');
        Http::assertSent(fn (HttpRequest $r) => str_contains($r->url(), 'api.spotify.com') && $r->hasHeader('Authorization', 'Bearer tok'));
    }

    public function test_spotify_trouble_never_breaks_a_note(): void
    {
        config(['services.spotify.client_id' => 'id', 'services.spotify.client_secret' => 'secret']);
        Http::fake([
            'itunes.apple.com/*' => Http::response(json_encode(['results' => [$this->song(111)]]), 200),
            'accounts.spotify.com/*' => Http::response('nope', 401),
        ]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        // Spotify will not answer, so the link is a Spotify search for the song
        $link = $this->putJson('/api/v1/me/note', ['text' => 'nghe', 'trackId' => '111'])->assertOk()->json('data.track.spotifyUrl');
        $this->assertStringStartsWith('https://open.spotify.com/search/', $link);
        $this->assertStringContainsString(rawurlencode('Em Của Ngày Hôm Qua'), $link);

        // a match that is not a Spotify address is never passed on
        Cache::flush();
        Http::fake([
            'itunes.apple.com/*' => Http::response(json_encode(['results' => [$this->song(111)]]), 200),
            'accounts.spotify.com/*' => Http::response(['access_token' => 'tok'], 200),
            'api.spotify.com/*' => Http::response(['tracks' => ['items' => [['external_urls' => ['spotify' => 'https://evil.example.com/x']]]]], 200),
        ]);
        $this->putJson('/api/v1/me/note', ['text' => 'nghe', 'trackId' => '111'])->assertOk();
        $this->assertStringStartsWith('https://open.spotify.com/search/', $this->getJson('/api/v1/notes')->json('data.0.track.spotifyUrl'));
    }

    public function test_a_denied_spotify_api_falls_back_to_a_search_link(): void
    {
        config(['services.spotify.client_id' => 'id', 'services.spotify.client_secret' => 'secret']);
        Http::fake([
            'itunes.apple.com/*' => Http::response(json_encode(['results' => [$this->song(111)]]), 200),
            'accounts.spotify.com/*' => Http::response(['access_token' => 'tok'], 200),
            'api.spotify.com/*' => Http::response(['error' => 'Active premium subscription required for the owner of the app.'], 403),
        ]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson('/api/v1/me/note', ['text' => 'nghe', 'trackId' => '111'])->assertOk()
            ->assertJsonPath('data.track.spotifyUrl', 'https://open.spotify.com/search/'.rawurlencode('Em Của Ngày Hôm Qua Sơn Tùng M-TP'));
    }

    public function test_without_spotify_keys_spotify_is_never_called(): void
    {
        $this->fakeItunes([$this->song(111)]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson('/api/v1/me/note', ['text' => 'nghe', 'trackId' => '111'])->assertOk();

        Http::assertNotSent(fn (HttpRequest $r) => str_contains($r->url(), 'spotify.com'));
    }
}
