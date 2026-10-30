<?php

namespace Tests\Feature;

use App\Jobs\CreateNotification;
use App\Jobs\DeleteStoredImage;
use App\Models\Comment;
use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class QueuedJobsTest extends TestCase
{
    use RefreshDatabase;

    private function makePost(User $author): Post
    {
        return Post::forceCreate([
            'id' => (string) Str::ulid(), 'user_id' => $author->id, 'content' => 'hello',
            'privacy' => 'public', 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    public function test_like_queues_a_notification_instead_of_writing_it(): void
    {
        Queue::fake();
        [$author, $fan] = User::factory()->count(2)->create();
        $post = $this->makePost($author);

        $this->actingAs($fan, 'sanctum')->putJson("/api/v1/posts/{$post->id}/like")->assertOk();

        $this->assertSame(0, DB::table('notifications')->count());
        Queue::assertPushed(CreateNotification::class, fn (CreateNotification $job) => $job->recipientId === $author->id
            && $job->actorId === $fan->id
            && $job->type === 'like'
            && $job->postId === $post->id
            && $job->dedupeKey === "like:{$fan->id}:{$post->id}");
    }

    public function test_comment_share_and_friend_actions_queue_their_notifications(): void
    {
        Queue::fake();
        [$author, $other] = User::factory()->count(2)->create();
        $post = $this->makePost($author);
        $this->actingAs($other, 'sanctum');

        $this->postJson("/api/v1/posts/{$post->id}/comments", ['content' => 'hi'])->assertCreated();
        $this->postJson("/api/v1/posts/{$post->id}/shares")->assertOk();
        $requestId = $this->postJson('/api/v1/friend-requests', ['userId' => $author->id])->assertCreated()->json('data.id');
        $this->actingAs($author, 'sanctum')->postJson("/api/v1/friend-requests/$requestId/accept")->assertOk();

        $this->assertSame(0, DB::table('notifications')->count());
        $types = [];
        Queue::assertPushed(CreateNotification::class, function (CreateNotification $job) use (&$types) {
            $types[] = $job->type;

            return true;
        });
        $this->assertEqualsCanonicalizing(['comment', 'share', 'friend_request', 'friend_accepted'], $types);
    }

    public function test_the_job_writes_the_row_and_runs_twice_without_duplicates(): void
    {
        [$author, $fan] = User::factory()->count(2)->create();
        $post = $this->makePost($author);
        $job = new CreateNotification($author->id, $fan->id, 'like', postId: $post->id, dedupeKey: 'like:x:y');

        $job->handle();
        $job->handle();

        $this->assertSame(1, DB::table('notifications')->where(['user_id' => $author->id, 'type' => 'like'])->count());
    }

    public function test_the_job_never_notifies_the_actor_about_themselves(): void
    {
        $author = User::factory()->create();

        (new CreateNotification($author->id, $author->id, 'like', postId: $this->makePost($author)->id))->handle();

        $this->assertSame(0, DB::table('notifications')->count());
    }

    public function test_the_job_skips_a_post_or_comment_deleted_while_it_waited(): void
    {
        [$author, $fan] = User::factory()->count(2)->create();
        $post = $this->makePost($author);
        $comment = Comment::forceCreate(['id' => (string) Str::ulid(), 'post_id' => $post->id, 'user_id' => $fan->id, 'content' => 'x', 'created_at' => now()]);
        $commentJob = new CreateNotification($author->id, $fan->id, 'comment', postId: $post->id, commentId: $comment->id);
        $likeJob = new CreateNotification($author->id, $fan->id, 'like', postId: $post->id);

        $comment->delete();
        $commentJob->handle();
        $post->delete();
        $likeJob->handle();

        $this->assertSame(0, DB::table('notifications')->count());
    }

    public function test_friend_notification_job_keeps_the_friendship_id(): void
    {
        [$a, $b] = User::factory()->count(2)->create();
        $friendship = Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'pending']);

        (new CreateNotification($b->id, $a->id, 'friend_request', friendshipId: $friendship->id, dedupeKey: "friend_request:{$friendship->id}"))->handle();

        $this->assertSame($friendship->id, DB::table('notifications')->value('friendship_id'));
    }

    public function test_deleting_a_post_queues_the_image_removal(): void
    {
        Storage::fake('public');
        Queue::fake();
        $me = User::factory()->create();
        $id = $this->actingAs($me, 'sanctum')
            ->post('/api/v1/posts', ['image' => UploadedFile::fake()->image('a.png', 20, 20)], ['Accept' => 'application/json'])->json('data.id');
        $path = Post::find($id)->image_path;

        $this->deleteJson("/api/v1/posts/$id")->assertNoContent();

        Storage::disk('public')->assertExists($path); // still there until the job runs
        Queue::assertPushed(DeleteStoredImage::class, fn (DeleteStoredImage $job) => $job->path === $path);

        (new DeleteStoredImage($path))->handle();
        Storage::disk('public')->assertMissing($path);
    }

    public function test_replacing_and_removing_an_avatar_queue_the_old_file(): void
    {
        Storage::fake('public');
        Queue::fake();
        $me = User::factory()->create();
        $headers = ['Accept' => 'application/json'];
        $this->actingAs($me, 'sanctum');

        $first = $this->post('/api/v1/me/avatar', ['avatar' => UploadedFile::fake()->image('a.png', 20, 20)], $headers);
        $firstPath = $me->fresh()->avatar_path;
        $this->post('/api/v1/me/avatar', ['avatar' => UploadedFile::fake()->image('b.png', 20, 20)], $headers);
        $secondPath = $me->fresh()->avatar_path;
        $this->deleteJson('/api/v1/me/avatar')->assertOk();

        $first->assertOk();
        Queue::assertPushed(DeleteStoredImage::class, fn (DeleteStoredImage $job) => $job->path === $firstPath);
        Queue::assertPushed(DeleteStoredImage::class, fn (DeleteStoredImage $job) => $job->path === $secondPath);
        Queue::assertPushedTimes(DeleteStoredImage::class, 2);
    }

    public function test_the_purge_command_queues_expired_story_images(): void
    {
        Storage::fake('public');
        Queue::fake();
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum')
            ->post('/api/v1/stories', ['image' => UploadedFile::fake()->image('s.png', 10, 10)], ['Accept' => 'application/json'])->assertCreated();
        DB::table('stories')->update(['expires_at' => now()->subMinute()]);

        $this->artisan('stories:purge-expired')->assertSuccessful();

        Queue::assertPushed(DeleteStoredImage::class);
    }
}
