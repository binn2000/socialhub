<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class MessageInteractionsTest extends TestCase
{
    use RefreshDatabase;

    private function friends(): array
    {
        [$a, $b] = User::factory()->count(2)->create();
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'accepted']);

        return [$a, $b];
    }

    /** @return array{0: string, 1: string} conversation id and the id of a message from $a */
    private function chat(User $a, User $b, string $text = 'Xin chào'): array
    {
        $conversation = $this->actingAs($a, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $b->id])->json('data.id');
        $message = $this->postJson("/api/v1/conversations/$conversation/messages", ['text' => $text])->assertCreated()->json('data.id');

        return [$conversation, $message];
    }

    public function test_reactions_are_saved_counted_and_changed(): void
    {
        [$a, $b] = $this->friends();
        [$c, $m] = $this->chat($a, $b);

        $this->actingAs($b, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/reaction", ['emoji' => '😂'])
            ->assertOk()->assertJsonPath('data.reactions', ['😂' => 1])->assertJsonPath('data.myReaction', '😂');
        $this->actingAs($a, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/reaction", ['emoji' => '😂'])
            ->assertJsonPath('data.reactions', ['😂' => 2]);

        // One reaction per person: choosing another replaces it.
        $this->actingAs($b, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/reaction", ['emoji' => '😡'])
            ->assertJsonPath('data.reactions', ['😂' => 1, '😡' => 1])->assertJsonPath('data.myReaction', '😡');

        // The other person sees the same counts and their own reaction.
        $seen = $this->actingAs($a, 'sanctum')->getJson("/api/v1/conversations/$c/messages")->json('data.0');
        $this->assertSame('😂', $seen['myReaction']);
        $this->assertSame(['😂' => 1, '😡' => 1], $seen['reactions']);

        $this->actingAs($b, 'sanctum')->deleteJson("/api/v1/conversations/$c/messages/$m/reaction")
            ->assertOk()->assertJsonPath('data.reactions', ['😂' => 1])->assertJsonPath('data.myReaction', null);
    }

    public function test_the_heart_is_accepted_with_or_without_its_variation_selector(): void
    {
        [$a, $b] = $this->friends();
        [$c, $m] = $this->chat($a, $b);

        $this->actingAs($b, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/reaction", ['emoji' => "\u{2764}"])
            ->assertOk()->assertJsonPath('data.myReaction', "\u{2764}\u{FE0F}");
    }

    public function test_only_the_six_reactions_and_only_participants(): void
    {
        [$a, $b] = $this->friends();
        $stranger = User::factory()->create();
        [$c, $m] = $this->chat($a, $b);

        $this->actingAs($b, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/reaction", ['emoji' => '🍕'])
            ->assertUnprocessable()->assertJsonValidationErrors('emoji');
        $this->actingAs($stranger, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/reaction", ['emoji' => '😂'])
            ->assertNotFound();
        $this->putJson("/api/v1/conversations/$c/messages/nope/reaction", ['emoji' => '😂'])->assertNotFound();
    }

    public function test_recalling_removes_the_text_and_files_for_both_people(): void
    {
        Storage::fake('public');
        [$a, $b] = $this->friends();
        $c = $this->actingAs($a, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $b->id])->json('data.id');
        $m = $this->post("/api/v1/conversations/$c/messages", ['text' => 'Gửi nhầm', 'attachments' => [UploadedFile::fake()->image('a.jpg', 40, 30)]], ['Accept' => 'application/json'])
            ->assertCreated()->json('data.id');
        $this->actingAs($b, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/reaction", ['emoji' => '👍']);
        $this->assertCount(1, Storage::disk('public')->allFiles());

        // Only the sender may take it back.
        $this->deleteJson("/api/v1/conversations/$c/messages/$m")->assertForbidden();

        $this->actingAs($a, 'sanctum')->deleteJson("/api/v1/conversations/$c/messages/$m")
            ->assertOk()->assertJsonPath('data.isRecalled', true)->assertJsonPath('data.text', '')
            ->assertJsonPath('data.attachments', [])->assertJsonPath('data.reactions', []);

        $seen = $this->actingAs($b, 'sanctum')->getJson("/api/v1/conversations/$c/messages")->json('data.0');
        $this->assertTrue($seen['isRecalled']);
        $this->assertSame('', $seen['text']);
        $this->assertSame([], Storage::disk('public')->allFiles());

        // The conversation list shows it as recalled too, and a recalled message takes no reactions.
        $this->assertTrue($this->getJson('/api/v1/conversations')->json('data.0.lastMessage.isRecalled'));
        $this->actingAs($b, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/reaction", ['emoji' => '👍'])
            ->assertStatus(409)->assertJsonPath('code', 'message_recalled');

        // Recalling again is harmless.
        $this->actingAs($a, 'sanctum')->deleteJson("/api/v1/conversations/$c/messages/$m")->assertOk();
    }

    public function test_deleting_for_me_hides_the_message_only_from_me(): void
    {
        [$a, $b] = $this->friends();
        [$c, $m] = $this->chat($a, $b);
        $this->actingAs($b, 'sanctum')->postJson("/api/v1/conversations/$c/messages", ['text' => 'Tin thứ hai']);

        $this->actingAs($a, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/hide")->assertNoContent();
        $this->putJson("/api/v1/conversations/$c/messages/$m/hide")->assertNoContent(); // harmless twice

        $mine = array_column($this->getJson("/api/v1/conversations/$c/messages")->json('data'), 'text');
        $this->assertSame(['Tin thứ hai'], $mine);
        $theirs = array_column($this->actingAs($b, 'sanctum')->getJson("/api/v1/conversations/$c/messages")->json('data'), 'text');
        $this->assertEqualsCanonicalizing(['Tin thứ hai', 'Xin chào'], $theirs);

        // A hidden message can no longer be reached by the person who hid it.
        $this->actingAs($a, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/reaction", ['emoji' => '😂'])->assertNotFound();
    }

    public function test_polling_reports_what_changed_on_older_messages(): void
    {
        [$a, $b] = $this->friends();
        [$c, $first] = $this->chat($a, $b, 'Tin đầu');
        $last = $this->postJson("/api/v1/conversations/$c/messages", ['text' => 'Tin cuối'])->json('data.id');

        $this->actingAs($b, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$first/reaction", ['emoji' => '😮']);
        $this->actingAs($a, 'sanctum')->deleteJson("/api/v1/conversations/$c/messages/$last");

        $poll = $this->actingAs($b, 'sanctum')->getJson("/api/v1/conversations/$c/messages?after=$last")->assertOk();
        $states = $poll->json('meta.states');
        $this->assertSame(['😮' => 1], $states[$first]['reactions']);
        $this->assertSame('😮', $states[$first]['myReaction']);
        $this->assertTrue($states[$last]['isRecalled']);
    }
}
