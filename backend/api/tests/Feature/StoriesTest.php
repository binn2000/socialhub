<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\Story;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class StoriesTest extends TestCase
{
    use RefreshDatabase;

    private function story(User $u, string $text = 's', array $extra = []): Story
    {
        return Story::forceCreate($extra + [
            'id' => (string) Str::ulid(), 'user_id' => $u->id, 'text' => $text, 'background' => 'indigo',
            'expires_at' => now()->addHours(5), 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    private function befriend(User $a, User $b): void
    {
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'accepted']);
    }

    public function test_create_story(): void
    {
        $me = User::factory()->create();
        $r = $this->actingAs($me, 'sanctum')->postJson('/api/v1/stories', ['text' => '  Tin của tôi ', 'background' => 'sunset'])
            ->assertCreated()
            ->assertJsonPath('data.text', 'Tin của tôi')
            ->assertJsonPath('data.background', 'sunset')
            ->assertJsonPath('data.isViewed', false)
            ->assertJsonPath('data.imageUrl', null)
            ->assertJsonPath('data.author.id', $me->id);

        $created = strtotime($r->json('data.createdAt'));
        $this->assertEqualsWithDelta(86400, strtotime($r->json('data.expiresAt')) - $created, 2);
        $this->postJson('/api/v1/stories', ['text' => 'x'])->assertJsonPath('data.background', 'indigo');
    }

    public function test_create_validation(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->postJson('/api/v1/stories', ['text' => '   '])->assertStatus(422)->assertJsonStructure(['errors' => ['text']]);
        $this->postJson('/api/v1/stories', ['text' => str_repeat('a', 501)])->assertStatus(422);
        $this->postJson('/api/v1/stories', ['text' => 'x', 'background' => 'neon'])->assertStatus(422);
    }

    public function test_list_shows_own_then_friends_and_hides_expired_and_strangers(): void
    {
        [$me, $friend, $stranger] = User::factory()->count(3)->create();
        $this->befriend($friend, $me);
        $this->story($friend, 'friend-new', ['created_at' => now()->subMinutes(1)]);
        $this->story($me, 'mine-old', ['created_at' => now()->subHours(3)]);
        $this->story($me, 'mine-new', ['created_at' => now()->subHours(2)]);
        $this->story($friend, 'friend-old', ['created_at' => now()->subMinutes(30)]);
        $this->story($friend, 'expired', ['expires_at' => now()->subMinute()]);
        $this->story($stranger, 'stranger');

        $data = $this->actingAs($me, 'sanctum')->getJson('/api/v1/stories')->assertOk()->json('data');
        $this->assertSame(['mine-new', 'mine-old', 'friend-new', 'friend-old'], array_column($data, 'text'));
    }

    public function test_list_pagination_crosses_the_own_and_other_buckets(): void
    {
        [$me, $friend] = User::factory()->count(2)->create();
        $this->befriend($friend, $me);
        $this->story($me, 'm1', ['created_at' => now()->subHours(3)]);
        $this->story($me, 'm2', ['created_at' => now()->subHours(2)]);
        $this->story($friend, 'f1', ['created_at' => now()->subMinutes(20)]);
        $this->story($friend, 'f2', ['created_at' => now()->subMinutes(10)]);
        $this->actingAs($me, 'sanctum');

        $seen = [];
        $cursor = null;
        do {
            $r = $this->getJson('/api/v1/stories?limit=1'.($cursor ? "&cursor=$cursor" : ''))->assertOk();
            $seen = array_merge($seen, array_column($r->json('data'), 'text'));
            $cursor = $r->json('meta.nextCursor');
        } while ($cursor);

        $this->assertSame(['m2', 'm1', 'f2', 'f1'], $seen);
        $this->getJson('/api/v1/stories?cursor=bad')->assertStatus(400);
    }

    public function test_view_marks_viewed_only_for_the_caller(): void
    {
        [$me, $friend, $other] = User::factory()->count(3)->create();
        $this->befriend($friend, $me);
        $this->befriend($friend, $other);
        $s = $this->story($friend);
        $own = $this->story($me, 'own');

        $this->actingAs($me, 'sanctum');
        $this->postJson("/api/v1/stories/{$s->id}/view")->assertNoContent();
        $this->postJson("/api/v1/stories/{$s->id}/view")->assertNoContent();
        $this->postJson("/api/v1/stories/{$own->id}/view")->assertNoContent();
        $this->assertSame(1, DB::table('story_views')->count());

        $viewed = array_column($this->getJson('/api/v1/stories')->json('data'), 'isViewed', 'id');
        $this->assertTrue($viewed[$s->id]);
        $this->assertFalse($viewed[$own->id]);
        $this->assertFalse(array_column($this->actingAs($other, 'sanctum')->getJson('/api/v1/stories')->json('data'), 'isViewed', 'id')[$s->id]);
    }

    public function test_invisible_stories_are_404(): void
    {
        [$me, $stranger] = User::factory()->count(2)->create();
        $s = $this->story($stranger);
        $expired = $this->story($me, 'old', ['expires_at' => now()->subMinute()]);
        $this->actingAs($me, 'sanctum');

        $this->postJson("/api/v1/stories/{$s->id}/view")->assertNotFound();
        $this->deleteJson("/api/v1/stories/{$s->id}")->assertNotFound();
        $this->deleteJson("/api/v1/stories/{$expired->id}")->assertNotFound();
        $this->assertSame(0, DB::table('story_views')->count());
    }

    public function test_delete_is_author_only(): void
    {
        [$me, $friend] = User::factory()->count(2)->create();
        $this->befriend($friend, $me);
        $theirs = $this->story($friend);
        $mine = $this->story($me);
        DB::table('story_views')->insert(['story_id' => $mine->id, 'user_id' => $friend->id, 'viewed_at' => now()]);
        $this->actingAs($me, 'sanctum');

        $this->deleteJson("/api/v1/stories/{$theirs->id}")->assertForbidden()->assertJsonPath('code', 'forbidden');
        $this->deleteJson("/api/v1/stories/{$mine->id}")->assertNoContent();
        $this->deleteJson("/api/v1/stories/{$mine->id}")->assertNotFound();
        $this->assertSame(0, DB::table('story_views')->count()); // cascade
    }

    public function test_purge_command_removes_only_expired(): void
    {
        $me = User::factory()->create();
        $this->story($me, 'live');
        $this->story($me, 'dead', ['expires_at' => now()->subMinute()]);

        $this->artisan('stories:purge-expired')->assertSuccessful();
        $this->assertSame(['live'], Story::pluck('text')->all());
    }

    public function test_requires_authentication(): void
    {
        $this->getJson('/api/v1/stories')->assertStatus(401);
    }
}
