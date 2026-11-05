<?php

namespace Tests\Feature;

use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PostReactionsTest extends TestCase
{
    use RefreshDatabase;

    private function makePost(User $author): Post
    {
        return Post::create(['user_id' => $author->id, 'content' => 'Bài viết', 'privacy' => 'public']);
    }

    public function test_a_reaction_is_saved_and_changed_without_counting_twice(): void
    {
        $post = $this->makePost(User::factory()->create());
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson("/api/v1/posts/{$post->id}/like", ['reaction' => 'love'])
            ->assertOk()->assertJsonPath('data.likes', 1)->assertJsonPath('data.reaction', 'love')
            ->assertJsonPath('data.reactionCounts.love', 1);

        $this->putJson("/api/v1/posts/{$post->id}/like", ['reaction' => 'haha'])
            ->assertOk()->assertJsonPath('data.likes', 1)->assertJsonPath('data.reaction', 'haha')
            ->assertJsonPath('data.reactionCounts', ['haha' => 1]);

        // Liking again without a reaction keeps the one that is there.
        $this->putJson("/api/v1/posts/{$post->id}/like")->assertJsonPath('data.reaction', 'haha');
    }

    public function test_a_plain_like_is_a_like_reaction(): void
    {
        $post = $this->makePost(User::factory()->create());
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson("/api/v1/posts/{$post->id}/like")->assertJsonPath('data.reaction', 'like');
    }

    public function test_an_unknown_reaction_is_refused(): void
    {
        $post = $this->makePost(User::factory()->create());
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson("/api/v1/posts/{$post->id}/like", ['reaction' => 'meh'])
            ->assertUnprocessable()->assertJsonValidationErrors('reaction');
    }

    public function test_the_post_shows_my_reaction_and_everyone_s_counts(): void
    {
        $post = $this->makePost(User::factory()->create());
        [$a, $b, $me] = User::factory()->count(3)->create();

        $this->actingAs($a, 'sanctum')->putJson("/api/v1/posts/{$post->id}/like", ['reaction' => 'love']);
        $this->actingAs($b, 'sanctum')->putJson("/api/v1/posts/{$post->id}/like", ['reaction' => 'love']);
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/posts/{$post->id}/like", ['reaction' => 'sad']);

        $row = $this->getJson('/api/v1/explore')->assertOk()->json('data.0');
        $this->assertSame('sad', $row['myReaction']);
        $this->assertSame(['love' => 2, 'sad' => 1], $row['reactionCounts']);
        $this->assertSame(3, $row['likes']);

        $this->actingAs(User::factory()->create(), 'sanctum');
        $other = $this->getJson("/api/v1/posts/{$post->id}")->assertOk()->json('data');
        $this->assertNull($other['myReaction']);
    }

    public function test_unliking_clears_the_reaction(): void
    {
        $post = $this->makePost(User::factory()->create());
        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->putJson("/api/v1/posts/{$post->id}/like", ['reaction' => 'wow']);

        $this->deleteJson("/api/v1/posts/{$post->id}/like")
            ->assertJsonPath('data.reaction', null)->assertJsonPath('data.likes', 0);
        $this->getJson("/api/v1/posts/{$post->id}")->assertJsonPath('data.myReaction', null)
            ->assertJsonPath('data.reactionCounts', []);
    }

    public function test_a_post_with_no_reactions_has_an_empty_object(): void
    {
        $post = $this->makePost(User::factory()->create());
        $this->actingAs(User::factory()->create(), 'sanctum');

        $body = $this->getJson("/api/v1/posts/{$post->id}")->getContent();
        $this->assertStringContainsString('"reactionCounts":{}', $body);
    }
}
