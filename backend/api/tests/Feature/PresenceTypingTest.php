<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PresenceTypingTest extends TestCase
{
    use RefreshDatabase;

    private function befriend(User $a, User $b): void
    {
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'accepted']);
    }

    // ---- presence

    public function test_a_request_marks_the_user_active_at_most_once_a_minute(): void
    {
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum');

        $this->getJson('/api/v1/me')->assertOk();
        $first = DB::table('users')->where('id', $me->id)->value('last_seen_at');
        $this->assertNotNull($first);

        $this->travel(30)->seconds();
        $this->getJson('/api/v1/me');
        $this->assertSame($first, DB::table('users')->where('id', $me->id)->value('last_seen_at')); // not rewritten

        $this->travel(40)->seconds();
        $this->postJson('/api/v1/me/presence')->assertNoContent();
        $this->assertNotSame($first, DB::table('users')->where('id', $me->id)->value('last_seen_at'));
    }

    public function test_friends_see_online_and_last_seen_but_others_do_not(): void
    {
        [$me, $friend, $stranger] = User::factory()->count(3)->create();
        $this->befriend($me, $friend);
        $friend->forceFill(['last_seen_at' => now()->subSeconds(30)])->save();
        $stranger->forceFill(['last_seen_at' => now()->subSeconds(30)])->save();
        $this->actingAs($me, 'sanctum');

        $profile = $this->getJson("/api/v1/users/{$friend->id}")->assertOk();
        $this->assertTrue($profile->json('data.isOnline'));
        $this->assertNotNull($profile->json('data.lastSeenAt'));

        $other = $this->getJson("/api/v1/users/{$stranger->id}")->assertOk();
        $this->assertFalse($other->json('data.isOnline'));
        $this->assertNull($other->json('data.lastSeenAt'));

        $this->travel(5)->minutes();
        $this->actingAs($me, 'sanctum');
        $later = $this->getJson("/api/v1/users/{$friend->id}");
        $this->assertFalse($later->json('data.isOnline')); // 2 minutes without a sign
        $this->assertNotNull($later->json('data.lastSeenAt'));
    }

    public function test_hiding_the_status_looks_like_being_offline(): void
    {
        [$me, $friend] = User::factory()->count(2)->create();
        $this->befriend($me, $friend);
        $friend->forceFill(['last_seen_at' => now()])->save();

        $this->actingAs($friend, 'sanctum')->patchJson('/api/v1/me', ['showOnlineStatus' => false])
            ->assertOk()->assertJsonPath('data.showOnlineStatus', false);

        $this->actingAs($me, 'sanctum');
        $profile = $this->getJson("/api/v1/users/{$friend->id}");
        $this->assertFalse($profile->json('data.isOnline'));
        $this->assertNull($profile->json('data.lastSeenAt'));
        $this->assertFalse($this->getJson('/api/v1/users?relationship=friends')->assertOk()->json('data.0.isOnline'));

        // the person themself still sees their own state
        $this->actingAs($friend, 'sanctum')->getJson('/api/v1/me')->assertJsonPath('data.showOnlineStatus', false);
        $this->patchJson('/api/v1/me', ['showOnlineStatus' => 'maybe'])->assertStatus(422)->assertJsonStructure(['errors' => ['showOnlineStatus']]);
        $this->patchJson('/api/v1/me', ['showOnlineStatus' => true])->assertOk()->assertJsonPath('data.showOnlineStatus', true);
    }

    public function test_presence_shows_in_conversations_and_friend_lists(): void
    {
        [$me, $friend] = User::factory()->count(2)->create();
        $this->befriend($me, $friend);
        $friend->forceFill(['last_seen_at' => now()])->save();
        $this->actingAs($me, 'sanctum');
        $conversation = $this->postJson('/api/v1/conversations', ['userId' => $friend->id])->assertCreated();
        $this->assertTrue($conversation->json('data.participant.isOnline'));
        $this->postJson("/api/v1/conversations/{$conversation->json('data.id')}/messages", ['text' => 'hi']);

        $this->assertTrue($this->getJson('/api/v1/conversations')->json('data.0.participant.isOnline'));
        $this->assertTrue($this->getJson('/api/v1/users?relationship=friends')->assertOk()->json('data.0.isOnline'));
    }

    // ---- typing

    private function chat(): array
    {
        [$me, $friend] = User::factory()->count(2)->create();
        $this->befriend($me, $friend);
        $id = $this->actingAs($me, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $friend->id])->json('data.id');

        return [$me, $friend, $id];
    }

    public function test_the_other_person_sees_typing_for_six_seconds(): void
    {
        [$me, $friend, $id] = $this->chat();
        $this->assertFalse($this->getJson("/api/v1/conversations/$id/messages")->json('meta.otherTyping'));

        $this->putJson("/api/v1/conversations/$id/typing")->assertNoContent();

        $this->assertFalse($this->getJson("/api/v1/conversations/$id/messages")->json('meta.otherTyping')); // my own typing is not shown to me
        $this->actingAs($friend, 'sanctum');
        $this->assertTrue($this->getJson("/api/v1/conversations/$id/messages")->json('meta.otherTyping'));
        $message = $this->actingAs($me, 'sanctum')->postJson("/api/v1/conversations/$id/messages", ['text' => 'a'])->json('data.id');
        $this->actingAs($friend, 'sanctum');
        $this->assertFalse($this->getJson("/api/v1/conversations/$id/messages?after=$message")->json('meta.otherTyping')); // sending clears it

        $this->actingAs($me, 'sanctum')->putJson("/api/v1/conversations/$id/typing");
        $this->actingAs($friend, 'sanctum');
        $this->assertTrue($this->getJson("/api/v1/conversations/$id/messages?after=$message")->json('meta.otherTyping'));
        $this->travel(7)->seconds();
        $this->assertFalse($this->getJson("/api/v1/conversations/$id/messages?after=$message")->json('meta.otherTyping'));
    }

    public function test_stopping_clears_typing_at_once(): void
    {
        [$me, $friend, $id] = $this->chat();
        $this->putJson("/api/v1/conversations/$id/typing");

        $this->deleteJson("/api/v1/conversations/$id/typing")->assertNoContent();
        $this->deleteJson("/api/v1/conversations/$id/typing")->assertNoContent();

        $this->actingAs($friend, 'sanctum');
        $this->assertFalse($this->getJson("/api/v1/conversations/$id/messages")->json('meta.otherTyping'));
    }

    public function test_only_friends_in_the_conversation_can_type(): void
    {
        [$me, $friend, $id] = $this->chat();

        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->putJson("/api/v1/conversations/$id/typing")->assertNotFound();
        $this->deleteJson("/api/v1/conversations/$id/typing")->assertNotFound();

        Friendship::query()->delete();
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/conversations/$id/typing")
            ->assertForbidden()->assertJsonPath('code', 'not_friends');
        $this->assertFalse(Cache::has("typing:$id:{$me->id}"));

        $this->app['auth']->forgetGuards();
        $this->putJson("/api/v1/conversations/$id/typing")->assertUnauthorized();
    }
}
