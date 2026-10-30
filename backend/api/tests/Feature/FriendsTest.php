<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class FriendsTest extends TestCase
{
    use RefreshDatabase;

    private function link(User $from, User $to, string $status = 'accepted'): Friendship
    {
        return Friendship::create(['requester_id' => $from->id, 'addressee_id' => $to->id, 'status' => $status]);
    }

    public function test_send_accept_flow(): void
    {
        [$a, $b] = User::factory()->count(2)->create();

        $id = $this->actingAs($a, 'sanctum')->postJson('/api/v1/friend-requests', ['userId' => $b->id])
            ->assertCreated()
            ->assertJsonPath('data.sender.id', $a->id)
            ->assertJsonPath('data.receiver.id', $b->id)
            ->json('data.id');

        $this->assertSame(1, DB::table('notifications')->where(['user_id' => $b->id, 'type' => 'friend_request'])->count());

        $this->actingAs($b, 'sanctum')->getJson('/api/v1/friend-requests')
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $id);
        $this->actingAs($a, 'sanctum')->getJson('/api/v1/friend-requests')->assertJsonCount(0, 'data');
        $this->actingAs($a, 'sanctum')->getJson('/api/v1/friend-requests?direction=outgoing')->assertJsonCount(1, 'data');

        // only the receiver may accept
        $this->actingAs($a, 'sanctum')->postJson("/api/v1/friend-requests/$id/accept")->assertNotFound();
        $this->actingAs(User::factory()->create(), 'sanctum')->postJson("/api/v1/friend-requests/$id/accept")->assertNotFound();

        $this->actingAs($b, 'sanctum')->postJson("/api/v1/friend-requests/$id/accept")
            ->assertOk()
            ->assertJsonPath('data.id', $a->id)
            ->assertJsonPath('data.friendship.status', 'friends')
            ->assertJsonPath('data.friendsCount', 1);
        $this->actingAs($b, 'sanctum')->postJson("/api/v1/friend-requests/$id/accept")->assertOk(); // idempotent

        $this->assertSame(1, DB::table('notifications')->where(['user_id' => $a->id, 'type' => 'friend_accepted'])->count());
        $this->actingAs($b, 'sanctum')->getJson('/api/v1/friend-requests')->assertJsonCount(0, 'data');
    }

    public function test_send_validation_and_conflicts(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $this->actingAs($a, 'sanctum');

        $this->postJson('/api/v1/friend-requests', [])->assertStatus(422);
        $this->postJson('/api/v1/friend-requests', ['userId' => $a->id])->assertStatus(422)->assertJsonStructure(['errors' => ['userId']]);
        $this->postJson('/api/v1/friend-requests', ['userId' => 'nope'])->assertStatus(422);

        $this->postJson('/api/v1/friend-requests', ['userId' => $b->id])->assertCreated();
        $this->postJson('/api/v1/friend-requests', ['userId' => $b->id])->assertStatus(409)->assertJsonPath('code', 'friend_request_exists');
        // the other direction is the same pair
        $this->actingAs($b, 'sanctum')->postJson('/api/v1/friend-requests', ['userId' => $a->id])
            ->assertStatus(409)->assertJsonPath('code', 'friend_request_exists');

        Friendship::query()->update(['status' => 'accepted']);
        $this->postJson('/api/v1/friend-requests', ['userId' => $a->id])->assertStatus(409)->assertJsonPath('code', 'already_friends');
    }

    public function test_cancel_and_decline_allow_a_new_request(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $f = $this->link($a, $b, 'pending');

        $this->actingAs(User::factory()->create(), 'sanctum')->deleteJson("/api/v1/friend-requests/{$f->id}")->assertNotFound();
        $this->actingAs($b, 'sanctum')->deleteJson("/api/v1/friend-requests/{$f->id}")->assertNoContent(); // decline
        $this->actingAs($b, 'sanctum')->deleteJson("/api/v1/friend-requests/{$f->id}")->assertNotFound();

        $this->actingAs($b, 'sanctum')->postJson('/api/v1/friend-requests', ['userId' => $a->id])->assertCreated();
    }

    public function test_accepted_friendship_cannot_be_deleted_as_a_request(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $f = $this->link($a, $b);

        $this->actingAs($a, 'sanctum')->deleteJson("/api/v1/friend-requests/{$f->id}")->assertNotFound();
    }

    public function test_unfriend_is_idempotent_and_removes_friends_only_access(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $this->link($a, $b);
        $post = Post::forceCreate(['id' => (string) Str::ulid(), 'user_id' => $a->id, 'content' => 'x', 'privacy' => 'friends', 'created_at' => now()]);

        $this->actingAs($b, 'sanctum')->getJson("/api/v1/posts/{$post->id}")->assertOk();
        $this->actingAs($b, 'sanctum')->deleteJson("/api/v1/friends/{$a->id}")->assertNoContent();
        $this->actingAs($b, 'sanctum')->deleteJson("/api/v1/friends/{$a->id}")->assertNoContent();
        $this->actingAs($b, 'sanctum')->getJson("/api/v1/posts/{$post->id}")->assertNotFound();
        $this->actingAs($b, 'sanctum')->deleteJson('/api/v1/friends/doesnotexist')->assertNotFound();
    }

    public function test_user_list_excludes_self_and_reports_friendship(): void
    {
        $me = User::factory()->create(['name' => 'Me']);
        $friend = User::factory()->create(['name' => 'Bình']);
        $out = User::factory()->create(['name' => 'Cường']);
        $in = User::factory()->create(['name' => 'Dung']);
        $none = User::factory()->create(['name' => 'An']);
        $this->link($me, $friend);
        $outReq = $this->link($me, $out, 'pending');
        $inReq = $this->link($in, $me, 'pending');
        $this->actingAs($me, 'sanctum');

        $data = $this->getJson('/api/v1/users')->assertOk()->json('data');
        $this->assertSame(['An', 'Bình', 'Cường', 'Dung'], array_column($data, 'name'));
        $by = array_column($data, 'friendship', 'name');
        $this->assertSame(['status' => 'none', 'requestId' => null], $by['An']);
        $this->assertSame(['status' => 'friends', 'requestId' => null], $by['Bình']);
        $this->assertSame(['status' => 'pending_outgoing', 'requestId' => $outReq->id], $by['Cường']);
        $this->assertSame(['status' => 'pending_incoming', 'requestId' => $inReq->id], $by['Dung']);
        $this->assertArrayNotHasKey('email', $data[0]);

        foreach (['none' => ['An'], 'friends' => ['Bình'], 'pending_outgoing' => ['Cường'], 'pending_incoming' => ['Dung']] as $rel => $names) {
            $this->assertSame($names, array_column($this->getJson("/api/v1/users?relationship=$rel")->json('data'), 'name'), $rel);
        }
        $this->getJson('/api/v1/users?relationship=bogus')->assertStatus(422);
    }

    public function test_user_search_pagination_and_mutual_friends(): void
    {
        $me = User::factory()->create(['name' => 'Me']);
        $shared = User::factory()->create(['name' => 'Shared']);
        $x = User::factory()->create(['name' => 'Minh Anh']);
        $y = User::factory()->create(['name' => 'Mình Bảo']);
        User::factory()->create(['name' => 'Zed']);
        $this->link($me, $shared);
        $this->link($x, $shared);
        $this->actingAs($me, 'sanctum');

        $found = $this->getJson('/api/v1/users?q=minh')->json('data');
        $this->assertSame(['Minh Anh', 'Mình Bảo'], array_column($found, 'name'));
        $this->assertSame(1, $found[0]['mutualFriendsCount']);
        $this->assertSame(0, $found[1]['mutualFriendsCount']);

        $p1 = $this->getJson('/api/v1/users?limit=2')->assertOk();
        $this->assertTrue($p1->json('meta.hasMore'));
        $p2 = $this->getJson('/api/v1/users?limit=2&cursor='.$p1->json('meta.nextCursor'))->assertOk();
        $names = array_merge(array_column($p1->json('data'), 'name'), array_column($p2->json('data'), 'name'));
        $this->assertSame(['Minh Anh', 'Mình Bảo', 'Shared', 'Zed'], $names);
        $this->getJson('/api/v1/users?q=zed&cursor='.$p1->json('meta.nextCursor'))->assertStatus(400);
    }

    public function test_profile(): void
    {
        [$me, $other, $third] = User::factory()->count(3)->create();
        $other->update(['bio' => 'Hello']);
        $this->link($me, $third);
        $this->link($other, $third);
        $this->actingAs($me, 'sanctum');

        $this->getJson("/api/v1/users/{$other->id}")->assertOk()
            ->assertJsonPath('data.bio', 'Hello')
            ->assertJsonPath('data.friendsCount', 1)
            ->assertJsonPath('data.mutualFriendsCount', 1)
            ->assertJsonPath('data.friendship.status', 'none')
            ->assertJsonMissingPath('data.email');
        $this->getJson("/api/v1/users/{$me->id}")->assertJsonPath('data.friendship.status', 'self')->assertJsonPath('data.mutualFriendsCount', null);
        $this->getJson('/api/v1/users/missing')->assertNotFound();
    }

    public function test_user_posts_respect_visibility_and_include_hidden(): void
    {
        [$me, $author] = User::factory()->count(2)->create();
        $mk = fn (string $privacy) => Post::forceCreate(['id' => (string) Str::ulid(), 'user_id' => $author->id, 'content' => $privacy, 'privacy' => $privacy, 'created_at' => now()]);
        $public = $mk('public');
        $mk('friends');
        $mk('only_me');
        DB::table('post_hidden')->insert(['post_id' => $public->id, 'user_id' => $me->id]);
        $this->actingAs($me, 'sanctum');

        $r = $this->getJson("/api/v1/users/{$author->id}/posts")->assertOk();
        $this->assertSame(['public'], array_column($r->json('data'), 'content'));
        $this->assertTrue($r->json('data.0.isHidden'));

        $this->link($me, $author);
        $this->assertCount(2, $this->getJson("/api/v1/users/{$author->id}/posts")->json('data'));
        $this->actingAs($author, 'sanctum');
        $this->assertCount(3, $this->getJson("/api/v1/users/{$author->id}/posts")->json('data'));
    }

    public function test_requires_authentication(): void
    {
        $this->getJson('/api/v1/users')->assertStatus(401);
        $this->postJson('/api/v1/friend-requests', ['userId' => 'x'])->assertStatus(401);
    }
}
