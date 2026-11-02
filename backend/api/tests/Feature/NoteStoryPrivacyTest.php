<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\Story;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class NoteStoryPrivacyTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;

    private User $friend;

    private User $follower;

    private User $stranger;

    protected function setUp(): void
    {
        parent::setUp();
        [$this->owner, $this->friend, $this->follower, $this->stranger] = User::factory()->count(4)->create();
        Friendship::create(['requester_id' => $this->owner->id, 'addressee_id' => $this->friend->id, 'status' => 'accepted']);
        DB::table('follows')->insert(['follower_id' => $this->follower->id, 'followee_id' => $this->owner->id, 'created_at' => now()]);
    }

    private function noteTexts(User $viewer): array
    {
        return array_column($this->actingAs($viewer, 'sanctum')->getJson('/api/v1/notes')->assertOk()->json('data'), 'text');
    }

    private function profileNote(User $viewer): ?array
    {
        return $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/users/{$this->owner->id}")->assertOk()->json('data.note');
    }

    private function share(string $text, ?string $privacy = null): void
    {
        $this->actingAs($this->owner, 'sanctum')
            ->putJson('/api/v1/me/note', ['text' => $text] + ($privacy ? ['privacy' => $privacy] : []))->assertOk();
    }

    // ---- notes

    public function test_a_new_note_is_for_friends_by_default(): void
    {
        $this->share('chào');

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/notes')->assertJsonPath('data.0.privacy', 'friends');
        $this->assertSame(['chào'], $this->noteTexts($this->friend));
        $this->assertSame([], $this->noteTexts($this->follower)); // following is not friendship
        $this->assertSame([], $this->noteTexts($this->stranger));
        $this->assertNull($this->profileNote($this->stranger));
        $this->assertSame('chào', $this->profileNote($this->friend)['text']);
    }

    public function test_a_public_note_reaches_followers_and_every_profile_visitor(): void
    {
        $this->share('cho mọi người', 'public');

        $this->assertSame(['cho mọi người'], $this->noteTexts($this->friend));
        $this->assertSame(['cho mọi người'], $this->noteTexts($this->follower)); // in their Notes row
        $this->assertSame([], $this->noteTexts($this->stranger)); // not in a stranger's row...
        $this->assertSame('cho mọi người', $this->profileNote($this->stranger)['text']); // ...but on the profile
        $this->assertSame('public', $this->profileNote($this->stranger)['privacy']);
    }

    public function test_a_note_only_for_me_is_seen_by_nobody_else(): void
    {
        $this->share('bí mật', 'only_me');

        foreach ([$this->friend, $this->follower, $this->stranger] as $viewer) {
            $this->assertSame([], $this->noteTexts($viewer));
            $this->assertNull($this->profileNote($viewer));
        }
        $this->assertSame(['bí mật'], $this->noteTexts($this->owner));
        $this->assertSame('bí mật', $this->profileNote($this->owner)['text']);
    }

    public function test_replacing_a_note_keeps_its_privacy_unless_a_new_one_is_given(): void
    {
        $this->share('một', 'public');
        $this->share('hai'); // no privacy sent
        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/notes')->assertJsonPath('data.0.privacy', 'public');

        $this->share('ba', 'friends');
        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/notes')->assertJsonPath('data.0.privacy', 'friends');
        $this->assertSame([], $this->noteTexts($this->follower));
    }

    public function test_the_privacy_value_is_checked_and_expired_or_blocked_notes_are_hidden(): void
    {
        $this->actingAs($this->owner, 'sanctum')->putJson('/api/v1/me/note', ['text' => 'x', 'privacy' => 'everyone'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['privacy']]);

        $this->share('công khai', 'public');
        $this->actingAs($this->stranger, 'sanctum')->putJson("/api/v1/users/{$this->owner->id}/block")->assertNoContent();
        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/users/{$this->stranger->id}")->assertNotFound(); // blocked either way

        $this->travel(25)->hours();
        $this->assertNull($this->profileNote($this->friend));
        $this->assertSame([], $this->noteTexts($this->friend));
    }

    // ---- stories

    private function story(string $text, ?string $privacy = null): string
    {
        return $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/stories', ['text' => $text] + ($privacy ? ['privacy' => $privacy] : []))
            ->assertCreated()->json('data.id');
    }

    private function trayIds(User $viewer): array
    {
        return array_column($this->actingAs($viewer, 'sanctum')->getJson('/api/v1/stories')->assertOk()->json('data'), 'id');
    }

    private function storyIdsOf(User $viewer): array
    {
        return array_column($this->actingAs($viewer, 'sanctum')->getJson("/api/v1/users/{$this->owner->id}/stories")->assertOk()->json('data'), 'id');
    }

    public function test_a_new_story_is_for_friends_by_default(): void
    {
        $id = $this->story('hè');

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/stories')->assertJsonPath('data.0.privacy', 'friends');
        $this->assertSame([$id], $this->trayIds($this->friend));
        $this->assertSame([], $this->trayIds($this->follower));
        $this->assertSame([], $this->trayIds($this->stranger));
        $this->assertSame([$id], $this->storyIdsOf($this->friend));
        $this->assertSame([], $this->storyIdsOf($this->stranger));
        $this->actingAs($this->stranger, 'sanctum')->postJson("/api/v1/stories/$id/view")->assertNotFound();
    }

    public function test_a_public_story_opens_from_the_profile_and_reaches_followers_tray(): void
    {
        $id = $this->story('cho mọi người', 'public');

        $this->assertSame([$id], $this->trayIds($this->friend));
        $this->assertSame([$id], $this->trayIds($this->follower)); // follows the author
        $this->assertSame([], $this->trayIds($this->stranger)); // a stranger's tray stays clean
        $this->assertSame([$id], $this->storyIdsOf($this->stranger)); // but the profile opens it
        $this->actingAs($this->stranger, 'sanctum')->postJson("/api/v1/stories/$id/view")->assertNoContent();
        $this->assertSame(1, DB::table('story_views')->where('story_id', $id)->count());
    }

    public function test_a_story_only_for_me_is_seen_by_nobody_else(): void
    {
        $id = $this->story('riêng tư', 'only_me');

        foreach ([$this->friend, $this->follower, $this->stranger] as $viewer) {
            $this->assertSame([], $this->trayIds($viewer));
            $this->assertSame([], $this->storyIdsOf($viewer));
        }
        $this->assertSame([$id], $this->trayIds($this->owner));
    }

    public function test_the_author_can_change_the_privacy_of_a_story(): void
    {
        $id = $this->story('đổi', 'friends');

        $this->actingAs($this->owner, 'sanctum')->patchJson("/api/v1/stories/$id", ['privacy' => 'public'])
            ->assertOk()->assertJsonPath('data.privacy', 'public');
        $this->assertSame([$id], $this->storyIdsOf($this->stranger));

        $this->actingAs($this->owner, 'sanctum')->patchJson("/api/v1/stories/$id", ['privacy' => 'only_me'])->assertOk();
        $this->assertSame([], $this->storyIdsOf($this->friend));
    }

    public function test_only_the_author_can_change_it_and_the_value_is_checked(): void
    {
        $id = $this->story('của tôi', 'public');

        $this->actingAs($this->friend, 'sanctum')->patchJson("/api/v1/stories/$id", ['privacy' => 'only_me'])
            ->assertForbidden()->assertJsonPath('code', 'forbidden');
        $this->actingAs($this->owner, 'sanctum')->patchJson("/api/v1/stories/$id", ['privacy' => 'everyone'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['privacy']]);
        $this->patchJson("/api/v1/stories/$id", [])->assertStatus(422);
        $this->assertSame('public', Story::find($id)->privacy);

        $hidden = $this->story('ẩn', 'only_me');
        $this->actingAs($this->stranger, 'sanctum')->patchJson("/api/v1/stories/$hidden", ['privacy' => 'public'])->assertNotFound();
        $this->assertSame('only_me', Story::find($hidden)->privacy);
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/stories', ['text' => 'x', 'privacy' => 'everyone'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['privacy']]);
    }

    public function test_the_profile_says_whether_there_are_stories_to_see(): void
    {
        $this->story('thường');
        $has = fn (User $viewer) => $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/users/{$this->owner->id}")->json('data.hasStories');

        $this->assertTrue($has($this->owner));
        $this->assertTrue($has($this->friend));
        $this->assertFalse($has($this->stranger));

        $this->story('công khai', 'public');
        $this->assertTrue($has($this->stranger));

        $this->travel(25)->hours();
        $this->assertFalse($has($this->friend)); // expired
    }

    public function test_blocking_hides_stories_both_ways_and_the_profile_list_is_blocked_too(): void
    {
        $this->story('công khai', 'public');
        $this->actingAs($this->stranger, 'sanctum')->putJson("/api/v1/users/{$this->owner->id}/block")->assertNoContent();

        $this->actingAs($this->stranger, 'sanctum')->getJson("/api/v1/users/{$this->owner->id}/stories")->assertOk()->assertJsonCount(0, 'data');
        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/users/{$this->stranger->id}/stories")->assertNotFound();
        $this->getJson('/api/v1/users/nobody/stories')->assertNotFound();

        $this->app['auth']->forgetGuards();
        $this->getJson("/api/v1/users/{$this->owner->id}/stories")->assertUnauthorized();
    }
}
