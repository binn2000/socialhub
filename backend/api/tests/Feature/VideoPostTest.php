<?php

namespace Tests\Feature;

use App\Jobs\ProcessPostVideo;
use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class VideoPostTest extends TestCase
{
    use RefreshDatabase;

    private array $json = ['Accept' => 'application/json'];

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    /** A real clip made with ffmpeg: a test picture and a tone, so the conversion runs for real. */
    private function clip(int $seconds = 2): UploadedFile
    {
        $file = sys_get_temp_dir().'/clip-'.uniqid().'.mp4';
        $result = Process::run([
            config('services.ffmpeg.binary'), '-y', '-f', 'lavfi', '-i', "testsrc=size=160x120:rate=5:duration=$seconds",
            '-f', 'lavfi', '-i', "sine=frequency=440:duration=$seconds", '-c:v', 'libx264', '-preset', 'ultrafast',
            '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-shortest', $file,
        ]);
        if (! $result->successful()) {
            $this->markTestSkipped('ffmpeg is not installed.');
        }
        $this->beforeApplicationDestroyed(fn () => @unlink($file));

        return new UploadedFile($file, 'clip.mp4', 'video/mp4', null, true);
    }

    private function befriend(User $a, User $b): void
    {
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'accepted']);
    }

    public function test_a_video_is_converted_and_the_post_becomes_ready(): void
    {
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum');

        $response = $this->post('/api/v1/posts', ['content' => 'Clip', 'video' => $this->clip()], $this->json)
            ->assertCreated();

        // The test queue runs jobs at once, so the answer to a later read is final.
        $id = $response->json('data.id');
        $video = $this->getJson("/api/v1/posts/$id")->assertOk()->json('data.video');
        $this->assertSame('ready', $video['status']);
        $this->assertSame(2, $video['durationSeconds']);
        $this->assertSame(160, $video['width']);
        $this->assertStringEndsWith('.mp4', $video['url']);
        $this->assertStringEndsWith('.jpg', $video['thumbnailUrl']);

        $files = Storage::disk('public')->allFiles();
        $this->assertCount(2, $files); // the mp4 and the thumbnail; the source is gone
        $this->assertNull(Post::find($id)->video_source_path);
        $this->assertNull($this->getJson("/api/v1/posts/$id")->json('data.imageUrl'));
    }

    public function test_others_see_the_post_only_when_the_video_is_ready(): void
    {
        Queue::fake();
        $me = User::factory()->create();
        $friend = User::factory()->create();
        $this->befriend($me, $friend);

        $id = $this->actingAs($me, 'sanctum')
            ->post('/api/v1/posts', ['content' => 'Clip', 'privacy' => 'public', 'video' => $this->clip()], $this->json)
            ->assertCreated()->assertJsonPath('data.video.status', 'processing')
            ->assertJsonPath('data.video.url', null)->json('data.id');
        Queue::assertPushed(ProcessPostVideo::class);

        $this->assertContains($id, array_column($this->getJson('/api/v1/feed')->json('data'), 'id')); // mine
        $this->actingAs($friend, 'sanctum');
        $this->assertNotContains($id, array_column($this->getJson('/api/v1/feed')->json('data'), 'id'));
        $this->getJson("/api/v1/posts/$id")->assertNotFound();
        $this->assertSame([], $this->getJson('/api/v1/explore?filter=short_video')->json('data'));

        (new ProcessPostVideo($id))->handle();

        $this->assertContains($id, array_column($this->getJson('/api/v1/feed')->json('data'), 'id'));
        $this->assertSame([$id], array_column($this->getJson('/api/v1/explore?filter=short_video')->json('data'), 'id'));
        $this->assertContains($id, array_column($this->getJson('/api/v1/feed?filter=media')->json('data'), 'id'));
    }

    public function test_a_video_that_cannot_be_converted_marks_the_post_failed(): void
    {
        Queue::fake();
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum');
        $id = $this->post('/api/v1/posts', ['content' => 'Clip', 'video' => $this->clip()], $this->json)->json('data.id');

        $source = Post::find($id)->video_source_path;
        Storage::disk('public')->put($source, 'not a video');
        $job = new ProcessPostVideo($id);
        try {
            $job->handle();
            $this->fail('The conversion should have failed.');
        } catch (\Throwable $e) {
            $job->failed($e);
        }

        $this->getJson("/api/v1/posts/$id")->assertJsonPath('data.video.status', 'failed')->assertJsonPath('data.video.url', null);
        $this->assertSame([], Storage::disk('public')->allFiles()); // the source is removed
    }

    public function test_a_file_that_is_not_a_video_is_refused(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->post('/api/v1/posts', ['video' => UploadedFile::fake()->create('x.mp4', 10, 'video/mp4')], $this->json)
            ->assertUnprocessable()->assertJsonValidationErrors('video');
        $this->post('/api/v1/posts', ['video' => UploadedFile::fake()->create('x.txt', 10, 'text/plain')], $this->json)
            ->assertUnprocessable()->assertJsonValidationErrors('video');
        $this->assertSame([], Storage::disk('public')->allFiles());
        $this->assertSame(0, Post::count());
    }

    public function test_a_video_over_a_minute_is_refused(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->post('/api/v1/posts', ['video' => $this->clip(62)], $this->json)
            ->assertUnprocessable()->assertJsonValidationErrors('video');
        $this->assertSame(0, Post::count());
    }

    public function test_a_post_has_images_or_a_video_not_both(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->post('/api/v1/posts', ['video' => $this->clip(), 'image' => UploadedFile::fake()->image('a.jpg')], $this->json)
            ->assertUnprocessable()->assertJsonValidationErrors('video');
        $this->assertSame(0, Post::count());
    }

    public function test_deleting_the_post_removes_the_video_files(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $id = $this->post('/api/v1/posts', ['video' => $this->clip()], $this->json)->assertCreated()->json('data.id');
        $this->assertCount(2, Storage::disk('public')->allFiles());

        $this->deleteJson("/api/v1/posts/$id")->assertNoContent();

        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_a_post_without_a_video_has_null_video(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->postJson('/api/v1/posts', ['content' => 'Chữ thôi'])->assertCreated()->assertJsonPath('data.video', null);
    }

    public function test_a_lost_upload_answers_422_not_500(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        // PHP reports a file over upload_max_filesize like this: an error code and no temporary file.
        $lost = new UploadedFile('', 'clip.mp4', 'video/mp4', UPLOAD_ERR_INI_SIZE, true);

        $this->post('/api/v1/posts', ['video' => $lost], $this->json + ['Idempotency-Key' => (string) Str::uuid()])
            ->assertUnprocessable()->assertJsonValidationErrors('video');
        $this->assertSame(0, Post::count());
    }
}
