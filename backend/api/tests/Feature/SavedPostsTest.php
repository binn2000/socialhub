<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class SavedPostsTest extends TestCase
{
    use RefreshDatabase;

    private function makePost(User $author, string $content, string $privacy = 'public'): Post
    {
        return Post::forceCreate([
            'id' => (string) Str::ulid(), 'user_id' => $author->id, 'content' => $content,
            'privacy' => $privacy, 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function save(User $user, Post $post, $at): void
    {
        DB::table('post_saves')->insert(['post_id' => $post->id, 'user_id' => $user->id, 'created_at' => $at]);
    }

    public function test_lists_saved_posts_most_recently_saved_first(): void
    {
        [$me, $author] = User::factory()->count(2)->create();
        $a = $this->makePost($author, 'a');
        $b = $this->makePost($author, 'b');
        $c = $this->makePost($author, 'c');
        $this->makePost($author, 'never saved');
        $this->save($me, $a, now()->subMinutes(30));
        $this->save($me, $c, now()->subMinutes(20));
        $this->save($me, $b, now()->subMinutes(10));

        $data = $this->actingAs($me, 'sanctum')->getJson('/api/v1/me/saved-posts')->assertOk()->json('data');

        $this->assertSame(['b', 'c', 'a'], array_column($data, 'content'));
        $this->assertSame([true, true, true], array_column($data, 'isSaved'));
    }

    public function test_only_my_own_saves_are_listed(): void
    {
        [$me, $other, $author] = User::factory()->count(3)->create();
        $this->save($other, $this->makePost($author, 'theirs'), now());
        $this->save($me, $this->makePost($author, 'mine'), now());

        $data = $this->actingAs($me, 'sanctum')->getJson('/api/v1/me/saved-posts')->json('data');

        $this->assertSame(['mine'], array_column($data, 'content'));
    }

    public function test_posts_that_are_gone_or_no_longer_visible_are_skipped(): void
    {
        [$me, $author] = User::factory()->count(2)->create();
        Friendship::create(['requester_id' => $author->id, 'addressee_id' => $me->id, 'status' => 'accepted']);
        $deleted = $this->makePost($author, 'deleted');
        $madePrivate = $this->makePost($author, 'private now');
        $friendsOnly = $this->makePost($author, 'friends only', 'friends');
        $kept = $this->makePost($author, 'kept');
        foreach ([$deleted, $madePrivate, $friendsOnly, $kept] as $i => $post) {
            $this->save($me, $post, now()->subMinutes(10 - $i));
        }
        $deleted->delete();
        $madePrivate->update(['privacy' => 'only_me']);

        $names = fn () => array_column($this->actingAs($me, 'sanctum')->getJson('/api/v1/me/saved-posts')->json('data'), 'content');
        $this->assertSame(['kept', 'friends only'], $names());

        // after unfriending, the friends-only post is not visible either
        Friendship::query()->delete();
        $this->assertSame(['kept'], $names());
    }

    public function test_hidden_posts_are_still_listed(): void
    {
        [$me, $author] = User::factory()->count(2)->create();
        $post = $this->makePost($author, 'hidden but saved');
        $this->save($me, $post, now());
        DB::table('post_hidden')->insert(['post_id' => $post->id, 'user_id' => $me->id]);

        $this->actingAs($me, 'sanctum')->getJson('/api/v1/me/saved-posts')
            ->assertJsonPath('data.0.isHidden', true)->assertJsonPath('data.0.isSaved', true);
    }

    public function test_pagination_follows_the_saved_order(): void
    {
        [$me, $author] = User::factory()->count(2)->create();
        foreach (range(1, 5) as $i) {
            $this->save($me, $this->makePost($author, "p$i"), now()->subMinutes(10 - $i));
        }
        // two saved in the same second: the post id breaks the tie
        $x = $this->makePost($author, 'x');
        $y = $this->makePost($author, 'y');
        $same = now()->addMinute();
        $this->save($me, $x, $same);
        $this->save($me, $y, $same);
        $this->actingAs($me, 'sanctum');

        $seen = [];
        $cursor = null;
        do {
            $r = $this->getJson('/api/v1/me/saved-posts?limit=2'.($cursor ? "&cursor=$cursor" : ''))->assertOk();
            $seen = array_merge($seen, array_column($r->json('data'), 'content'));
            $cursor = $r->json('meta.nextCursor');
        } while ($cursor);

        $this->assertSame(['y', 'x', 'p5', 'p4', 'p3', 'p2', 'p1'], $seen);
        $this->getJson('/api/v1/me/saved-posts?cursor=bad')->assertStatus(400)->assertJsonPath('code', 'invalid_cursor');
        $this->getJson('/api/v1/me/saved-posts?limit=99')->assertStatus(422);
    }

    public function test_saving_through_the_api_shows_up_and_unsaving_removes(): void
    {
        [$me, $author] = User::factory()->count(2)->create();
        $post = $this->makePost($author, 'toggle');
        $this->actingAs($me, 'sanctum');

        $this->putJson("/api/v1/posts/{$post->id}/save")->assertOk();
        $this->assertCount(1, $this->getJson('/api/v1/me/saved-posts')->json('data'));

        $this->deleteJson("/api/v1/posts/{$post->id}/save")->assertOk();
        $this->assertCount(0, $this->getJson('/api/v1/me/saved-posts')->json('data'));
    }

    public function test_requires_authentication(): void
    {
        $this->getJson('/api/v1/me/saved-posts')->assertStatus(401);
    }
}
