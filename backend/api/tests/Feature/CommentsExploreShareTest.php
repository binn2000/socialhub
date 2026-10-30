<?php

namespace Tests\Feature;

use App\Models\Comment;
use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class CommentsExploreShareTest extends TestCase
{
    use RefreshDatabase;

    private function makePost(User $u, string $privacy = 'public', string $content = 'hello', array $extra = []): Post
    {
        return Post::forceCreate($extra + [
            'id' => (string) Str::ulid(), 'user_id' => $u->id, 'content' => $content,
            'privacy' => $privacy, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    public function test_comment_create_list_and_counter(): void
    {
        [$author, $me] = User::factory()->count(2)->create();
        $post = $this->makePost($author);
        $this->actingAs($me, 'sanctum');

        $this->postJson("/api/v1/posts/{$post->id}/comments", ['content' => '  Hay quá!  '])
            ->assertCreated()
            ->assertJsonPath('data.content', 'Hay quá!')
            ->assertJsonPath('data.postId', $post->id)
            ->assertJsonPath('data.author.id', $me->id)
            ->assertJsonPath('meta.commentsCount', 1);
        $this->postJson("/api/v1/posts/{$post->id}/comments", ['content' => 'second'])->assertJsonPath('meta.commentsCount', 2);

        $this->getJson("/api/v1/posts/{$post->id}")->assertJsonPath('data.comments', 2);
        $this->assertSame(['second', 'Hay quá!'], array_column($this->getJson("/api/v1/posts/{$post->id}/comments")->json('data'), 'content'));
        $this->assertSame(2, DB::table('notifications')->where(['user_id' => $author->id, 'type' => 'comment'])->count());
    }

    public function test_comment_validation_and_self_comment_does_not_notify(): void
    {
        $me = User::factory()->create();
        $post = $this->makePost($me);
        $this->actingAs($me, 'sanctum');

        $this->postJson("/api/v1/posts/{$post->id}/comments", ['content' => '   '])->assertStatus(422)->assertJsonStructure(['errors' => ['content']]);
        $this->postJson("/api/v1/posts/{$post->id}/comments", ['content' => str_repeat('a', 1001)])->assertStatus(422);
        $this->postJson("/api/v1/posts/{$post->id}/comments", ['content' => 'mine'])->assertCreated();
        $this->assertSame(0, DB::table('notifications')->count());
    }

    public function test_comments_follow_post_visibility(): void
    {
        [$author, $stranger] = User::factory()->count(2)->create();
        $private = $this->makePost($author, 'only_me');
        $this->actingAs($stranger, 'sanctum');

        $this->getJson("/api/v1/posts/{$private->id}/comments")->assertNotFound();
        $this->postJson("/api/v1/posts/{$private->id}/comments", ['content' => 'x'])->assertNotFound();
        $this->assertSame(0, $private->fresh()->comments_count);
    }

    public function test_comment_pagination(): void
    {
        [$author, $me] = User::factory()->count(2)->create();
        $post = $this->makePost($author);
        foreach (range(1, 3) as $i) {
            Comment::forceCreate(['id' => (string) Str::ulid(), 'post_id' => $post->id, 'user_id' => $me->id, 'content' => "c$i", 'created_at' => now()->subMinutes(10 - $i)]);
        }
        $this->actingAs($me, 'sanctum');

        $p1 = $this->getJson("/api/v1/posts/{$post->id}/comments?limit=2")->assertOk();
        $this->assertSame(['c3', 'c2'], array_column($p1->json('data'), 'content'));
        $p2 = $this->getJson("/api/v1/posts/{$post->id}/comments?limit=2&cursor=".$p1->json('meta.nextCursor'));
        $this->assertSame(['c1'], array_column($p2->json('data'), 'content'));
        $this->assertFalse($p2->json('meta.hasMore'));
    }

    public function test_comment_delete_permissions(): void
    {
        [$postAuthor, $commenter, $bystander] = User::factory()->count(3)->create();
        $post = $this->makePost($postAuthor);
        $mk = function () use ($post, $commenter) {
            $this->actingAs($commenter, 'sanctum')->postJson("/api/v1/posts/{$post->id}/comments", ['content' => 'x']);

            return Comment::latest('id')->first();
        };

        $c = $mk();
        $this->actingAs($bystander, 'sanctum')->deleteJson("/api/v1/comments/{$c->id}")->assertForbidden()->assertJsonPath('code', 'forbidden');
        $this->actingAs($commenter, 'sanctum')->deleteJson("/api/v1/comments/{$c->id}")->assertNoContent();
        $this->assertSame(0, $post->fresh()->comments_count);
        $this->assertSame(0, DB::table('notifications')->count());
        $this->actingAs($commenter, 'sanctum')->deleteJson("/api/v1/comments/{$c->id}")->assertNotFound();

        $c2 = $mk();
        $this->actingAs($postAuthor, 'sanctum')->deleteJson("/api/v1/comments/{$c2->id}")->assertNoContent(); // post author may moderate
        $this->assertSame(0, $post->fresh()->comments_count);
    }

    public function test_comment_on_invisible_post_cannot_be_deleted(): void
    {
        [$author, $other] = User::factory()->count(2)->create();
        $post = $this->makePost($author, 'only_me');
        $c = Comment::forceCreate(['id' => (string) Str::ulid(), 'post_id' => $post->id, 'user_id' => $author->id, 'content' => 'x', 'created_at' => now()]);

        $this->actingAs($other, 'sanctum')->deleteJson("/api/v1/comments/{$c->id}")->assertNotFound();
    }

    public function test_explore_for_you_shows_only_public_posts_including_own_and_hidden(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        $mine = $this->makePost($me, 'public', 'mine');
        $theirs = $this->makePost($other, 'public', 'theirs');
        $this->makePost($other, 'friends', 'friends-only');
        $this->makePost($me, 'only_me', 'private');
        DB::table('post_hidden')->insert(['post_id' => $theirs->id, 'user_id' => $me->id]);

        $data = $this->actingAs($me, 'sanctum')->getJson('/api/v1/explore')->assertOk()->json('data');
        $this->assertEqualsCanonicalizing(['mine', 'theirs'], array_column($data, 'content'));
        $this->assertTrue(collect($data)->firstWhere('content', 'theirs')['isHidden']);
    }

    public function test_explore_search_and_pagination(): void
    {
        $me = User::factory()->create(['name' => 'Someone']);
        foreach (range(1, 3) as $i) {
            $this->makePost($me, 'public', "Mình $i", ['created_at' => now()->subMinutes(10 - $i)]);
        }
        $this->makePost($me, 'public', 'other');
        $this->actingAs($me, 'sanctum');

        $this->assertCount(3, $this->getJson('/api/v1/explore?q=minh')->json('data'));
        $p1 = $this->getJson('/api/v1/explore?limit=3')->assertOk();
        $this->assertTrue($p1->json('meta.hasMore'));
        $this->assertCount(1, $this->getJson('/api/v1/explore?limit=3&cursor='.$p1->json('meta.nextCursor'))->json('data'));
        $this->getJson('/api/v1/explore?limit=3&q=x&cursor='.$p1->json('meta.nextCursor'))->assertStatus(400);
        $this->getJson('/api/v1/explore?filter=bogus')->assertStatus(422);
    }

    public function test_explore_trending_is_recent_and_most_liked_first(): void
    {
        $me = User::factory()->create();
        $this->makePost($me, 'public', 'old but huge', ['likes_count' => 999, 'created_at' => now()->subDays(8)]);
        $this->makePost($me, 'public', 'low', ['likes_count' => 1]);
        $this->makePost($me, 'public', 'top', ['likes_count' => 50]);
        $this->makePost($me, 'public', 'mid', ['likes_count' => 5]);
        $this->actingAs($me, 'sanctum');

        $this->assertSame(['top', 'mid', 'low'], array_column($this->getJson('/api/v1/explore?filter=trending')->json('data'), 'content'));

        $p1 = $this->getJson('/api/v1/explore?filter=trending&limit=2');
        $this->assertSame(['top', 'mid'], array_column($p1->json('data'), 'content'));
        $p2 = $this->getJson('/api/v1/explore?filter=trending&limit=2&cursor='.$p1->json('meta.nextCursor'));
        $this->assertSame(['low'], array_column($p2->json('data'), 'content'));
    }

    public function test_explore_short_video_is_empty(): void
    {
        $me = User::factory()->create();
        $this->makePost($me);

        $this->actingAs($me, 'sanctum')->getJson('/api/v1/explore?filter=short_video')
            ->assertOk()->assertExactJson(['data' => [], 'meta' => ['nextCursor' => null, 'hasMore' => false]]);
    }

    public function test_share_counts_once_per_user_and_notifies_author(): void
    {
        [$author, $me, $other] = User::factory()->count(3)->create();
        $post = $this->makePost($author);

        $this->actingAs($me, 'sanctum');
        $this->postJson("/api/v1/posts/{$post->id}/shares", ['target' => 'message'])->assertOk()->assertExactJson(['data' => ['shares' => 1]]);
        $this->postJson("/api/v1/posts/{$post->id}/shares")->assertOk()->assertJsonPath('data.shares', 1);
        $this->actingAs($other, 'sanctum')->postJson("/api/v1/posts/{$post->id}/shares")->assertJsonPath('data.shares', 2);
        $this->assertSame(2, DB::table('notifications')->where(['user_id' => $author->id, 'type' => 'share'])->count());

        $this->actingAs($author, 'sanctum')->postJson("/api/v1/posts/{$post->id}/shares")->assertJsonPath('data.shares', 3);
        $this->assertSame(2, DB::table('notifications')->where('type', 'share')->count());
        $this->getJson("/api/v1/posts/{$post->id}")->assertJsonPath('data.shares', 3);
    }

    public function test_share_validation_and_visibility(): void
    {
        [$author, $other] = User::factory()->count(2)->create();
        $private = $this->makePost($author, 'only_me');
        $public = $this->makePost($author);

        $this->actingAs($other, 'sanctum');
        $this->postJson("/api/v1/posts/{$private->id}/shares")->assertNotFound();
        $this->postJson("/api/v1/posts/{$public->id}/shares", ['target' => 'carrier-pigeon'])->assertStatus(422);
    }
}
