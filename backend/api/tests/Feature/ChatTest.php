<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ChatTest extends TestCase
{
    use RefreshDatabase;

    private function friends(): array
    {
        [$a, $b] = User::factory()->count(2)->create();
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'accepted']);

        return [$a, $b];
    }

    private function open(User $from, User $to): string
    {
        return $this->actingAs($from, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $to->id])->json('data.id');
    }

    private function say(User $from, string $conversation, string $text): array
    {
        return $this->actingAs($from, 'sanctum')->postJson("/api/v1/conversations/$conversation/messages", ['text' => $text])
            ->assertCreated()->json('data');
    }

    public function test_start_conversation_is_unique_per_pair(): void
    {
        [$a, $b] = $this->friends();

        $first = $this->actingAs($a, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $b->id])
            ->assertCreated()
            ->assertJsonPath('data.participant.id', $b->id)
            ->assertJsonPath('data.lastMessage', null)
            ->assertJsonPath('data.unreadCount', 0);
        $this->actingAs($b, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $a->id])
            ->assertOk()->assertJsonPath('data.id', $first->json('data.id'))->assertJsonPath('data.participant.id', $a->id);
        $this->assertSame(1, DB::table('conversations')->count());
    }

    public function test_start_conversation_rules(): void
    {
        [$a, $b] = $this->friends();
        $stranger = User::factory()->create();
        $this->actingAs($a, 'sanctum');

        $this->postJson('/api/v1/conversations', ['userId' => $stranger->id])->assertForbidden()->assertJsonPath('code', 'not_friends');
        $this->postJson('/api/v1/conversations', ['userId' => $a->id])->assertStatus(422);
        $this->postJson('/api/v1/conversations', ['userId' => 'missing'])->assertNotFound();
        $this->postJson('/api/v1/conversations', [])->assertStatus(422);
    }

    public function test_send_list_and_unread_counts(): void
    {
        [$a, $b] = $this->friends();
        $c = $this->open($a, $b);

        // an empty conversation is not listed
        $this->actingAs($a, 'sanctum')->getJson('/api/v1/conversations')->assertJsonCount(0, 'data');

        $this->say($a, $c, '  Chào bạn!  ');
        $last = $this->say($a, $c, 'Bạn khoẻ không?');
        $this->assertSame('Bạn khoẻ không?', $last['text']);

        $mine = $this->actingAs($a, 'sanctum')->getJson('/api/v1/conversations')->assertOk()->json('data.0');
        $this->assertSame(0, $mine['unreadCount']);
        $this->assertSame($last['id'], $mine['lastMessage']['id']);

        $theirs = $this->actingAs($b, 'sanctum')->getJson('/api/v1/conversations')->json('data.0');
        $this->assertSame(2, $theirs['unreadCount']);
        $this->assertSame($a->id, $theirs['participant']['id']);

        $this->postJson("/api/v1/conversations/$c/read")->assertNoContent();
        $this->postJson("/api/v1/conversations/$c/read")->assertNoContent();
        $this->assertSame(0, $this->getJson('/api/v1/conversations')->json('data.0.unreadCount'));
        $this->assertSame(0, DB::table('notifications')->count());
    }

    public function test_message_validation_and_trimming(): void
    {
        [$a, $b] = $this->friends();
        $c = $this->open($a, $b);

        $this->postJson("/api/v1/conversations/$c/messages", ['text' => '   '])->assertStatus(422)->assertJsonStructure(['errors' => ['text']]);
        $this->postJson("/api/v1/conversations/$c/messages", ['text' => str_repeat('a', 2001)])->assertStatus(422);
        $this->assertSame('hi', $this->say($a, $c, '  hi ')['text']);
    }

    public function test_only_participants_can_read_or_write(): void
    {
        [$a, $b] = $this->friends();
        $outsider = User::factory()->create();
        $c = $this->open($a, $b);
        $this->say($a, $c, 'secret');

        $this->actingAs($outsider, 'sanctum');
        $this->getJson("/api/v1/conversations/$c/messages")->assertNotFound();
        $this->postJson("/api/v1/conversations/$c/messages", ['text' => 'x'])->assertNotFound();
        $this->postJson("/api/v1/conversations/$c/read")->assertNotFound();
        $this->getJson('/api/v1/conversations')->assertJsonCount(0, 'data');
    }

    public function test_cannot_send_after_unfriending(): void
    {
        [$a, $b] = $this->friends();
        $c = $this->open($a, $b);
        $this->say($a, $c, 'hello');
        $this->actingAs($a, 'sanctum')->deleteJson("/api/v1/friends/{$b->id}");

        $this->postJson("/api/v1/conversations/$c/messages", ['text' => 'again'])->assertForbidden()->assertJsonPath('code', 'not_friends');
        $this->getJson("/api/v1/conversations/$c/messages")->assertOk()->assertJsonCount(1, 'data'); // history stays readable
    }

    public function test_history_pagination_newest_first(): void
    {
        [$a, $b] = $this->friends();
        $c = $this->open($a, $b);
        foreach (['m1', 'm2', 'm3'] as $t) {
            $this->say($a, $c, $t);
        }
        $this->actingAs($b, 'sanctum');

        $p1 = $this->getJson("/api/v1/conversations/$c/messages?limit=2")->assertOk();
        $this->assertSame(['m3', 'm2'], array_column($p1->json('data'), 'text'));
        $p2 = $this->getJson("/api/v1/conversations/$c/messages?limit=2&cursor=".$p1->json('meta.nextCursor'));
        $this->assertSame(['m1'], array_column($p2->json('data'), 'text'));
        $this->assertFalse($p2->json('meta.hasMore'));
        $this->getJson("/api/v1/conversations/$c/messages?cursor=bad")->assertStatus(400);
    }

    public function test_polling_with_after(): void
    {
        [$a, $b] = $this->friends();
        $c = $this->open($a, $b);
        $m1 = $this->say($a, $c, 'm1');
        $this->say($b, $c, 'm2');
        $this->say($a, $c, 'm3');
        $this->actingAs($a, 'sanctum');

        $r = $this->getJson("/api/v1/conversations/$c/messages?after={$m1['id']}")->assertOk();
        $this->assertSame(['m2', 'm3'], array_column($r->json('data'), 'text'));
        $this->assertNull($r->json('meta.nextCursor'));
        $this->assertFalse($r->json('meta.hasMore'));

        $r = $this->getJson("/api/v1/conversations/$c/messages?after={$m1['id']}&limit=1");
        $this->assertSame(['m2'], array_column($r->json('data'), 'text'));
        $this->assertTrue($r->json('meta.hasMore'));

        $this->getJson("/api/v1/conversations/$c/messages?after=unknown")->assertNotFound();
        $this->getJson("/api/v1/conversations/$c/messages?after={$m1['id']}&cursor=x")->assertStatus(422);
    }

    public function test_read_marker_never_moves_backwards_and_checks_message(): void
    {
        [$a, $b] = $this->friends();
        $c = $this->open($a, $b);
        $m1 = $this->say($a, $c, 'm1');
        $this->say($a, $c, 'm2');
        $m3 = $this->say($a, $c, 'm3');
        $this->actingAs($b, 'sanctum');

        $this->postJson("/api/v1/conversations/$c/read", ['upToMessageId' => $m3['id']])->assertNoContent();
        $this->postJson("/api/v1/conversations/$c/read", ['upToMessageId' => $m1['id']])->assertNoContent();
        $this->assertSame(0, $this->getJson('/api/v1/conversations')->json('data.0.unreadCount'));
        $this->postJson("/api/v1/conversations/$c/read", ['upToMessageId' => 'nope'])->assertStatus(422);
    }

    public function test_conversations_ordered_by_latest_activity(): void
    {
        [$a, $b] = $this->friends();
        $c3 = User::factory()->create();
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $c3->id, 'status' => 'accepted']);
        $first = $this->open($a, $b);
        $second = $this->open($a, $c3);
        $this->say($a, $first, 'one');
        $this->say($a, $second, 'two');
        $this->say($b, $first, 'three');

        $ids = array_column($this->actingAs($a, 'sanctum')->getJson('/api/v1/conversations')->json('data'), 'id');
        $this->assertSame([$first, $second], $ids);

        $p1 = $this->getJson('/api/v1/conversations?limit=1');
        $this->assertTrue($p1->json('meta.hasMore'));
        $this->assertSame([$second], array_column($this->getJson('/api/v1/conversations?limit=1&cursor='.$p1->json('meta.nextCursor'))->json('data'), 'id'));
    }

    public function test_requires_authentication(): void
    {
        $this->getJson('/api/v1/conversations')->assertStatus(401);
    }
}
