<?php

namespace Tests\Feature;

use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class PostsTest extends TestCase
{
    use RefreshDatabase;

    private function befriend(User $a, User $b, string $status = 'accepted'): void
    {
        DB::table('friendships')->insert([
            'id' => (string) Str::ulid(), 'requester_id' => $a->id, 'addressee_id' => $b->id,
            'user_low_id' => min($a->id, $b->id), 'user_high_id' => max($a->id, $b->id),
            'status' => $status, 'created_at' => now(),
        ]);
    }

    private function makePost(User $author, string $privacy = 'public', string $content = 'hello', $at = null): Post
    {
        return Post::forceCreate([
            'id' => (string) Str::ulid(), 'user_id' => $author->id, 'content' => $content,
            'privacy' => $privacy, 'created_at' => $at ?? now(), 'updated_at' => now(),
        ]);
    }

    public function test_create_post_defaults_and_validation(): void
    {
        $me = User::factory()->create();

        $this->actingAs($me, 'sanctum')
            ->postJson('/api/v1/posts', ['content' => '  Xin chào  ', 'feeling' => 'excited'])
            ->assertCreated()
            ->assertHeader('Location')
            ->assertJsonPath('data.content', 'Xin chào')
            ->assertJsonPath('data.privacy', 'public')
            ->assertJsonPath('data.feeling', 'excited')
            ->assertJsonPath('data.likes', 0)
            ->assertJsonPath('data.isLiked', false)
            ->assertJsonPath('data.author.id', $me->id);

        $this->actingAs($me, 'sanctum')->postJson('/api/v1/posts', ['content' => '   '])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['content']]);
        $this->actingAs($me, 'sanctum')->postJson('/api/v1/posts', ['content' => 'x', 'privacy' => 'secret'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['privacy']]);
    }

    public function test_visibility_rules_for_show(): void
    {
        $author = User::factory()->create();
        $friend = User::factory()->create();
        $stranger = User::factory()->create();
        $this->befriend($author, $friend);
        $public = $this->makePost($author, 'public');
        $friends = $this->makePost($author, 'friends');
        $onlyMe = $this->makePost($author, 'only_me');

        $this->actingAs($stranger, 'sanctum');
        $this->getJson("/api/v1/posts/{$public->id}")->assertOk();
        $this->getJson("/api/v1/posts/{$friends->id}")->assertNotFound()->assertJsonPath('code', 'not_found');
        $this->getJson("/api/v1/posts/{$onlyMe->id}")->assertNotFound();

        $this->actingAs($friend, 'sanctum');
        $this->getJson("/api/v1/posts/{$friends->id}")->assertOk();
        $this->getJson("/api/v1/posts/{$onlyMe->id}")->assertNotFound();

        $this->actingAs($author, 'sanctum');
        $this->getJson("/api/v1/posts/{$onlyMe->id}")->assertOk();
    }

    public function test_pending_friendship_does_not_grant_access(): void
    {
        $author = User::factory()->create();
        $other = User::factory()->create();
        $this->befriend($author, $other, 'pending');
        $post = $this->makePost($author, 'friends');

        $this->actingAs($other, 'sanctum')->getJson("/api/v1/posts/{$post->id}")->assertNotFound();
    }

    public function test_delete_is_author_only(): void
    {
        $author = User::factory()->create();
        $other = User::factory()->create();
        $post = $this->makePost($author);

        $this->actingAs($other, 'sanctum')->deleteJson("/api/v1/posts/{$post->id}")
            ->assertForbidden()->assertJsonPath('code', 'forbidden');
        $this->actingAs($author, 'sanctum')->deleteJson("/api/v1/posts/{$post->id}")->assertNoContent();
        $this->actingAs($author, 'sanctum')->getJson("/api/v1/posts/{$post->id}")->assertNotFound();
        $this->assertSoftDeleted('posts', ['id' => $post->id]);
    }

    public function test_feed_contains_own_and_friends_posts_only(): void
    {
        $me = User::factory()->create();
        $friend = User::factory()->create();
        $stranger = User::factory()->create();
        $this->befriend($friend, $me);
        $mine = $this->makePost($me, 'only_me', 'mine');
        $fPublic = $this->makePost($friend, 'public', 'f-public');
        $fFriends = $this->makePost($friend, 'friends', 'f-friends');
        $this->makePost($friend, 'only_me', 'f-private');
        $this->makePost($stranger, 'public', 'stranger');

        $ids = collect($this->actingAs($me, 'sanctum')->getJson('/api/v1/feed')->assertOk()->json('data'))->pluck('id');

        $this->assertEqualsCanonicalizing([$mine->id, $fPublic->id, $fFriends->id], $ids->all());
    }

    public function test_new_account_has_empty_feed(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum')->getJson('/api/v1/feed')
            ->assertOk()->assertExactJson(['data' => [], 'meta' => ['nextCursor' => null, 'hasMore' => false]]);
    }

    public function test_feed_pagination_and_cursor_scope(): void
    {
        $me = User::factory()->create();
        foreach (range(1, 5) as $i) {
            $this->makePost($me, 'public', "post $i", now()->subMinutes(10 - $i));
        }
        $this->actingAs($me, 'sanctum');

        $page1 = $this->getJson('/api/v1/feed?limit=2')->assertOk();
        $this->assertSame(['post 5', 'post 4'], array_column($page1->json('data'), 'content'));
        $this->assertTrue($page1->json('meta.hasMore'));

        $cursor = $page1->json('meta.nextCursor');
        $page2 = $this->getJson('/api/v1/feed?limit=2&cursor='.$cursor)->assertOk();
        $this->assertSame(['post 3', 'post 2'], array_column($page2->json('data'), 'content'));

        $page3 = $this->getJson('/api/v1/feed?limit=2&cursor='.$page2->json('meta.nextCursor'))->assertOk();
        $this->assertSame(['post 1'], array_column($page3->json('data'), 'content'));
        $this->assertNull($page3->json('meta.nextCursor'));

        $this->getJson('/api/v1/feed?limit=2&q=post&cursor='.$cursor)->assertStatus(400)->assertJsonPath('code', 'invalid_cursor');
        $this->getJson('/api/v1/feed?cursor=garbage')->assertStatus(400);
        $this->getJson('/api/v1/feed?limit=99')->assertStatus(422);
    }

    public function test_feed_search_is_accent_insensitive_and_escapes_wildcards(): void
    {
        $me = User::factory()->create(['name' => 'Tên Khác']);
        $this->makePost($me, 'public', 'Ngày đẹp với Mình');
        $this->makePost($me, 'public', '100% vui');
        $this->makePost($me, 'public', 'other');
        $this->actingAs($me, 'sanctum');

        $this->assertCount(1, $this->getJson('/api/v1/feed?q=minh')->json('data'));
        $this->assertCount(1, $this->getJson('/api/v1/feed?q=100%25')->json('data'));
        $this->assertCount(1, $this->getJson('/api/v1/feed?q=%25')->json('data'));
        $this->assertCount(3, $this->getJson('/api/v1/feed?q=khac')->json('data')); // author name match
    }

    public function test_like_is_idempotent_and_counts_once(): void
    {
        $author = User::factory()->create();
        $me = User::factory()->create();
        $post = $this->makePost($author);
        $this->actingAs($me, 'sanctum');

        $this->putJson("/api/v1/posts/{$post->id}/like")->assertOk()->assertExactJson(['data' => ['isLiked' => true, 'likes' => 1]]);
        $this->putJson("/api/v1/posts/{$post->id}/like")->assertOk()->assertJsonPath('data.likes', 1);
        $this->getJson("/api/v1/posts/{$post->id}")->assertJsonPath('data.isLiked', true);

        $this->deleteJson("/api/v1/posts/{$post->id}/like")->assertOk()->assertExactJson(['data' => ['isLiked' => false, 'likes' => 0]]);
        $this->deleteJson("/api/v1/posts/{$post->id}/like")->assertOk()->assertJsonPath('data.likes', 0);
    }

    public function test_like_notifies_author_once_and_never_self(): void
    {
        $author = User::factory()->create();
        $me = User::factory()->create();
        $post = $this->makePost($author);

        $this->actingAs($me, 'sanctum');
        $this->putJson("/api/v1/posts/{$post->id}/like");
        $this->deleteJson("/api/v1/posts/{$post->id}/like");
        $this->putJson("/api/v1/posts/{$post->id}/like");
        $this->assertSame(1, DB::table('notifications')->where(['user_id' => $author->id, 'type' => 'like'])->count());

        $this->actingAs($author, 'sanctum')->putJson("/api/v1/posts/{$post->id}/like");
        $this->assertSame(1, DB::table('notifications')->count());
    }

    public function test_cannot_like_invisible_post(): void
    {
        $author = User::factory()->create();
        $post = $this->makePost($author, 'only_me');

        $this->actingAs(User::factory()->create(), 'sanctum')->putJson("/api/v1/posts/{$post->id}/like")->assertNotFound();
        $this->assertSame(0, $post->fresh()->likes_count);
    }

    public function test_save_and_hide_affect_only_the_caller(): void
    {
        $me = User::factory()->create();
        $friend = User::factory()->create();
        $this->befriend($me, $friend);
        $post = $this->makePost($friend);

        $this->actingAs($me, 'sanctum');
        $this->putJson("/api/v1/posts/{$post->id}/save")->assertOk()->assertExactJson(['data' => ['isSaved' => true]]);
        $this->putJson("/api/v1/posts/{$post->id}/save")->assertOk();
        $this->putJson("/api/v1/posts/{$post->id}/hide")->assertOk()->assertExactJson(['data' => ['isHidden' => true]]);

        $this->assertCount(0, $this->getJson('/api/v1/feed')->json('data'));
        $this->getJson("/api/v1/posts/{$post->id}")->assertJsonPath('data.isHidden', true)->assertJsonPath('data.isSaved', true);

        $this->actingAs($friend, 'sanctum');
        $this->assertCount(1, $this->getJson('/api/v1/feed')->json('data'));
        $this->getJson("/api/v1/posts/{$post->id}")->assertJsonPath('data.isHidden', false);

        $this->actingAs($me, 'sanctum');
        $this->deleteJson("/api/v1/posts/{$post->id}/hide")->assertOk()->assertJsonPath('data.isHidden', false);
        $this->deleteJson("/api/v1/posts/{$post->id}/save")->assertOk()->assertJsonPath('data.isSaved', false);
        $this->assertCount(1, $this->getJson('/api/v1/feed')->json('data'));
    }

    public function test_deleting_post_removes_its_notifications(): void
    {
        $author = User::factory()->create();
        $post = $this->makePost($author);
        $this->actingAs(User::factory()->create(), 'sanctum')->putJson("/api/v1/posts/{$post->id}/like");
        $this->assertSame(1, DB::table('notifications')->count());

        $this->actingAs($author, 'sanctum')->deleteJson("/api/v1/posts/{$post->id}")->assertNoContent();
        $this->assertSame(0, DB::table('notifications')->count());
    }

    public function test_posts_require_authentication(): void
    {
        $this->getJson('/api/v1/feed')->assertStatus(401);
        $this->postJson('/api/v1/posts', ['content' => 'x'])->assertStatus(401);
    }
}
