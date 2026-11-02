<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\Note;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class NotesTest extends TestCase
{
    use RefreshDatabase;

    private function befriend(User $a, User $b): void
    {
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'accepted']);
    }

    private function texts(): array
    {
        return array_column($this->getJson('/api/v1/notes')->assertOk()->json('data'), 'text');
    }

    public function test_a_note_is_set_and_comes_back_with_its_expiry(): void
    {
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum');

        $response = $this->putJson('/api/v1/me/note', ['text' => '  Đang học   bài 📚 '])->assertOk();

        $response->assertJsonPath('data.text', 'Đang học bài 📚')->assertJsonPath('data.user.id', $me->id);
        $this->assertSame(now()->addHours(24)->toIso8601ZuluString(), $response->json('data.expiresAt'));
        $this->assertSame(['Đang học bài 📚'], $this->texts());
    }

    public function test_setting_a_note_again_replaces_it_and_restarts_the_24_hours(): void
    {
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum');
        $this->putJson('/api/v1/me/note', ['text' => 'một'])->assertOk();

        $this->travel(20)->hours();
        $this->putJson('/api/v1/me/note', ['text' => 'hai'])->assertOk();
        $this->travel(10)->hours(); // 30 hours after the first, 10 after the second

        $this->assertSame(['hai'], $this->texts());
        $this->assertSame(1, Note::count());
    }

    public function test_a_note_disappears_after_24_hours_and_the_purge_removes_it(): void
    {
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum')->putJson('/api/v1/me/note', ['text' => 'chào'])->assertOk();

        $this->travel(25)->hours();
        $this->assertSame([], $this->texts());
        $this->assertSame(1, Note::count()); // hidden, not yet deleted

        $this->artisan('notes:purge-expired')->assertSuccessful();
        $this->assertSame(0, Note::count());
    }

    public function test_the_text_rules(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->putJson('/api/v1/me/note', [])->assertStatus(422)->assertJsonStructure(['errors' => ['text']]);
        $this->putJson('/api/v1/me/note', ['text' => "   \n  "])->assertStatus(422)->assertJsonStructure(['errors' => ['text']]);
        $this->putJson('/api/v1/me/note', ['text' => str_repeat('a', 61)])->assertStatus(422)->assertJsonStructure(['errors' => ['text']]);
        $this->putJson('/api/v1/me/note', ['text' => str_repeat('a', 60)])->assertOk();
        // 60 emoji are 60 characters even though they are far more bytes
        $this->putJson('/api/v1/me/note', ['text' => str_repeat('😀', 60)])->assertOk();
        $this->putJson('/api/v1/me/note', ['text' => str_repeat('😀', 61)])->assertStatus(422);
        $this->putJson('/api/v1/me/note', ['text' => ['not', 'a string']])->assertStatus(422);
    }

    public function test_friends_see_it_strangers_and_blocked_people_do_not(): void
    {
        [$me, $friend, $stranger, $blocked] = User::factory()->count(4)->create();
        $this->befriend($me, $friend);
        $this->actingAs($friend, 'sanctum')->putJson('/api/v1/me/note', ['text' => 'của bạn'])->assertOk();
        $this->actingAs($stranger, 'sanctum')->putJson('/api/v1/me/note', ['text' => 'người lạ'])->assertOk();
        $this->actingAs($blocked, 'sanctum')->putJson('/api/v1/me/note', ['text' => 'bị chặn'])->assertOk();
        $this->befriend($me, $blocked);
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/users/{$blocked->id}/block")->assertNoContent();

        $this->assertSame(['của bạn'], $this->texts());
        // the stranger sees only their own
        $this->actingAs($stranger, 'sanctum');
        $this->assertSame(['người lạ'], $this->texts());
    }

    public function test_my_note_comes_first_then_friends_newest_first(): void
    {
        [$me, $a, $b] = User::factory()->count(3)->create();
        $this->befriend($me, $a);
        $this->befriend($me, $b);
        $this->actingAs($a, 'sanctum')->putJson('/api/v1/me/note', ['text' => 'của A']);
        $this->travel(5)->minutes();
        $this->actingAs($b, 'sanctum')->putJson('/api/v1/me/note', ['text' => 'của B']);
        $this->travel(5)->minutes();
        $this->actingAs($me, 'sanctum')->putJson('/api/v1/me/note', ['text' => 'của tôi']);
        $this->travel(-5)->minutes();

        $this->assertSame(['của tôi', 'của B', 'của A'], $this->texts());
    }

    public function test_deleting_is_idempotent_and_unfriending_hides_the_note(): void
    {
        [$me, $friend] = User::factory()->count(2)->create();
        $this->befriend($me, $friend);
        $this->actingAs($friend, 'sanctum')->putJson('/api/v1/me/note', ['text' => 'chào'])->assertOk();

        $this->actingAs($me, 'sanctum')->deleteJson("/api/v1/friends/{$friend->id}")->assertNoContent();
        $this->assertSame([], $this->texts());

        $this->actingAs($friend, 'sanctum')->deleteJson('/api/v1/me/note')->assertNoContent();
        $this->deleteJson('/api/v1/me/note')->assertNoContent();
        $this->assertSame([], $this->texts());
    }

    public function test_deleted_accounts_have_no_notes_and_limits_apply(): void
    {
        [$me, $friend] = User::factory()->count(2)->create();
        $this->befriend($me, $friend);
        $this->actingAs($friend, 'sanctum')->putJson('/api/v1/me/note', ['text' => 'đi rồi']);
        $friend->delete();
        $this->actingAs($me, 'sanctum');
        $this->assertSame([], $this->texts());

        foreach (range(1, 30) as $i) {
            $this->putJson('/api/v1/me/note', ['text' => "n$i"])->assertOk();
        }
        $this->putJson('/api/v1/me/note', ['text' => 'quá nhiều'])->assertStatus(429);
    }

    public function test_authentication_is_required(): void
    {
        $this->getJson('/api/v1/notes')->assertUnauthorized();
        $this->putJson('/api/v1/me/note', ['text' => 'x'])->assertUnauthorized();
        $this->deleteJson('/api/v1/me/note')->assertUnauthorized();
        $this->assertSame(0, DB::table('notes')->count());
    }
}
