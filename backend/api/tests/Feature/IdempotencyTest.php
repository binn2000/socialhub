<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class IdempotencyTest extends TestCase
{
    use RefreshDatabase;

    private function key(): array
    {
        return ['Idempotency-Key' => (string) Str::uuid()];
    }

    public function test_repeated_post_returns_the_original_response_once(): void
    {
        $me = User::factory()->create();
        $h = $this->key();
        $this->actingAs($me, 'sanctum');

        $first = $this->postJson('/api/v1/posts', ['content' => 'once'], $h)->assertCreated();
        $second = $this->postJson('/api/v1/posts', ['content' => 'once'], $h)->assertCreated()
            ->assertHeader('Idempotent-Replayed', 'true')
            ->assertHeader('Location', $first->headers->get('Location'));

        $this->assertSame($first->json('data.id'), $second->json('data.id'));
        $this->assertSame(1, Post::count());
    }

    public function test_same_key_with_different_body_is_409(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $h = $this->key();

        $this->postJson('/api/v1/posts', ['content' => 'a'], $h)->assertCreated();
        $this->postJson('/api/v1/posts', ['content' => 'b'], $h)->assertStatus(409)->assertJsonPath('code', 'idempotency_key_reused');
        $this->assertSame(1, Post::count());
    }

    public function test_same_key_on_another_endpoint_is_409(): void
    {
        $me = User::factory()->create();
        $post = Post::forceCreate(['id' => (string) Str::ulid(), 'user_id' => $me->id, 'content' => 'x', 'privacy' => 'public', 'created_at' => now()]);
        $this->actingAs($me, 'sanctum');
        $h = $this->key();

        $this->postJson('/api/v1/posts', ['content' => 'a'], $h)->assertCreated();
        $this->postJson("/api/v1/posts/{$post->id}/comments", ['content' => 'a'], $h)->assertStatus(409);
    }

    public function test_keys_are_per_user(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $h = $this->key();

        $this->actingAs($a, 'sanctum')->postJson('/api/v1/posts', ['content' => 'same'], $h)->assertCreated();
        $this->actingAs($b, 'sanctum')->postJson('/api/v1/posts', ['content' => 'same'], $h)->assertCreated()
            ->assertHeaderMissing('Idempotent-Replayed');
        $this->assertSame(2, Post::count());
    }

    public function test_failed_request_does_not_burn_the_key(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $h = $this->key();

        $this->postJson('/api/v1/posts', ['content' => ' '], $h)->assertStatus(422);
        $this->assertSame(0, DB::table('idempotency_keys')->count());
        $this->postJson('/api/v1/posts', ['content' => 'fixed'], $h)->assertCreated();
    }

    public function test_request_without_key_is_not_deduplicated_and_bad_key_is_rejected(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->postJson('/api/v1/posts', ['content' => 'x'])->assertCreated();
        $this->postJson('/api/v1/posts', ['content' => 'x'])->assertCreated();
        $this->assertSame(2, Post::count());
        $this->assertSame(0, DB::table('idempotency_keys')->count());

        $this->postJson('/api/v1/posts', ['content' => 'x'], ['Idempotency-Key' => 'not-a-uuid'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['Idempotency-Key']]);
    }

    public function test_unfinished_first_request_blocks_repeats_until_stale(): void
    {
        $me = User::factory()->create();
        $h = $this->key();
        $this->actingAs($me, 'sanctum');
        $payload = ['content' => 'x'];

        $this->postJson('/api/v1/posts', $payload, $h)->assertCreated();
        // simulate a first request that is still running
        DB::table('idempotency_keys')->update(['status_code' => null, 'response_body' => null]);

        $this->postJson('/api/v1/posts', $payload, $h)->assertStatus(409)->assertJsonPath('code', 'request_in_progress');

        // ...and one that died long ago
        DB::table('idempotency_keys')->update(['created_at' => now()->subMinutes(10)]);
        $this->postJson('/api/v1/posts', $payload, $h)->assertCreated();
        $this->assertSame(2, Post::count());
    }

    public function test_keys_expire_after_24_hours_and_purge_command(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $h = $this->key();

        $this->postJson('/api/v1/posts', ['content' => 'x'], $h)->assertCreated();
        DB::table('idempotency_keys')->update(['created_at' => now()->subHours(25)]);
        $this->artisan('idempotency:purge')->assertSuccessful();
        $this->assertSame(0, DB::table('idempotency_keys')->count());

        $this->postJson('/api/v1/posts', ['content' => 'x'], $h)->assertCreated();
        DB::table('idempotency_keys')->update(['created_at' => now()->subHours(25)]);
        $this->postJson('/api/v1/posts', ['content' => 'x'], $h)->assertCreated()->assertHeaderMissing('Idempotent-Replayed');
        $this->assertSame(3, Post::count());
    }

    public function test_comments_do_not_double_count(): void
    {
        $me = User::factory()->create();
        $post = Post::forceCreate(['id' => (string) Str::ulid(), 'user_id' => $me->id, 'content' => 'x', 'privacy' => 'public', 'created_at' => now()]);
        $this->actingAs($me, 'sanctum');
        $h = $this->key();

        $this->postJson("/api/v1/posts/{$post->id}/comments", ['content' => 'hi'], $h)->assertCreated()->assertJsonPath('meta.commentsCount', 1);
        $this->postJson("/api/v1/posts/{$post->id}/comments", ['content' => 'hi'], $h)->assertCreated()->assertJsonPath('meta.commentsCount', 1);
        $this->assertSame(1, $post->fresh()->comments_count);
    }

    public function test_messages_and_stories_replay(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'accepted']);
        $this->actingAs($a, 'sanctum');
        $c = $this->postJson('/api/v1/conversations', ['userId' => $b->id])->json('data.id');

        $h = $this->key();
        $m1 = $this->postJson("/api/v1/conversations/$c/messages", ['text' => 'once'], $h)->assertCreated()->json('data.id');
        $m2 = $this->postJson("/api/v1/conversations/$c/messages", ['text' => 'once'], $h)->assertCreated()->json('data.id');
        $this->assertSame($m1, $m2);
        $this->assertSame(1, DB::table('messages')->count());

        $h = $this->key();
        $this->postJson('/api/v1/stories', ['text' => 's'], $h)->assertCreated();
        $this->postJson('/api/v1/stories', ['text' => 's'], $h)->assertCreated()->assertHeader('Idempotent-Replayed', 'true');
        $this->assertSame(1, DB::table('stories')->count());
    }

    public function test_multipart_retry_with_same_file_replays_and_different_file_conflicts(): void
    {
        Storage::fake('public');
        $this->actingAs(User::factory()->create(), 'sanctum');
        $h = $this->key() + ['Accept' => 'application/json'];
        $img = fn (int $w) => UploadedFile::fake()->image('p.png', $w, 20);

        $a = $this->post('/api/v1/posts', ['image' => $img(30)], $h)->assertCreated()->json('data.id');
        $b = $this->post('/api/v1/posts', ['image' => $img(30)], $h)->assertCreated()->json('data.id');
        $this->assertSame($a, $b);
        $this->assertCount(1, Storage::disk('public')->allFiles());

        $this->post('/api/v1/posts', ['image' => $img(60)], $h)->assertStatus(409)->assertJsonPath('code', 'idempotency_key_reused');
    }
}
