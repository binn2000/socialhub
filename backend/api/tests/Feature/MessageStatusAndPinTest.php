<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MessageStatusAndPinTest extends TestCase
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
        $c = $this->actingAs($a, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $b->id])->json('data.id');
        $m = $this->postJson("/api/v1/conversations/$c/messages", ['text' => $text])->assertCreated()->json('data.id');

        return [$c, $m];
    }

    public function test_a_message_is_delivered_when_the_other_app_fetches_it_and_seen_when_read(): void
    {
        [$a, $b] = $this->friends();
        [$c, $m] = $this->chat($a, $b);

        // Nothing fetched yet: sent only.
        $meta = $this->getJson("/api/v1/conversations/$c/messages")->json('meta');
        $this->assertNull($meta['partnerLastDeliveredMessageId']);
        $this->assertNull($meta['partnerLastReadMessageId']);

        // The other person's app loads the conversation list: delivered, not yet seen.
        $this->actingAs($b, 'sanctum')->getJson('/api/v1/conversations')->assertOk();
        $meta = $this->actingAs($a, 'sanctum')->getJson("/api/v1/conversations/$c/messages?after=$m")->json('meta');
        $this->assertSame($m, $meta['partnerLastDeliveredMessageId']);
        $this->assertNull($meta['partnerLastReadMessageId']);

        // They open the chat and read it.
        $this->actingAs($b, 'sanctum')->postJson("/api/v1/conversations/$c/read")->assertNoContent();
        $meta = $this->actingAs($a, 'sanctum')->getJson("/api/v1/conversations/$c/messages?after=$m")->json('meta');
        $this->assertSame($m, $meta['partnerLastReadMessageId']);

        // The conversation list says the same.
        $row = $this->getJson('/api/v1/conversations')->json('data.0');
        $this->assertSame($m, $row['partnerLastReadMessageId']);
        $this->assertSame($m, $row['partnerLastDeliveredMessageId']);
    }

    public function test_reading_counts_as_delivered(): void
    {
        [$a, $b] = $this->friends();
        [$c, $m] = $this->chat($a, $b);

        $this->actingAs($b, 'sanctum')->postJson("/api/v1/conversations/$c/read")->assertNoContent();

        $row = $this->actingAs($a, 'sanctum')->getJson('/api/v1/conversations')->json('data.0');
        $this->assertSame($m, $row['partnerLastDeliveredMessageId']);
    }

    public function test_a_pinned_message_is_shared_by_both_people(): void
    {
        [$a, $b] = $this->friends();
        [$c, $m] = $this->chat($a, $b, 'Hẹn 7h tối nay');

        $this->actingAs($b, 'sanctum')->putJson("/api/v1/conversations/$c/pin", ['messageId' => $m])
            ->assertOk()->assertJsonPath('data.pinnedMessage.text', 'Hẹn 7h tối nay');

        foreach ([$a, $b] as $person) {
            $this->actingAs($person, 'sanctum');
            $this->assertSame($m, $this->getJson("/api/v1/conversations/$c/messages")->json('meta.pinnedMessage.id'));
            $this->assertSame($m, $this->getJson('/api/v1/conversations')->json('data.0.pinnedMessage.id'));
        }

        // Either person can take the pin away.
        $this->actingAs($a, 'sanctum')->deleteJson("/api/v1/conversations/$c/pin")->assertOk()->assertJsonPath('data.pinnedMessage', null);
        $this->assertNull($this->actingAs($b, 'sanctum')->getJson("/api/v1/conversations/$c/messages")->json('meta.pinnedMessage'));
    }

    public function test_a_new_pin_replaces_the_old_one_and_a_recalled_message_unpins_itself(): void
    {
        [$a, $b] = $this->friends();
        [$c, $first] = $this->chat($a, $b, 'Tin một');
        $second = $this->postJson("/api/v1/conversations/$c/messages", ['text' => 'Tin hai'])->json('data.id');

        $this->putJson("/api/v1/conversations/$c/pin", ['messageId' => $first]);
        $this->putJson("/api/v1/conversations/$c/pin", ['messageId' => $second])->assertJsonPath('data.pinnedMessage.id', $second);

        $this->deleteJson("/api/v1/conversations/$c/messages/$second")->assertOk();
        $this->assertNull($this->actingAs($b, 'sanctum')->getJson("/api/v1/conversations/$c/messages")->json('meta.pinnedMessage'));
    }

    public function test_pinning_follows_the_rules_of_messages(): void
    {
        [$a, $b] = $this->friends();
        $stranger = User::factory()->create();
        [$c, $m] = $this->chat($a, $b);

        $this->actingAs($stranger, 'sanctum')->putJson("/api/v1/conversations/$c/pin", ['messageId' => $m])->assertNotFound();
        $this->actingAs($a, 'sanctum')->putJson("/api/v1/conversations/$c/pin", ['messageId' => 'nope'])->assertNotFound();
        $this->putJson("/api/v1/conversations/$c/pin", [])->assertUnprocessable();

        // A message the caller deleted for themselves cannot be pinned, and a pin they deleted is not shown to them.
        $this->putJson("/api/v1/conversations/$c/pin", ['messageId' => $m])->assertOk();
        $this->actingAs($b, 'sanctum')->putJson("/api/v1/conversations/$c/messages/$m/hide")->assertNoContent();
        $this->assertNull($this->getJson("/api/v1/conversations/$c/messages")->json('meta.pinnedMessage'));
        $this->assertSame($m, $this->actingAs($a, 'sanctum')->getJson("/api/v1/conversations/$c/messages")->json('meta.pinnedMessage.id'));
    }
}
