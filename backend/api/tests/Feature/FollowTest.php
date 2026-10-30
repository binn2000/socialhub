<?php

namespace Tests\Feature;

use App\Jobs\CreateNotification;
use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class FollowTest extends TestCase
{
    use RefreshDatabase;

    private function makePost(User $author, array $attributes = []): Post
    {
        return Post::forceCreate($attributes + [
            'id' => strtolower((string) Str::ulid()), 'user_id' => $author->id, 'content' => 'hello',
            'privacy' => 'public', 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function ids(array $response): array
    {
        return array_column($response['data'], 'id');
    }

    public function test_following_is_one_way_idempotent_and_notifies_once(): void
    {
        [$me, $star] = User::factory()->count(2)->create();
        $this->actingAs($me, 'sanctum');

        $this->putJson("/api/v1/users/{$star->id}/follow")->assertNoContent();
        $this->putJson("/api/v1/users/{$star->id}/follow")->assertNoContent();

        $this->assertSame(1, DB::table('follows')->count());
        $this->assertSame(0, DB::table('friendships')->count()); // not a friendship
        $this->assertSame(1, DB::table('notifications')->where('type', 'follow')->count());
        $this->assertSame($star->id, DB::table('notifications')->value('user_id'));

        $this->getJson("/api/v1/users/{$star->id}")
            ->assertJsonPath('data.isFollowing', true)->assertJsonPath('data.followsYou', false)
            ->assertJsonPath('data.followersCount', 1)->assertJsonPath('data.followingCount', 0);
        $this->actingAs($star, 'sanctum')->getJson("/api/v1/users/{$me->id}")
            ->assertJsonPath('data.isFollowing', false)->assertJsonPath('data.followsYou', true);
        $this->getJson('/api/v1/me')->assertJsonPath('data.followersCount', 1)->assertJsonPath('data.followingCount', 0);

        $notification = $this->getJson('/api/v1/notifications?category=friends')->assertOk();
        $this->assertSame('follow', $notification->json('data.0.type'));
        $this->assertSame($me->id, $notification->json('data.0.actor.id'));

        $this->actingAs($me, 'sanctum')->deleteJson("/api/v1/users/{$star->id}/follow")->assertNoContent();
        $this->deleteJson("/api/v1/users/{$star->id}/follow")->assertNoContent();
        $this->assertSame(0, DB::table('follows')->count());

        // following again after unfollowing does not notify twice
        $this->putJson("/api/v1/users/{$star->id}/follow")->assertNoContent();
        $this->assertSame(1, DB::table('notifications')->where('type', 'follow')->count());
    }

    public function test_the_follow_input_is_checked(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        $this->actingAs($me, 'sanctum');

        $this->putJson("/api/v1/users/{$me->id}/follow")->assertStatus(422)->assertJsonStructure(['errors' => ['userId']]);
        $this->putJson('/api/v1/users/nobody/follow')->assertNotFound();

        $this->putJson("/api/v1/users/{$other->id}/block");
        $this->putJson("/api/v1/users/{$other->id}/follow")->assertNotFound();
        $this->actingAs($other, 'sanctum')->putJson("/api/v1/users/{$me->id}/follow")->assertNotFound();

        $this->app['auth']->forgetGuards();
        $this->putJson("/api/v1/users/{$other->id}/follow")->assertUnauthorized();
    }

    public function test_followed_people_show_up_in_the_feed_but_only_their_public_posts(): void
    {
        [$me, $star] = User::factory()->count(2)->create();
        $public = $this->makePost($star, ['content' => 'public']);
        $friendsOnly = $this->makePost($star, ['content' => 'friends', 'privacy' => 'friends']);
        $this->actingAs($me, 'sanctum');
        $this->assertSame([], $this->ids($this->getJson('/api/v1/feed')->json())); // a stranger's posts are not in the feed

        $this->putJson("/api/v1/users/{$star->id}/follow");

        $this->assertSame([$public->id], $this->ids($this->getJson('/api/v1/feed')->json()));
        $this->assertSame([$public->id], $this->ids($this->getJson('/api/v1/feed?filter=following')->json()));
        $this->assertSame([], $this->ids($this->getJson('/api/v1/feed?filter=friends')->json()));
        $this->assertNotContains($friendsOnly->id, $this->ids($this->getJson('/api/v1/feed')->json()));

        $this->deleteJson("/api/v1/users/{$star->id}/follow");
        $this->assertSame([], $this->ids($this->getJson('/api/v1/feed')->json()));
    }

    public function test_the_friends_and_following_tabs_do_not_mix(): void
    {
        [$me, $friend, $star] = User::factory()->count(3)->create();
        Friendship::create(['requester_id' => $me->id, 'addressee_id' => $friend->id, 'status' => 'accepted']);
        $fromFriend = $this->makePost($friend);
        $fromStar = $this->makePost($star);
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/users/{$star->id}/follow");

        $this->assertEqualsCanonicalizing([$fromFriend->id, $fromStar->id], $this->ids($this->getJson('/api/v1/feed')->json()));
        $this->assertSame([$fromFriend->id], $this->ids($this->getJson('/api/v1/feed?filter=friends')->json()));
        $this->assertSame([$fromStar->id], $this->ids($this->getJson('/api/v1/feed?filter=following')->json()));
    }

    public function test_followers_and_following_lists(): void
    {
        [$star, $a, $b, $viewer] = User::factory()->count(4)->create();
        $a->update(['name' => 'An']);
        $b->update(['name' => 'Bình']);
        foreach ([$a, $b, $viewer] as $follower) {
            DB::table('follows')->insert(['follower_id' => $follower->id, 'followee_id' => $star->id, 'created_at' => now()]);
        }
        DB::table('follows')->insert(['follower_id' => $star->id, 'followee_id' => $a->id, 'created_at' => now()]);
        $this->actingAs($viewer, 'sanctum');

        $followers = $this->getJson("/api/v1/users/{$star->id}/followers")->assertOk();
        $this->assertSame([$a->id, $b->id], $this->ids($followers->json())); // by name, without the viewer
        $this->assertFalse($followers->json('data.0.isFollowing'));
        $this->assertSame([$a->id], $this->ids($this->getJson("/api/v1/users/{$star->id}/following")->json()));

        $this->putJson("/api/v1/users/{$a->id}/follow");
        $this->assertTrue($this->getJson("/api/v1/users/{$star->id}/followers")->json('data.0.isFollowing'));

        $page = $this->getJson("/api/v1/users/{$star->id}/followers?limit=1")->assertOk();
        $this->assertTrue($page->json('meta.hasMore'));
        $this->getJson("/api/v1/users/{$star->id}/following?cursor=".urlencode($page->json('meta.nextCursor')))->assertStatus(400);
    }

    public function test_blocking_deleted_accounts_and_the_counts(): void
    {
        [$star, $a, $b, $c] = User::factory()->count(4)->create();
        foreach ([$a, $b, $c] as $follower) {
            DB::table('follows')->insert(['follower_id' => $follower->id, 'followee_id' => $star->id, 'created_at' => now()]);
        }
        $this->actingAs($star, 'sanctum');
        $this->getJson('/api/v1/me')->assertJsonPath('data.followersCount', 3);

        $b->delete(); // a deleted account is not counted or listed
        $this->getJson('/api/v1/me')->assertJsonPath('data.followersCount', 2);
        $this->assertNotContains($b->id, $this->ids($this->getJson("/api/v1/users/{$star->id}/followers")->json()));

        $this->actingAs($c, 'sanctum')->putJson("/api/v1/users/{$star->id}/block")->assertNoContent(); // blocking ends the follow
        $this->assertSame(0, DB::table('follows')->where('follower_id', $c->id)->count());
        $this->actingAs($star, 'sanctum')->getJson('/api/v1/me')->assertJsonPath('data.followersCount', 1);
    }

    public function test_a_blocked_follower_gets_no_notification(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/users/{$other->id}/block");

        CreateNotification::dispatchSync($me->id, $other->id, 'follow', dedupeKey: 'f');

        $this->assertSame(0, DB::table('notifications')->count());
    }

    public function test_follows_are_removed_with_the_account(): void
    {
        [$me, $star] = User::factory()->count(2)->create(['password' => 'secret-pass-1']);
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/users/{$star->id}/follow");
        $this->assertSame(1, DB::table('follows')->count());

        $this->deleteJson('/api/v1/me', ['password' => 'secret-pass-1'])->assertNoContent();

        $this->assertSame(0, DB::table('follows')->count());
    }
}
