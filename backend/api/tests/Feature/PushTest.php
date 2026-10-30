<?php

namespace Tests\Feature;

use App\Jobs\CreateNotification;
use App\Jobs\SendPush;
use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Tests\TestCase;

class PushTest extends TestCase
{
    use RefreshDatabase;

    private function fcmOn(): void
    {
        $key = openssl_pkey_new(['private_key_bits' => 2048]);
        openssl_pkey_export($key, $pem);
        $file = tempnam(sys_get_temp_dir(), 'fcm');
        file_put_contents($file, json_encode(['client_email' => 'svc@example.iam.gserviceaccount.com', 'private_key' => $pem]));
        config(['services.fcm.project_id' => 'demo', 'services.fcm.credentials' => $file]);
        Cache::forget('fcm_access_token');
    }

    private function device(User $user, string $token = 'tok-1'): void
    {
        DB::table('device_tokens')->insert([
            'user_id' => $user->id, 'token_hash' => hash('sha256', $token), 'token' => $token,
            'platform' => 'android', 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    // ---- registering

    public function test_a_device_is_registered_and_moves_between_accounts(): void
    {
        [$a, $b] = User::factory()->count(2)->create();

        $this->actingAs($a, 'sanctum')->putJson('/api/v1/me/devices', ['token' => 'abc', 'platform' => 'ios'])->assertNoContent();
        $this->putJson('/api/v1/me/devices', ['token' => 'abc', 'platform' => 'ios'])->assertNoContent();
        $this->assertSame(1, DB::table('device_tokens')->count());

        // the same phone signs in as someone else
        $this->actingAs($b, 'sanctum')->putJson('/api/v1/me/devices', ['token' => 'abc', 'platform' => 'ios'])->assertNoContent();
        $this->assertSame(1, DB::table('device_tokens')->count());
        $this->assertSame($b->id, DB::table('device_tokens')->value('user_id'));
    }

    public function test_registering_is_validated_and_needs_sign_in(): void
    {
        $this->putJson('/api/v1/me/devices', ['token' => 'abc', 'platform' => 'ios'])->assertStatus(401);

        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->putJson('/api/v1/me/devices', ['platform' => 'ios'])->assertStatus(422);
        $this->putJson('/api/v1/me/devices', ['token' => 'abc', 'platform' => 'windows'])->assertStatus(422);
    }

    public function test_a_device_can_only_be_removed_by_its_owner(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $this->device($a);

        $this->actingAs($b, 'sanctum')->deleteJson('/api/v1/me/devices', ['token' => 'tok-1'])->assertNoContent();
        $this->assertSame(1, DB::table('device_tokens')->count());

        $this->actingAs($a, 'sanctum')->deleteJson('/api/v1/me/devices', ['token' => 'tok-1'])->assertNoContent();
        $this->assertSame(0, DB::table('device_tokens')->count());
        $this->deleteJson('/api/v1/me/devices', ['token' => 'tok-1'])->assertNoContent(); // already gone
    }

    public function test_deleting_the_account_forgets_its_devices(): void
    {
        $user = User::factory()->create(['password' => 'old-password-1']);
        $this->device($user);

        $this->actingAs($user, 'sanctum')->deleteJson('/api/v1/me', ['password' => 'old-password-1'])->assertNoContent();

        $this->assertSame(0, DB::table('device_tokens')->count());
    }

    // ---- sending

    public function test_a_like_pushes_to_the_post_author(): void
    {
        Queue::fake([SendPush::class]);
        [$author, $fan] = User::factory()->count(2)->create(['name' => 'Lan']);
        $fan->forceFill(['name' => 'Khang'])->save();
        $post = Post::forceCreate([
            'id' => (string) Str::ulid(), 'user_id' => $author->id, 'content' => 'hi', 'privacy' => 'public',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        (new CreateNotification($author->id, $fan->id, 'like', postId: $post->id, dedupeKey: 'k1'))->handle();
        (new CreateNotification($author->id, $fan->id, 'like', postId: $post->id, dedupeKey: 'k1'))->handle(); // duplicate

        Queue::assertPushed(SendPush::class, 1);
        Queue::assertPushed(SendPush::class, fn (SendPush $job) => $job->userId === $author->id
            && $job->body === 'Khang đã thích bài viết của bạn'
            && $job->data['type'] === 'like' && $job->data['postId'] === $post->id);
    }

    public function test_a_chat_message_pushes_to_the_other_person(): void
    {
        Queue::fake([SendPush::class]);
        [$me, $friend] = User::factory()->count(2)->create();
        Friendship::create(['requester_id' => $me->id, 'addressee_id' => $friend->id, 'status' => 'accepted']);
        $conversation = $this->actingAs($me, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $friend->id])->json('data.id');

        $this->postJson("/api/v1/conversations/$conversation/messages", ['text' => 'Chào bạn'])->assertCreated();

        Queue::assertPushed(SendPush::class, fn (SendPush $job) => $job->userId === $friend->id
            && $job->title === $me->name && $job->body === 'Chào bạn'
            && $job->data['type'] === 'message' && $job->data['conversationId'] === $conversation);
    }

    public function test_the_sender_calls_fcm_for_every_device(): void
    {
        $this->fcmOn();
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'at-1']),
            'fcm.googleapis.com/*' => Http::response(['name' => 'ok']),
        ]);
        $user = User::factory()->create();
        $this->device($user, 'tok-1');
        $this->device($user, 'tok-2');

        (new SendPush($user->id, 'Tiêu đề', 'Nội dung', ['type' => 'like', 'postId' => 'p1', 'skip' => null]))->handle();

        Http::assertSentCount(3); // one token request, two pushes
        Http::assertSent(fn ($request) => str_contains($request->url(), '/projects/demo/messages:send')
            && $request->hasHeader('Authorization', 'Bearer at-1')
            && $request['message']['notification'] === ['title' => 'Tiêu đề', 'body' => 'Nội dung']
            && (array) $request['message']['data'] === ['type' => 'like', 'postId' => 'p1']);
    }

    public function test_a_dead_token_is_forgotten(): void
    {
        $this->fcmOn();
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'at-1']),
            'fcm.googleapis.com/*' => Http::response(['error' => ['status' => 'NOT_FOUND', 'message' => 'gone']], 404),
        ]);
        $user = User::factory()->create();
        $this->device($user);

        (new SendPush($user->id, 'a', 'b'))->handle();

        $this->assertSame(0, DB::table('device_tokens')->count());
    }

    public function test_nothing_is_sent_when_fcm_is_not_configured(): void
    {
        config(['services.fcm.project_id' => null]);
        Http::fake();
        $user = User::factory()->create();
        $this->device($user);

        (new SendPush($user->id, 'a', 'b'))->handle();

        Http::assertNothingSent();
        $this->assertSame(1, DB::table('device_tokens')->count());
    }
}
