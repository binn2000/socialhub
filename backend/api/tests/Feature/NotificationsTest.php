<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class NotificationsTest extends TestCase
{
    use RefreshDatabase;

    private function postBy(User $u, string $content = 'hello'): string
    {
        return $this->actingAs($u, 'sanctum')->postJson('/api/v1/posts', ['content' => $content])->json('data.id');
    }

    public function test_activity_produces_notifications_with_related_content(): void
    {
        [$author, $fan] = User::factory()->count(2)->create();
        $postId = $this->postBy($author, 'Ngày đẹp trời');

        $this->actingAs($fan, 'sanctum');
        $this->putJson("/api/v1/posts/$postId/like");
        $this->postJson("/api/v1/posts/$postId/comments", ['content' => 'Hay quá!']);
        $this->postJson("/api/v1/posts/$postId/shares");
        $this->postJson('/api/v1/friend-requests', ['userId' => $author->id]);

        $items = $this->actingAs($author, 'sanctum')->getJson('/api/v1/notifications')->assertOk()->json('data');
        $this->assertCount(4, $items);
        $by = array_column($items, null, 'type');

        $this->assertSame('Ngày đẹp trời', $by['like']['relatedContent']);
        $this->assertSame('Ngày đẹp trời', $by['share']['relatedContent']);
        $this->assertSame('Hay quá!', $by['comment']['relatedContent']);
        $this->assertNotNull($by['comment']['commentId']);
        $this->assertSame($postId, $by['comment']['postId']);
        $this->assertSame($fan->id, $by['like']['actor']['id']);
        $this->assertFalse($by['like']['isRead']);
        $this->assertNull($by['friend_request']['relatedContent']);
        $this->assertNotNull($by['friend_request']['friendRequestId']);
        $this->assertNull($by['friend_request']['postId']);
    }

    public function test_friend_request_id_clears_once_accepted(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $reqId = $this->actingAs($a, 'sanctum')->postJson('/api/v1/friend-requests', ['userId' => $b->id])->json('data.id');
        $this->actingAs($b, 'sanctum')->postJson("/api/v1/friend-requests/$reqId/accept");

        $this->assertNull($this->getJson('/api/v1/notifications')->json('data.0.friendRequestId'));
        $accepted = $this->actingAs($a, 'sanctum')->getJson('/api/v1/notifications')->json('data.0');
        $this->assertSame('friend_accepted', $accepted['type']);
        $this->assertSame($b->id, $accepted['actor']['id']);
    }

    public function test_only_own_notifications_newest_first_with_pagination(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        foreach (range(1, 3) as $i) {
            DB::table('notifications')->insert([
                'id' => '01j'.str_repeat((string) $i, 23), 'user_id' => $me->id, 'actor_id' => $other->id,
                'type' => 'friend_request', 'created_at' => now()->subMinutes(10 - $i),
            ]);
        }
        DB::table('notifications')->insert(['id' => 'zzz'.str_repeat('0', 23), 'user_id' => $other->id, 'actor_id' => $me->id, 'type' => 'like', 'created_at' => now()]);
        $this->actingAs($me, 'sanctum');

        $p1 = $this->getJson('/api/v1/notifications?limit=2')->assertOk();
        $this->assertSame(['01j'.str_repeat('3', 23), '01j'.str_repeat('2', 23)], array_column($p1->json('data'), 'id'));
        $p2 = $this->getJson('/api/v1/notifications?limit=2&cursor='.$p1->json('meta.nextCursor'));
        $this->assertCount(1, $p2->json('data'));
        $this->assertFalse($p2->json('meta.hasMore'));
        $this->getJson('/api/v1/notifications?cursor=bad')->assertStatus(400);
    }

    public function test_unread_count_and_mark_read(): void
    {
        [$author, $fan] = User::factory()->count(2)->create();
        $postId = $this->postBy($author);
        $this->actingAs($fan, 'sanctum')->putJson("/api/v1/posts/$postId/like");
        $this->postJson("/api/v1/posts/$postId/comments", ['content' => 'a']);
        $this->postJson("/api/v1/posts/$postId/comments", ['content' => 'b']);

        $this->actingAs($author, 'sanctum');
        $this->getJson('/api/v1/notifications/unread-count')->assertExactJson(['data' => ['count' => 3]]);

        $first = $this->getJson('/api/v1/notifications')->json('data.0.id');
        $this->postJson("/api/v1/notifications/$first/read")->assertNoContent();
        $this->postJson("/api/v1/notifications/$first/read")->assertNoContent(); // idempotent
        $this->getJson('/api/v1/notifications/unread-count')->assertJsonPath('data.count', 2);
        $this->assertTrue($this->getJson('/api/v1/notifications')->json('data.0.isRead'));

        $this->postJson('/api/v1/notifications/read')->assertNoContent();
        $this->postJson('/api/v1/notifications/read')->assertNoContent();
        $this->getJson('/api/v1/notifications/unread-count')->assertJsonPath('data.count', 0);
    }

    public function test_cannot_read_someone_elses_notification(): void
    {
        [$author, $fan] = User::factory()->count(2)->create();
        $postId = $this->postBy($author);
        $this->actingAs($fan, 'sanctum')->putJson("/api/v1/posts/$postId/like");
        $id = $this->actingAs($author, 'sanctum')->getJson('/api/v1/notifications')->json('data.0.id');

        $this->actingAs($fan, 'sanctum')->postJson("/api/v1/notifications/$id/read")->assertNotFound();
        $this->actingAs($fan, 'sanctum')->postJson('/api/v1/notifications/read')->assertNoContent();
        $this->actingAs($author, 'sanctum')->getJson('/api/v1/notifications/unread-count')->assertJsonPath('data.count', 1);
    }

    public function test_deleted_post_notifications_disappear_and_requires_auth(): void
    {
        [$author, $fan] = User::factory()->count(2)->create();
        $postId = $this->postBy($author);
        $this->actingAs($fan, 'sanctum')->putJson("/api/v1/posts/$postId/like");
        $this->actingAs($author, 'sanctum')->deleteJson("/api/v1/posts/$postId");

        $this->getJson('/api/v1/notifications')->assertJsonCount(0, 'data');
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/notifications/unread-count')->assertStatus(401);
    }

    public function test_notification_ids_are_lowercase_ulids(): void
    {
        [$author, $fan] = User::factory()->count(2)->create();
        $postId = $this->postBy($author);
        $this->actingAs($fan, 'sanctum');
        $this->putJson("/api/v1/posts/$postId/like");
        $this->postJson("/api/v1/posts/$postId/comments", ['content' => 'x']);
        $this->postJson("/api/v1/posts/$postId/shares");
        $this->postJson('/api/v1/friend-requests', ['userId' => $author->id]);

        $ids = array_column($this->actingAs($author, 'sanctum')->getJson('/api/v1/notifications')->json('data'), 'id');
        $this->assertCount(4, $ids);
        foreach ($ids as $id) {
            $this->assertMatchesRegularExpression('/^[0-9a-z]{26}$/', $id);
        }
    }
}
