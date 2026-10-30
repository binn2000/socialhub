<?php

namespace Tests\Feature;

use App\Jobs\CreateNotification;
use App\Models\Comment;
use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class BlocksReportsPrivacyTest extends TestCase
{
    use RefreshDatabase;

    private function makePost(User $author, string $privacy = 'public', string $content = 'hello'): Post
    {
        return Post::forceCreate([
            'id' => strtolower((string) Str::ulid()), 'user_id' => $author->id, 'content' => $content,
            'privacy' => $privacy, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function befriend(User $a, User $b): void
    {
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'accepted']);
    }

    private function comment(Post $post, User $author, string $text = 'nice'): Comment
    {
        return Comment::forceCreate([
            'id' => strtolower((string) Str::ulid()), 'post_id' => $post->id, 'user_id' => $author->id,
            'content' => $text, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function ids(array $response): array
    {
        return array_column($response['data'], 'id');
    }

    // ---- changing the privacy of a post

    public function test_the_author_can_change_privacy_and_everyone_follows(): void
    {
        [$author, $friend, $stranger] = User::factory()->count(3)->create();
        $this->befriend($author, $friend);
        $post = $this->makePost($author);

        $this->actingAs($author, 'sanctum')->patchJson("/api/v1/posts/{$post->id}", ['privacy' => 'only_me'])
            ->assertOk()->assertJsonPath('data.privacy', 'only_me');
        $this->assertSame('only_me', $post->fresh()->privacy);

        $this->actingAs($author, 'sanctum')->getJson("/api/v1/posts/{$post->id}")->assertOk();
        foreach ([$friend, $stranger] as $other) {
            $this->actingAs($other, 'sanctum');
            $this->getJson("/api/v1/posts/{$post->id}")->assertNotFound();
            $this->assertNotContains($post->id, $this->ids($this->getJson('/api/v1/feed')->json()));
            $this->assertNotContains($post->id, $this->ids($this->getJson('/api/v1/explore')->json()));
        }

        $this->actingAs($author, 'sanctum')->patchJson("/api/v1/posts/{$post->id}", ['privacy' => 'friends'])->assertOk();
        $this->actingAs($friend, 'sanctum')->getJson("/api/v1/posts/{$post->id}")->assertOk();
        $this->actingAs($stranger, 'sanctum')->getJson("/api/v1/posts/{$post->id}")->assertNotFound();
        $this->assertNotContains($post->id, $this->ids($this->getJson('/api/v1/explore')->json()));

        $this->actingAs($author, 'sanctum')->patchJson("/api/v1/posts/{$post->id}", ['privacy' => 'public'])->assertOk();
        $this->actingAs($stranger, 'sanctum')->getJson("/api/v1/posts/{$post->id}")->assertOk();
        $this->assertContains($post->id, $this->ids($this->getJson('/api/v1/explore')->json()));
    }

    public function test_only_the_author_can_change_privacy(): void
    {
        [$author, $friend, $stranger] = User::factory()->count(3)->create();
        $this->befriend($author, $friend);
        $post = $this->makePost($author, 'friends');

        $this->actingAs($friend, 'sanctum')->patchJson("/api/v1/posts/{$post->id}", ['privacy' => 'public'])
            ->assertForbidden()->assertJsonPath('code', 'forbidden');
        $this->actingAs($stranger, 'sanctum')->patchJson("/api/v1/posts/{$post->id}", ['privacy' => 'public'])->assertNotFound();
        $this->assertSame('friends', $post->fresh()->privacy);
    }

    public function test_the_privacy_value_is_checked(): void
    {
        $author = User::factory()->create();
        $post = $this->makePost($author);
        $this->actingAs($author, 'sanctum');

        $this->patchJson("/api/v1/posts/{$post->id}", ['privacy' => 'everyone'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['privacy']]);
        $this->patchJson("/api/v1/posts/{$post->id}", [])->assertStatus(422);
        $this->patchJson("/api/v1/posts/{$post->id}", ['privacy' => 'public'])->assertOk(); // same value
        $this->patchJson('/api/v1/posts/nope', ['privacy' => 'public'])->assertNotFound();

        $this->app['auth']->forgetGuards();
        $this->patchJson("/api/v1/posts/{$post->id}", ['privacy' => 'public'])->assertUnauthorized();
    }

    // ---- blocking

    public function test_blocking_ends_the_friendship_and_is_idempotent(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        $this->befriend($me, $other);
        $this->actingAs($me, 'sanctum');

        $this->putJson("/api/v1/users/{$other->id}/block")->assertNoContent();
        $this->putJson("/api/v1/users/{$other->id}/block")->assertNoContent();

        $this->assertSame(1, DB::table('user_blocks')->count());
        $this->assertSame(0, DB::table('friendships')->count());

        $this->deleteJson("/api/v1/users/{$other->id}/block")->assertNoContent();
        $this->deleteJson("/api/v1/users/{$other->id}/block")->assertNoContent();
        $this->assertSame(0, DB::table('user_blocks')->count());
        $this->assertSame(0, DB::table('friendships')->count()); // not restored
    }

    public function test_a_pending_request_is_dropped_too_and_input_is_checked(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        Friendship::create(['requester_id' => $other->id, 'addressee_id' => $me->id, 'status' => 'pending']);
        $this->actingAs($me, 'sanctum');

        $this->putJson("/api/v1/users/{$me->id}/block")->assertStatus(422)->assertJsonStructure(['errors' => ['userId']]);
        $this->putJson('/api/v1/users/nobody/block')->assertNotFound();
        $this->putJson("/api/v1/users/{$other->id}/block")->assertNoContent();

        $this->assertSame(0, DB::table('friendships')->count());
        $this->assertCount(0, $this->getJson('/api/v1/friend-requests')->json('data'));

        $this->app['auth']->forgetGuards();
        $this->putJson("/api/v1/users/{$other->id}/block")->assertUnauthorized();
    }

    public function test_blocked_people_cannot_see_each_others_posts(): void
    {
        [$me, $other, $bystander] = User::factory()->count(3)->create();
        $mine = $this->makePost($me, 'public', 'mine');
        $theirs = $this->makePost($other, 'public', 'theirs');
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/users/{$other->id}/block")->assertNoContent();

        $this->actingAs($me, 'sanctum');
        $this->getJson("/api/v1/posts/{$theirs->id}")->assertNotFound();
        $this->assertNotContains($theirs->id, $this->ids($this->getJson('/api/v1/explore')->json()));
        $this->assertNotContains($theirs->id, $this->ids($this->getJson('/api/v1/feed')->json()));
        $this->assertSame([], $this->getJson("/api/v1/users/{$other->id}/posts")->json('data'));

        $this->actingAs($other, 'sanctum');
        $this->getJson("/api/v1/posts/{$mine->id}")->assertNotFound();
        $this->assertNotContains($mine->id, $this->ids($this->getJson('/api/v1/explore')->json()));
        $this->getJson("/api/v1/users/{$me->id}/posts")->assertNotFound();

        // everyone else is untouched
        $this->actingAs($bystander, 'sanctum');
        $this->assertEqualsCanonicalizing([$mine->id, $theirs->id], $this->ids($this->getJson('/api/v1/explore')->json()));

        // unblocking brings the posts back
        $this->actingAs($me, 'sanctum')->deleteJson("/api/v1/users/{$other->id}/block")->assertNoContent();
        $this->getJson("/api/v1/posts/{$theirs->id}")->assertOk();
    }

    public function test_profiles_and_user_lists_respect_blocks(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/users/{$other->id}/block");

        // the blocker still opens the profile (to unblock) and sees the flag
        $this->getJson("/api/v1/users/{$other->id}")->assertOk()->assertJsonPath('data.isBlocked', true);
        $this->assertNotContains($other->id, $this->ids($this->getJson('/api/v1/users')->json()));
        $this->assertSame([], $this->getJson('/api/v1/users?q='.urlencode($other->name))->json('data'));

        // the blocked person cannot find the blocker at all
        $this->actingAs($other, 'sanctum');
        $this->getJson("/api/v1/users/{$me->id}")->assertNotFound();
        $this->assertNotContains($me->id, $this->ids($this->getJson('/api/v1/users')->json()));

        $this->actingAs($me, 'sanctum')->deleteJson("/api/v1/users/{$other->id}/block");
        $this->getJson("/api/v1/users/{$other->id}")->assertOk()->assertJsonPath('data.isBlocked', false);
    }

    public function test_comments_of_a_blocked_person_are_hidden(): void
    {
        [$me, $other, $third] = User::factory()->count(3)->create();
        $post = $this->makePost($third);
        $this->comment($post, $me, 'from me');
        $this->comment($post, $other, 'from them');
        $this->comment($post, $third, 'from author');
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/users/{$other->id}/block");

        $texts = fn () => array_column($this->getJson("/api/v1/posts/{$post->id}/comments")->json('data'), 'content');
        $this->assertEqualsCanonicalizing(['from me', 'from author'], $texts());
        $this->actingAs($other, 'sanctum');
        $this->assertEqualsCanonicalizing(['from them', 'from author'], $texts());
    }

    public function test_no_friend_request_can_pass_a_block(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/users/{$other->id}/block");

        $this->postJson('/api/v1/friend-requests', ['userId' => $other->id])->assertStatus(422);
        $this->actingAs($other, 'sanctum')->postJson('/api/v1/friend-requests', ['userId' => $me->id])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['userId']]);
        $this->assertSame(0, DB::table('friendships')->count());
    }

    public function test_a_conversation_with_a_blocked_person_disappears(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        $this->befriend($me, $other);
        $conversation = $this->actingAs($me, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $other->id])->json('data.id');
        $this->postJson("/api/v1/conversations/$conversation/messages", ['text' => 'hi'])->assertCreated();
        $this->assertCount(1, $this->getJson('/api/v1/conversations')->json('data'));

        $this->putJson("/api/v1/users/{$other->id}/block")->assertNoContent();

        $this->assertCount(0, $this->getJson('/api/v1/conversations')->json('data'));
        $this->postJson("/api/v1/conversations/$conversation/messages", ['text' => 'still there?'])->assertForbidden();
        $this->actingAs($other, 'sanctum');
        $this->assertCount(0, $this->getJson('/api/v1/conversations')->json('data'));
        $this->postJson("/api/v1/conversations/$conversation/messages", ['text' => 'hello?'])->assertForbidden();
        $this->postJson('/api/v1/conversations', ['userId' => $me->id])->assertForbidden();
    }

    public function test_notifications_do_not_cross_a_block(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        $post = $this->makePost($me);
        CreateNotification::dispatchSync($me->id, $other->id, 'like', postId: $post->id, dedupeKey: 'like:1');
        $this->actingAs($me, 'sanctum');
        $this->assertCount(1, $this->getJson('/api/v1/notifications')->json('data'));

        $this->putJson("/api/v1/users/{$other->id}/block");
        $this->assertCount(0, $this->getJson('/api/v1/notifications')->json('data'));

        // and no new row appears while blocked
        CreateNotification::dispatchSync($me->id, $other->id, 'comment', postId: $post->id);
        $this->assertSame(1, DB::table('notifications')->count());
    }

    public function test_the_block_list_pages_and_skips_deleted_accounts(): void
    {
        $me = User::factory()->create();
        $others = User::factory()->count(3)->create();
        $this->actingAs($me, 'sanctum');
        foreach ($others as $other) {
            $this->putJson("/api/v1/users/{$other->id}/block")->assertNoContent();
        }
        $others[0]->delete(); // the account was deleted

        $first = $this->getJson('/api/v1/me/blocks?limit=1')->assertOk();
        $this->assertSame([$others[2]->id], $this->ids($first->json())); // newest block first
        $this->assertTrue($first->json('meta.hasMore'));

        $second = $this->getJson('/api/v1/me/blocks?limit=1&cursor='.urlencode($first->json('meta.nextCursor')))->assertOk();
        $this->assertSame([$others[1]->id], $this->ids($second->json()));
        $this->assertFalse($second->json('meta.hasMore'));
        $this->assertNull($second->json('meta.nextCursor'));

        $this->assertArrayNotHasKey('email', $first->json('data.0'));
    }

    // ---- reports

    public function test_reporting_a_post_a_comment_and_a_user(): void
    {
        [$me, $author] = User::factory()->count(2)->create();
        $post = $this->makePost($author);
        $comment = $this->comment($post, $author);
        $this->actingAs($me, 'sanctum');

        $report = $this->postJson('/api/v1/reports', [
            'targetType' => 'post', 'targetId' => $post->id, 'reason' => 'spam', 'details' => '  quảng cáo  ',
        ])->assertCreated()->assertJsonPath('data.targetType', 'post')->assertJsonPath('data.reason', 'spam');
        $this->assertDatabaseHas('reports', [
            'id' => $report->json('data.id'), 'reporter_id' => $me->id, 'target_id' => $post->id,
            'details' => 'quảng cáo', 'status' => 'open',
        ]);

        $this->postJson('/api/v1/reports', ['targetType' => 'comment', 'targetId' => $comment->id, 'reason' => 'harassment'])->assertCreated();
        $this->postJson('/api/v1/reports', ['targetType' => 'user', 'targetId' => $author->id, 'reason' => 'other'])->assertCreated();
        $this->assertSame(3, DB::table('reports')->count());
    }

    public function test_the_same_report_is_not_stored_twice(): void
    {
        [$me, $author] = User::factory()->count(2)->create();
        $post = $this->makePost($author);
        $body = ['targetType' => 'post', 'targetId' => $post->id, 'reason' => 'spam'];
        $this->actingAs($me, 'sanctum');

        $first = $this->postJson('/api/v1/reports', $body)->assertCreated();
        $again = $this->postJson('/api/v1/reports', [...$body, 'reason' => 'hate'])->assertOk();

        $this->assertSame($first->json('data.id'), $again->json('data.id'));
        $this->assertSame('spam', $again->json('data.reason'));
        $this->assertSame(1, DB::table('reports')->count());
    }

    public function test_reports_are_checked(): void
    {
        [$me, $author, $stranger] = User::factory()->count(3)->create();
        $private = $this->makePost($author, 'only_me');
        $own = $this->makePost($me);
        $this->actingAs($me, 'sanctum');

        $this->postJson('/api/v1/reports', ['targetType' => 'post', 'targetId' => $private->id, 'reason' => 'spam'])->assertNotFound();
        $this->postJson('/api/v1/reports', ['targetType' => 'post', 'targetId' => 'missing', 'reason' => 'spam'])->assertNotFound();
        $this->postJson('/api/v1/reports', ['targetType' => 'post', 'targetId' => $own->id, 'reason' => 'spam'])->assertStatus(422);
        $this->postJson('/api/v1/reports', ['targetType' => 'user', 'targetId' => $me->id, 'reason' => 'spam'])->assertStatus(422);
        $this->postJson('/api/v1/reports', ['targetType' => 'user', 'targetId' => 'missing', 'reason' => 'spam'])->assertNotFound();
        $this->postJson('/api/v1/reports', ['targetType' => 'page', 'targetId' => $author->id, 'reason' => 'spam'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['targetType']]);
        $this->postJson('/api/v1/reports', ['targetType' => 'user', 'targetId' => $author->id, 'reason' => 'boring'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['reason']]);
        $this->postJson('/api/v1/reports', ['targetType' => 'user', 'targetId' => $author->id, 'reason' => 'spam', 'details' => str_repeat('x', 501)])
            ->assertStatus(422);
        $this->assertSame(0, DB::table('reports')->count());

        // a user who blocked the reporter cannot be reported (looks missing)
        $this->actingAs($stranger, 'sanctum')->putJson("/api/v1/users/{$me->id}/block");
        $this->actingAs($me, 'sanctum')->postJson('/api/v1/reports', ['targetType' => 'user', 'targetId' => $stranger->id, 'reason' => 'spam'])->assertNotFound();

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/reports', ['targetType' => 'user', 'targetId' => $author->id, 'reason' => 'spam'])->assertUnauthorized();
    }

    public function test_reports_are_rate_limited(): void
    {
        $me = User::factory()->create();
        $targets = User::factory()->count(21)->create();
        $this->actingAs($me, 'sanctum');

        foreach ($targets->take(20) as $target) {
            $this->postJson('/api/v1/reports', ['targetType' => 'user', 'targetId' => $target->id, 'reason' => 'spam'])->assertCreated();
        }

        $this->postJson('/api/v1/reports', ['targetType' => 'user', 'targetId' => $targets[20]->id, 'reason' => 'spam'])
            ->assertStatus(429)->assertHeader('Retry-After');
    }
}
