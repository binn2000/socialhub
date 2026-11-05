<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\VideoCatalog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class VideoSearchTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
        config(['services.youtube.key' => 'test-key']);
        $this->actingAs(User::factory()->create(), 'sanctum');
    }

    private function details(): array
    {
        return ['items' => [
            ['id' => 'dQw4w9WgXcQ', 'snippet' => [
                'title' => 'Bài hát', 'channelTitle' => 'Kênh A', 'publishedAt' => '2026-01-01T00:00:00Z',
                'thumbnails' => ['medium' => ['url' => 'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg']],
            ], 'contentDetails' => ['duration' => 'PT1H2M3S'], 'status' => ['embeddable' => true]],
            // Not allowed to be embedded: useless for the in-app player.
            ['id' => 'aaaaaaaaaaa', 'snippet' => ['title' => 'Khóa', 'channelTitle' => 'B', 'thumbnails' => []],
                'contentDetails' => ['duration' => 'PT5S'], 'status' => ['embeddable' => false]],
            // An id that is not 11 characters is never passed on.
            ['id' => 'short', 'snippet' => ['title' => 'Sai', 'channelTitle' => 'C', 'thumbnails' => []], 'contentDetails' => []],
        ]];
    }

    public function test_search_returns_playable_videos_with_duration_and_trusted_thumbnails(): void
    {
        Http::fake([
            'googleapis.com/youtube/v3/search*' => Http::response([
                'nextPageToken' => 'CAoQAA',
                'items' => [['id' => ['videoId' => 'dQw4w9WgXcQ']], ['id' => ['videoId' => 'aaaaaaaaaaa']], ['id' => ['videoId' => '<script>']]],
            ]),
            'googleapis.com/youtube/v3/videos*' => Http::response($this->details()),
        ]);

        $this->getJson('/api/v1/videos/search?q=nhac+viet')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', 'dQw4w9WgXcQ')
            ->assertJsonPath('data.0.title', 'Bài hát')
            ->assertJsonPath('data.0.durationSeconds', 3723)
            ->assertJsonPath('data.0.thumbnailUrl', 'https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg')
            ->assertJsonPath('meta.nextCursor', 'CAoQAA')
            ->assertJsonPath('meta.hasMore', true);

        // The bad id never reached the details call, and the key is sent by the server only.
        Http::assertSent(fn ($r) => str_contains($r->url(), '/videos') && ! str_contains($r->url(), 'script') && str_contains($r->url(), 'key=test-key'));
    }

    public function test_without_words_it_lists_the_popular_videos_and_answers_are_cached(): void
    {
        Http::fake(['googleapis.com/youtube/v3/videos*' => Http::response($this->details())]);

        $this->getJson('/api/v1/videos/search')->assertOk()->assertJsonPath('data.0.id', 'dQw4w9WgXcQ');
        $this->getJson('/api/v1/videos/search')->assertOk();

        Http::assertSentCount(1);
        Http::assertSent(fn ($r) => str_contains($r->url(), 'chart=mostPopular') && str_contains($r->url(), 'regionCode=VN'));
    }

    public function test_the_cursor_is_validated_and_passed_to_youtube(): void
    {
        Http::fake(['googleapis.com/*' => Http::response(['items' => []])]);

        $this->getJson('/api/v1/videos/search?q=abc&cursor='.urlencode('a b&key=x'))->assertUnprocessable();
        $this->getJson('/api/v1/videos/search?q=abc&cursor=CAoQAA')->assertOk();
        Http::assertSent(fn ($r) => str_contains($r->url(), 'pageToken=CAoQAA'));
    }

    public function test_it_answers_503_when_youtube_refuses_or_no_key_is_set(): void
    {
        Http::fake(['googleapis.com/*' => Http::response(['error' => ['message' => 'quotaExceeded']], 403)]);
        $this->getJson('/api/v1/videos/search?q=abc')->assertStatus(503)->assertJsonPath('code', 'video_unavailable');

        config(['services.youtube.key' => null]);
        Cache::flush();
        $this->getJson('/api/v1/videos/search?q=xyz')->assertStatus(503)->assertJsonPath('code', 'video_unavailable');
    }

    public function test_it_needs_a_signed_in_user_and_parses_durations(): void
    {
        $this->assertSame(3723, VideoCatalog::seconds('PT1H2M3S'));
        $this->assertSame(45, VideoCatalog::seconds('PT45S'));
        $this->assertSame(86400, VideoCatalog::seconds('P1D'));
        $this->assertNull(VideoCatalog::seconds('nonsense'));
        $this->assertTrue(VideoCatalog::isVideoId('dQw4w9WgXcQ'));
        $this->assertFalse(VideoCatalog::isVideoId('dQw4w9WgXc'));

        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/videos/search?q=abc')->assertUnauthorized();
    }
}
