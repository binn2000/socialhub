<?php

namespace Tests\Feature;

use App\Jobs\CreateNotification;
use App\Models\Friendship;
use App\Models\Post;
use App\Models\PostImage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class ProfileSupportTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    private function makePost(User $author, array $attributes = []): Post
    {
        $post = Post::forceCreate($attributes + [
            'id' => strtolower((string) Str::ulid()), 'user_id' => $author->id, 'content' => 'hello',
            'privacy' => 'public', 'created_at' => now(), 'updated_at' => now(),
        ]);
        if ($post->image_path) {
            PostImage::create(['post_id' => $post->id, 'path' => $post->image_path, 'position' => 0, 'created_at' => $post->created_at]);
        }

        return $post;
    }

    private function befriend(User $a, User $b, string $status = 'accepted'): void
    {
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => $status]);
    }

    private function ids(array $response): array
    {
        return array_column($response['data'], 'id');
    }

    // ---- cover image and about

    public function test_the_about_fields_are_saved_shown_and_cleared(): void
    {
        [$me, $viewer] = User::factory()->count(2)->create();
        $this->actingAs($me, 'sanctum');

        $this->patchJson('/api/v1/me', [
            'location' => ' Hà Nội ', 'hometown' => 'Huế', 'workplace' => 'SocialHub', 'education' => 'ĐH Bách Khoa',
            'website' => 'https://example.com/me', 'birthday' => '1998-05-17',
        ])->assertOk()
            ->assertJsonPath('data.about.location', 'Hà Nội')
            ->assertJsonPath('data.about.birthday', '1998-05-17')
            ->assertJsonPath('data.coverUrl', null);

        $profile = $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/users/{$me->id}")->assertOk();
        $profile->assertJsonPath('data.about.workplace', 'SocialHub')
            ->assertJsonPath('data.about.website', 'https://example.com/me')
            ->assertJsonPath('data.coverUrl', null);
        $this->assertNotNull($profile->json('data.createdAt'));

        // blank and null clear a field; a field that is not sent stays
        $this->actingAs($me, 'sanctum')->patchJson('/api/v1/me', ['location' => '  ', 'hometown' => null])->assertOk()
            ->assertJsonPath('data.about.location', null)
            ->assertJsonPath('data.about.hometown', null)
            ->assertJsonPath('data.about.workplace', 'SocialHub');
        $this->getJson('/api/v1/me')->assertJsonPath('data.about.education', 'ĐH Bách Khoa');
    }

    public function test_the_about_fields_are_checked(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        foreach ([
            ['website' => 'javascript:alert(1)'],
            ['website' => 'not a url'],
            ['birthday' => '2999-01-01'],
            ['birthday' => '17/05/1998'],
            ['birthday' => '1800-01-01'],
            ['location' => str_repeat('x', 101)],
        ] as $body) {
            $this->patchJson('/api/v1/me', $body)->assertStatus(422)
                ->assertJsonPath('code', 'validation_failed')->assertJsonStructure(['errors' => [array_key_first($body)]]);
        }
    }

    public function test_the_cover_is_set_replaced_and_removed(): void
    {
        [$me, $viewer] = User::factory()->count(2)->create();
        $this->actingAs($me, 'sanctum');
        $headers = ['Accept' => 'application/json'];

        $first = $this->post('/api/v1/me/cover', ['cover' => UploadedFile::fake()->image('c.jpg', 120, 40)], $headers)
            ->assertOk()->json('data.coverUrl');
        $this->assertStringContainsString('/covers/', $first);

        $second = $this->post('/api/v1/me/cover', ['cover' => UploadedFile::fake()->image('d.png', 120, 40)], $headers)
            ->json('data.coverUrl');
        $this->assertNotSame($first, $second);
        $this->assertCount(1, Storage::disk('public')->allFiles()); // old file deleted

        $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/users/{$me->id}")->assertJsonPath('data.coverUrl', $second);

        $this->actingAs($me, 'sanctum')->deleteJson('/api/v1/me/cover')->assertOk()->assertJsonPath('data.coverUrl', null);
        $this->deleteJson('/api/v1/me/cover')->assertOk();
        $this->assertSame([], Storage::disk('public')->allFiles());

        $this->post('/api/v1/me/cover', [], $headers)->assertStatus(422)->assertJsonStructure(['errors' => ['cover']]);
        $this->post('/api/v1/me/cover', ['cover' => UploadedFile::fake()->create('x.pdf', 10, 'application/pdf')], $headers)->assertStatus(422);
    }

    public function test_deleting_the_account_removes_the_cover_file_too(): void
    {
        $me = User::factory()->create(['password' => 'secret-pass-1']);
        $this->actingAs($me, 'sanctum');
        $this->post('/api/v1/me/cover', ['cover' => UploadedFile::fake()->image('c.jpg', 50, 50)], ['Accept' => 'application/json'])->assertOk();

        $this->deleteJson('/api/v1/me', ['password' => 'secret-pass-1'])->assertNoContent();

        $this->assertSame([], Storage::disk('public')->allFiles()); // the queue runs synchronously in tests
    }

    // ---- photos

    public function test_photos_list_the_images_the_viewer_may_see(): void
    {
        [$owner, $friend, $stranger] = User::factory()->count(3)->create();
        $this->befriend($owner, $friend);
        $public = $this->makePost($owner, ['image_path' => 'posts/a.jpg', 'created_at' => now()->subMinutes(3)]);
        $friends = $this->makePost($owner, ['image_path' => 'posts/b.jpg', 'privacy' => 'friends', 'created_at' => now()->subMinutes(2)]);
        $private = $this->makePost($owner, ['image_path' => 'posts/c.jpg', 'privacy' => 'only_me', 'created_at' => now()->subMinute()]);
        $this->makePost($owner, ['content' => 'text only']);

        $postIds = fn () => array_column($this->getJson("/api/v1/users/{$owner->id}/photos")->assertOk()->json('data'), 'postId');

        $this->actingAs($owner, 'sanctum');
        $this->assertSame([$private->id, $friends->id, $public->id], $postIds()); // newest first
        $this->actingAs($friend, 'sanctum');
        $this->assertSame([$friends->id, $public->id], $postIds());
        $this->actingAs($stranger, 'sanctum');
        $first = $this->getJson("/api/v1/users/{$owner->id}/photos")->json('data.0');
        $this->assertSame([$public->id], $postIds());
        $this->assertStringContainsString('posts/a.jpg', $first['imageUrl']);
        $this->assertArrayHasKey('createdAt', $first);
    }

    public function test_photos_page_and_respect_blocks(): void
    {
        [$owner, $viewer] = User::factory()->count(2)->create();
        foreach (range(1, 3) as $i) {
            $this->makePost($owner, ['image_path' => "posts/$i.jpg", 'created_at' => now()->subMinutes(10 - $i)]);
        }
        $this->actingAs($viewer, 'sanctum');

        $first = $this->getJson("/api/v1/users/{$owner->id}/photos?limit=2")->assertOk();
        $this->assertCount(2, $first->json('data'));
        $this->assertTrue($first->json('meta.hasMore'));
        $second = $this->getJson("/api/v1/users/{$owner->id}/photos?limit=2&cursor=".urlencode($first->json('meta.nextCursor')))->assertOk();
        $this->assertCount(1, $second->json('data'));
        $this->assertFalse($second->json('meta.hasMore'));
        $this->getJson("/api/v1/users/{$owner->id}/photos?cursor=garbage")->assertStatus(400);

        $this->actingAs($owner, 'sanctum')->putJson("/api/v1/users/{$viewer->id}/block")->assertNoContent();
        $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/users/{$owner->id}/photos")->assertNotFound();
        $this->getJson('/api/v1/users/nobody/photos')->assertNotFound();
    }

    // ---- a user's friends

    public function test_the_friends_of_a_user_with_the_viewers_relationship(): void
    {
        [$owner, $viewer, $a, $b, $outsider] = User::factory()->count(5)->create(['name' => 'Zed']);
        $a->update(['name' => 'An']);
        $b->update(['name' => 'Bình']);
        $this->befriend($owner, $a);
        $this->befriend($b, $owner);
        $this->befriend($owner, $viewer);
        $this->befriend($viewer, $a); // the viewer knows An too
        $this->befriend($owner, $outsider, 'pending'); // not a friend yet
        $this->actingAs($viewer, 'sanctum');

        $response = $this->getJson("/api/v1/users/{$owner->id}/friends")->assertOk();

        $this->assertSame([$a->id, $b->id], $this->ids($response->json())); // by name; not the viewer, not the pending one
        $this->assertSame('friends', $response->json('data.0.friendship.status'));
        $this->assertSame('none', $response->json('data.1.friendship.status'));
        $this->assertSame(1, $response->json('data.1.mutualFriendsCount')); // owner is friends with both
    }

    public function test_user_friends_page_hide_blocked_people_and_blockers(): void
    {
        [$owner, $viewer] = User::factory()->count(2)->create();
        $friends = User::factory()->count(3)->create();
        foreach ($friends as $friend) {
            $this->befriend($owner, $friend);
        }
        $this->actingAs($viewer, 'sanctum');

        $first = $this->getJson("/api/v1/users/{$owner->id}/friends?limit=2")->assertOk();
        $this->assertTrue($first->json('meta.hasMore'));
        $second = $this->getJson("/api/v1/users/{$owner->id}/friends?limit=2&cursor=".urlencode($first->json('meta.nextCursor')));
        $this->assertCount(3, array_unique([...$this->ids($first->json()), ...$this->ids($second->json())]));

        $this->putJson("/api/v1/users/{$friends[0]->id}/block")->assertNoContent(); // the viewer blocked one of them
        $this->assertNotContains($friends[0]->id, $this->ids($this->getJson("/api/v1/users/{$owner->id}/friends")->json()));

        $friends[1]->delete(); // deleted accounts are not listed either
        $this->assertSame([$friends[2]->id], $this->ids($this->getJson("/api/v1/users/{$owner->id}/friends")->json()));

        $this->actingAs($owner, 'sanctum')->putJson("/api/v1/users/{$viewer->id}/block");
        $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/users/{$owner->id}/friends")->assertNotFound();
    }

    // ---- people you may know

    public function test_suggestions_rank_by_mutual_friends_and_skip_known_people(): void
    {
        [$me, $friend1, $friend2, $two, $one, $none, $pending, $blocked, $deleted] = User::factory()->count(9)->create();
        $this->befriend($me, $friend1);
        $this->befriend($me, $friend2);
        $this->befriend($friend1, $two);
        $this->befriend($friend2, $two);
        $this->befriend($friend1, $one);
        $this->befriend($me, $pending, 'pending');
        $this->befriend($friend1, $blocked);
        $this->befriend($friend1, $deleted);
        $deleted->delete();
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/users/{$blocked->id}/block");

        $response = $this->getJson('/api/v1/users/suggestions')->assertOk();
        $ids = $this->ids($response->json());

        $this->assertSame([$two->id, $one->id], array_slice($ids, 0, 2));
        $this->assertSame(2, $response->json('data.0.mutualFriendsCount'));
        $this->assertSame([$none->id], array_slice($ids, 2)); // the rest has nobody in common
        foreach ([$me, $friend1, $friend2, $pending, $blocked, $deleted] as $excluded) {
            $this->assertNotContains($excluded->id, $ids);
        }
        $this->assertSame('none', $response->json('data.0.friendship.status'));
    }

    public function test_a_new_account_still_gets_suggestions_and_they_page(): void
    {
        $me = User::factory()->create();
        $others = User::factory()->count(5)->create();
        $this->actingAs($me, 'sanctum');

        $first = $this->getJson('/api/v1/users/suggestions?limit=3')->assertOk();
        $this->assertCount(3, $first->json('data'));
        $this->assertTrue($first->json('meta.hasMore'));
        $second = $this->getJson('/api/v1/users/suggestions?limit=3&cursor='.urlencode($first->json('meta.nextCursor')))->assertOk();
        $this->assertCount(2, $second->json('data'));
        $this->assertFalse($second->json('meta.hasMore'));
        $this->assertNull($second->json('meta.nextCursor'));

        $all = [...$this->ids($first->json()), ...$this->ids($second->json())];
        $this->assertEqualsCanonicalizing($others->pluck('id')->all(), $all);
        $this->getJson('/api/v1/users/suggestions?cursor=garbage')->assertStatus(400);
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/users/suggestions')->assertUnauthorized();
    }

    // ---- searching conversations

    public function test_conversations_can_be_searched_by_the_other_persons_name(): void
    {
        $me = User::factory()->create();
        $lan = User::factory()->create(['name' => 'Lan Hương', 'username' => 'lan_h']);
        $khang = User::factory()->create(['name' => 'Duy Khang', 'username' => 'dkhang']);
        foreach ([$lan, $khang] as $friend) {
            $this->befriend($me, $friend);
            $id = $this->actingAs($me, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $friend->id])->json('data.id');
            $this->postJson("/api/v1/conversations/$id/messages", ['text' => 'hi'])->assertCreated();
        }

        $names = fn (string $query) => collect($this->getJson('/api/v1/conversations'.$query)->assertOk()->json('data'))
            ->pluck('participant.name')->all();
        $this->assertCount(2, $names(''));
        $this->assertSame(['Lan Hương'], $names('?q=Lan'));
        $this->assertSame(['Duy Khang'], $names('?q=dkhang')); // by username
        $this->assertSame([], $names('?q=nobody'));
        $this->assertSame([], $names('?q='.urlencode('%'))); // % is literal, not "everything"
        $this->assertCount(2, $names('?q=')); // blank means no search
    }

    public function test_a_conversation_cursor_belongs_to_its_query(): void
    {
        $me = User::factory()->create();
        foreach (User::factory()->count(2)->create() as $friend) {
            $this->befriend($me, $friend);
            $id = $this->actingAs($me, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $friend->id])->json('data.id');
            $this->postJson("/api/v1/conversations/$id/messages", ['text' => 'hi']);
        }
        $cursor = $this->getJson('/api/v1/conversations?limit=1')->json('meta.nextCursor');

        $this->assertNotNull($cursor);
        $this->getJson('/api/v1/conversations?limit=1&q=a&cursor='.urlencode($cursor))->assertStatus(400);
    }

    // ---- notification filters

    public function test_notifications_filter_by_category_and_unread(): void
    {
        [$me, $actor] = User::factory()->count(2)->create();
        $post = $this->makePost($me);
        CreateNotification::dispatchSync($me->id, $actor->id, 'like', postId: $post->id, dedupeKey: 'l');
        CreateNotification::dispatchSync($me->id, $actor->id, 'comment', postId: $post->id);
        CreateNotification::dispatchSync($me->id, $actor->id, 'friend_accepted', dedupeKey: 'f');
        DB::table('notifications')->where('type', 'like')->update(['read_at' => now()]);
        $this->actingAs($me, 'sanctum');

        $types = fn (string $query) => array_column($this->getJson('/api/v1/notifications'.$query)->assertOk()->json('data'), 'type');

        $this->assertCount(3, $types(''));
        $this->assertEqualsCanonicalizing(['like', 'comment'], $types('?category=interactions'));
        $this->assertSame(['friend_accepted'], $types('?category=friends'));
        $this->assertEqualsCanonicalizing(['comment', 'friend_accepted'], $types('?unread=true'));
        $this->assertSame(['comment'], $types('?unread=1&category=interactions'));
        $this->assertCount(3, $types('?unread=false'));
        $this->getJson('/api/v1/notifications?category=other')->assertStatus(422)->assertJsonStructure(['errors' => ['category']]);

        $cursor = $this->getJson('/api/v1/notifications?limit=1')->json('meta.nextCursor');
        $this->getJson('/api/v1/notifications?limit=1&category=friends&cursor='.urlencode($cursor))->assertStatus(400);
    }

    // ---- feed tabs

    public function test_feed_tabs(): void
    {
        [$me, $friend, $stranger] = User::factory()->count(3)->create();
        $this->befriend($me, $friend);
        $mine = $this->makePost($me, ['content' => 'mine', 'created_at' => now()->subMinutes(5)]);
        $older = $this->makePost($friend, ['content' => 'older', 'likes_count' => 5, 'created_at' => now()->subDays(2)]);
        $newer = $this->makePost($friend, ['content' => 'newer', 'likes_count' => 1, 'created_at' => now()->subMinutes(2)]);
        $old = $this->makePost($friend, ['content' => 'ancient', 'likes_count' => 99, 'created_at' => now()->subDays(30)]);
        $this->makePost($stranger, ['content' => 'stranger', 'likes_count' => 50]);
        $this->actingAs($me, 'sanctum');

        $ids = fn (string $query) => $this->ids($this->getJson('/api/v1/feed'.$query)->assertOk()->json());

        $this->assertSame([$newer->id, $mine->id, $older->id, $old->id], $ids(''));
        $this->assertSame($ids(''), $ids('?filter=all'));
        $this->assertSame([$newer->id, $older->id, $old->id], $ids('?filter=friends'));
        $this->assertSame([$older->id, $newer->id, $mine->id], $ids('?filter=popular')); // last 7 days, most liked first
        $this->getJson('/api/v1/feed?filter=trending')->assertStatus(422)->assertJsonStructure(['errors' => ['filter']]);
    }

    public function test_feed_tab_pages_and_cursors_are_not_interchangeable(): void
    {
        [$me, $friend] = User::factory()->count(2)->create();
        $this->befriend($me, $friend);
        foreach (range(1, 3) as $i) {
            $this->makePost($friend, ['likes_count' => $i, 'created_at' => now()->subMinutes($i)]);
        }
        $this->actingAs($me, 'sanctum');

        $first = $this->getJson('/api/v1/feed?filter=popular&limit=2')->assertOk();
        $this->assertTrue($first->json('meta.hasMore'));
        $second = $this->getJson('/api/v1/feed?filter=popular&limit=2&cursor='.urlencode($first->json('meta.nextCursor')))->assertOk();
        $this->assertCount(1, $second->json('data'));
        $this->assertSame([3, 2, 1], array_column([...$first->json('data'), ...$second->json('data')], 'likes'));

        $this->getJson('/api/v1/feed?filter=friends&limit=2&cursor='.urlencode($first->json('meta.nextCursor')))->assertStatus(400);
    }

    public function test_blocked_people_are_missing_from_every_new_list(): void
    {
        [$me, $other] = User::factory()->count(2)->create();
        $this->befriend($me, $other);
        $this->makePost($other, ['image_path' => 'posts/x.jpg']);
        $this->actingAs($me, 'sanctum')->putJson("/api/v1/users/{$other->id}/block")->assertNoContent();

        $this->assertNotContains($other->id, $this->ids($this->getJson('/api/v1/users/suggestions')->json()));
        $this->assertSame([], $this->getJson("/api/v1/users/{$other->id}/photos")->json('data'));
        $this->assertSame([], $this->getJson('/api/v1/feed?filter=friends')->json('data'));
    }
}
