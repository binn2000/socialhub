<?php

namespace Tests\Feature;

use App\Models\Story;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ImageUploadTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    private function files(): array
    {
        return Storage::disk('public')->allFiles();
    }

    public function test_image_only_post_is_stored_and_served(): void
    {
        $me = User::factory()->create();

        $r = $this->actingAs($me, 'sanctum')
            ->post('/api/v1/posts', ['image' => UploadedFile::fake()->image('photo.png', 300, 200), 'privacy' => 'friends'], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('data.content', '')
            ->assertJsonPath('data.privacy', 'friends');

        $this->assertMatchesRegularExpression('#/posts/\d{4}/\d{2}/[0-9a-z]{26}\.png$#', $r->json('data.imageUrl'));
        $this->assertCount(1, $this->files());
        $path = $this->files()[0];
        $this->assertSame([300, 200], array_slice(getimagesizefromstring(Storage::disk('public')->get($path)), 0, 2));
    }

    public function test_post_with_text_and_jpeg(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum')
            ->post('/api/v1/posts', ['content' => 'caption', 'image' => UploadedFile::fake()->image('p.jpg', 50, 50)], ['Accept' => 'application/json'])
            ->assertCreated()->assertJsonPath('data.content', 'caption');
        $this->assertStringEndsWith('.jpg', $this->files()[0]);
    }

    public function test_post_needs_text_or_image(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum')->postJson('/api/v1/posts', ['content' => '  '])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['content']]);
        $this->assertSame([], $this->files());
    }

    public function test_rejects_non_images_and_oversize(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $headers = ['Accept' => 'application/json'];

        $this->post('/api/v1/posts', ['image' => UploadedFile::fake()->create('evil.jpg', 5, 'text/plain')], $headers)
            ->assertStatus(422)->assertJsonStructure(['errors' => ['image']]);
        $this->post('/api/v1/posts', ['image' => UploadedFile::fake()->create('doc.pdf', 5, 'application/pdf')], $headers)->assertStatus(422);
        $this->post('/api/v1/posts', ['image' => UploadedFile::fake()->image('big.jpg')->size(10241)], $headers)->assertStatus(422);
        $this->post('/api/v1/posts', ['image' => UploadedFile::fake()->image('wide.png', 8001, 10)], $headers)
            ->assertStatus(422)->assertJsonStructure(['errors' => ['image']]);
        $this->assertSame([], $this->files());
    }

    public function test_deleting_a_post_removes_its_file(): void
    {
        $me = User::factory()->create();
        $id = $this->actingAs($me, 'sanctum')
            ->post('/api/v1/posts', ['image' => UploadedFile::fake()->image('a.png', 20, 20)], ['Accept' => 'application/json'])->json('data.id');
        $this->assertCount(1, $this->files());

        $this->deleteJson("/api/v1/posts/$id")->assertNoContent();
        $this->assertSame([], $this->files());
    }

    public function test_story_with_image_and_cleanup(): void
    {
        $me = User::factory()->create();
        $r = $this->actingAs($me, 'sanctum')
            ->post('/api/v1/stories', ['image' => UploadedFile::fake()->image('s.webp', 40, 60), 'background' => 'mint'], ['Accept' => 'application/json'])
            ->assertCreated()->assertJsonPath('data.text', null);
        $this->assertStringEndsWith('.webp', $r->json('data.imageUrl'));
        $this->assertCount(1, $this->files());

        $this->postJson('/api/v1/stories', ['text' => ' '])->assertStatus(422)->assertJsonStructure(['errors' => ['text']]);

        $this->deleteJson('/api/v1/stories/'.$r->json('data.id'))->assertNoContent();
        $this->assertSame([], $this->files());

        $this->post('/api/v1/stories', ['image' => UploadedFile::fake()->image('s.png', 10, 10)], ['Accept' => 'application/json'])->assertCreated();
        Story::query()->update(['expires_at' => now()->subMinute()]);
        $this->artisan('stories:purge-expired')->assertSuccessful();
        $this->assertSame([], $this->files());
    }

    public function test_avatar_set_replace_and_remove(): void
    {
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum');
        $headers = ['Accept' => 'application/json'];

        $first = $this->post('/api/v1/me/avatar', ['avatar' => UploadedFile::fake()->image('a.jpg', 64, 64)], $headers)
            ->assertOk()->json('data.avatarUrl');
        $this->assertStringContainsString('/avatars/', $first);
        $this->assertCount(1, $this->files());

        $second = $this->post('/api/v1/me/avatar', ['avatar' => UploadedFile::fake()->image('b.png', 64, 64)], $headers)->json('data.avatarUrl');
        $this->assertNotSame($first, $second);
        $this->assertCount(1, $this->files()); // old file deleted

        $this->getJson('/api/v1/me')->assertJsonPath('data.avatarUrl', $second);
        $this->deleteJson('/api/v1/me/avatar')->assertOk()->assertJsonPath('data.avatarUrl', null);
        $this->deleteJson('/api/v1/me/avatar')->assertOk();
        $this->assertSame([], $this->files());

        $this->post('/api/v1/me/avatar', [], $headers)->assertStatus(422)->assertJsonStructure(['errors' => ['avatar']]);
    }

    public function test_avatar_appears_in_author_summary(): void
    {
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum')->post('/api/v1/me/avatar', ['avatar' => UploadedFile::fake()->image('a.jpg', 32, 32)], ['Accept' => 'application/json']);

        $this->postJson('/api/v1/posts', ['content' => 'hi'])->assertJsonPath('data.author.avatarUrl', fn ($url) => str_contains($url, '/avatars/'));
    }

    public function test_images_go_to_the_configured_disk(): void
    {
        Storage::fake('cdn');
        config(['filesystems.images_disk' => 'cdn']);

        $url = $this->actingAs(User::factory()->create(), 'sanctum')
            ->post('/api/v1/posts', ['image' => UploadedFile::fake()->image('p.png', 30, 20)], ['Accept' => 'application/json'])
            ->assertCreated()->json('data.imageUrl');

        $this->assertCount(1, Storage::disk('cdn')->allFiles());
        $this->assertSame([], Storage::disk('public')->allFiles());
        $this->assertStringContainsString('/posts/', $url);
    }
}
