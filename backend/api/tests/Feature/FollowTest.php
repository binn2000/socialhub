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

    // ---- friends follow each other

    /** Sends a request from $from to $to through the API and returns its id. */
    private function requestFriendship(User $from, User $to): string
    {
        return $this->actingAs($from, 'sanctum')->postJson('/api/v1/friend-requests', ['userId' => $to->id])
            ->assertCreated()->json('data.id');
    }

    private function accept(User $by, string $requestId): void
    {
        $this->actingAs($by, 'sanctum')->postJson("/api/v1/friend-requests/$requestId/accept")->assertOk();
    }

    private function follows(User $follower, User $followee): bool
    {
        return DB::table('follows')->where('follower_id', $follower->id)->where('followee_id', $followee->id)->exists();
    }

    public function test_accepting_a_request_makes_both_follow_each_other_quietly(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $request = $this->requestFriendship($a, $b);
        $this->assertFalse($this->follows($a, $b)); // sending alone follows nobody

        $this->accept($b, $request);

        $this->assertTrue($this->follows($a, $b));
        $this->assertTrue($this->follows($b, $a));
        $this->assertSame(2, DB::table('follows')->count());
        $this->assertSame(0, DB::table('notifications')->where('type', 'follow')->count());
        $this->assertSame(1, DB::table('notifications')->where('type', 'friend_accepted')->count());

        $this->actingAs($a, 'sanctum')->getJson("/api/v1/users/{$b->id}")->assertJsonPath('data.isFollowing', true)->assertJsonPath('data.followsYou', true)
            ->assertJsonPath('data.followersCount', 1)->assertJsonPath('data.followingCount', 1);
    }

    public function test_a_follow_that_exists_is_kept_and_not_doubled(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $this->actingAs($a, 'sanctum')->putJson("/api/v1/users/{$b->id}/follow")->assertNoContent();
        $this->assertSame(1, DB::table('notifications')->where('type', 'follow')->count());

        $this->accept($b, $this->requestFriendship($a, $b));

        $this->assertSame(2, DB::table('follows')->count()); // A to B once, B to A added
        $this->assertSame(1, DB::table('follows')->where('follower_id', $a->id)->where('followee_id', $b->id)->count());
        $this->assertSame(1, DB::table('notifications')->where('type', 'follow')->count()); // no second one
    }

    public function test_accepting_twice_changes_nothing(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $request = $this->requestFriendship($a, $b);
        $this->accept($b, $request);
        DB::table('follows')->where('follower_id', $b->id)->delete(); // B unfollows A

        $this->accept($b, $request); // a repeated tap on an old request

        $this->assertFalse($this->follows($b, $a)); // the unfollow stands
    }

    public function test_declining_or_cancelling_creates_no_follow(): void
    {
        [$a, $b, $c] = User::factory()->count(3)->create();
        $declined = $this->requestFriendship($a, $b);
        $this->actingAs($b, 'sanctum')->deleteJson("/api/v1/friend-requests/$declined")->assertNoContent();
        $cancelled = $this->requestFriendship($a, $c);
        $this->actingAs($a, 'sanctum')->deleteJson("/api/v1/friend-requests/$cancelled")->assertNoContent();

        $this->assertSame(0, DB::table('follows')->count());
    }

    public function test_unfriending_keeps_the_follows_and_unfollowing_keeps_the_friendship(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $this->accept($b, $this->requestFriendship($a, $b));

        $this->actingAs($a, 'sanctum')->deleteJson("/api/v1/friends/{$b->id}")->assertNoContent();
        $this->assertSame(0, DB::table('friendships')->count());
        $this->assertTrue($this->follows($a, $b));
        $this->assertTrue($this->follows($b, $a));

        $c = User::factory()->create();
        $this->accept($c, $this->requestFriendship($a, $c));
        $this->actingAs($a, 'sanctum')->deleteJson("/api/v1/users/{$c->id}/follow")->assertNoContent();
        $this->assertSame(1, DB::table('friendships')->where('status', 'accepted')->count());
        $this->assertFalse($this->follows($a, $c));
        $this->assertTrue($this->follows($c, $a));
    }

    public function test_becoming_friends_again_follows_again(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $this->accept($b, $this->requestFriendship($a, $b));
        $this->actingAs($a, 'sanctum')->deleteJson("/api/v1/users/{$b->id}/follow");
        $this->deleteJson("/api/v1/friends/{$b->id}");

        $this->accept($b, $this->requestFriendship($a, $b));

        $this->assertTrue($this->follows($a, $b));
    }

    public function test_blocking_still_ends_both_the_friendship_and_the_follows(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $this->accept($b, $this->requestFriendship($a, $b));

        $this->actingAs($a, 'sanctum')->putJson("/api/v1/users/{$b->id}/block")->assertNoContent();

        $this->assertSame(0, DB::table('friendships')->count());
        $this->assertSame(0, DB::table('follows')->count());
    }

    public function test_a_new_friend_shows_in_both_the_friends_and_following_tabs(): void
    {
        [$me, $friend] = User::factory()->count(2)->create();
        $post = $this->makePost($friend);
        $this->accept($me, $this->requestFriendship($friend, $me));
        $this->actingAs($me, 'sanctum');

        $this->assertSame([$post->id], $this->ids($this->getJson('/api/v1/feed?filter=friends')->json()));
        $this->assertSame([$post->id], $this->ids($this->getJson('/api/v1/feed?filter=following')->json()));
        $this->assertSame([$post->id], $this->ids($this->getJson('/api/v1/feed')->json())); // listed once
    }

    public function test_the_migration_makes_existing_friends_follow_each_other(): void
    {
        [$a, $b, $c, $d] = User::factory()->count(4)->create();
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'accepted']);
        Friendship::create(['requester_id' => $c->id, 'addressee_id' => $a->id, 'status' => 'accepted']);
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $d->id, 'status' => 'pending']);
        DB::table('follows')->insert(['follower_id' => $a->id, 'followee_id' => $b->id, 'created_at' => now()->subYear()]);
        $migration = require database_path('migrations').'/'.collect(scandir(database_path('migrations')))
            ->first(fn ($file) => str_contains($file, 'follow_between_existing_friends'));

        $migration->up();
        $migration->up(); // running it again changes nothing

        $this->assertSame(4, DB::table('follows')->count());
        foreach ([[$a, $b], [$b, $a], [$c, $a], [$a, $c]] as [$follower, $followee]) {
            $this->assertTrue($this->follows($follower, $followee));
        }
        $this->assertFalse($this->follows($a, $d)); // a pending request is not a friendship
        $this->assertTrue(DB::table('follows')->where('follower_id', $a->id)->where('followee_id', $b->id)->value('created_at') < now()->subMonths(6)->toDateTimeString()); // the old row kept its date
        $this->assertSame(0, DB::table('notifications')->count());
    }
}
