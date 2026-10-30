<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class MultiImagePostTest extends TestCase
{
    use RefreshDatabase;

    private array $json = ['Accept' => 'application/json'];

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    private function images(int $count): array
    {
        return array_map(fn (int $i) => UploadedFile::fake()->image("p$i.jpg", 40 + $i, 30), range(1, $count));
    }

    public function test_a_post_keeps_several_images_in_order(): void
    {
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum');

        $response = $this->post('/api/v1/posts', ['content' => 'Chuyến đi', 'images' => $this->images(3)], $this->json)
            ->assertCreated();

        $urls = $response->json('data.imageUrls');
        $this->assertCount(3, $urls);
        $this->assertSame($urls[0], $response->json('data.imageUrl')); // the first one stays in imageUrl
        $this->assertCount(3, Storage::disk('public')->allFiles());
        $this->assertSame([0, 1, 2], DB::table('post_images')->orderBy('id')->pluck('position')->all());

        // the same list comes back from every endpoint
        $id = $response->json('data.id');
        $this->getJson("/api/v1/posts/$id")->assertJsonPath('data.imageUrls', $urls);
        $this->assertSame($urls, $this->getJson('/api/v1/feed')->json('data.0.imageUrls'));
        $this->assertSame($urls, $this->getJson('/api/v1/explore')->json('data.0.imageUrls'));
    }

    public function test_one_image_and_text_only_posts_still_work(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        $single = $this->post('/api/v1/posts', ['image' => $this->images(1)[0]], $this->json)->assertCreated();
        $this->assertCount(1, $single->json('data.imageUrls'));
        $this->assertSame($single->json('data.imageUrls.0'), $single->json('data.imageUrl'));

        $text = $this->postJson('/api/v1/posts', ['content' => 'chỉ chữ'])->assertCreated();
        $this->assertSame([], $text->json('data.imageUrls'));
        $this->assertNull($text->json('data.imageUrl'));
    }

    public function test_the_image_rules_are_checked(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        $this->post('/api/v1/posts', ['images' => $this->images(11)], $this->json)
            ->assertStatus(422)->assertJsonStructure(['errors' => ['images']]);
        $this->post('/api/v1/posts', ['image' => $this->images(1)[0], 'images' => $this->images(1)], $this->json)
            ->assertStatus(422)->assertJsonStructure(['errors' => ['images']]);
        $this->post('/api/v1/posts', ['images' => [UploadedFile::fake()->create('x.pdf', 10, 'application/pdf')]], $this->json)
            ->assertStatus(422);
        $this->post('/api/v1/posts', ['content' => '  '], $this->json)->assertStatus(422)->assertJsonStructure(['errors' => ['content']]);

        // a broken file among good ones stores nothing
        $this->post('/api/v1/posts', ['images' => [
            UploadedFile::fake()->image('ok.jpg', 20, 20),
            UploadedFile::fake()->createWithContent('bad.jpg', 'not an image at all'),
        ]], $this->json)->assertStatus(422)->assertJsonStructure(['errors' => ['images.1']]);
        $this->assertSame([], Storage::disk('public')->allFiles());
        $this->assertSame(0, Post::count());
    }

    public function test_deleting_the_post_removes_every_file(): void
    {
        $me = User::factory()->create();
        $this->actingAs($me, 'sanctum');
        $id = $this->post('/api/v1/posts', ['images' => $this->images(3)], $this->json)->json('data.id');
        $this->assertCount(3, Storage::disk('public')->allFiles());

        $this->deleteJson("/api/v1/posts/$id")->assertNoContent();

        $this->assertSame([], Storage::disk('public')->allFiles()); // the queue is synchronous in tests
    }

    public function test_photos_lists_every_image_and_follows_privacy(): void
    {
        [$owner, $friend, $stranger] = User::factory()->count(3)->create();
        Friendship::create(['requester_id' => $owner->id, 'addressee_id' => $friend->id, 'status' => 'accepted']);
        $this->actingAs($owner, 'sanctum');
        $this->post('/api/v1/posts', ['images' => $this->images(2)], $this->json)->assertCreated();
        $this->post('/api/v1/posts', ['images' => $this->images(2), 'privacy' => 'friends'], $this->json)->assertCreated();
        $this->post('/api/v1/posts', ['images' => $this->images(1), 'privacy' => 'only_me'], $this->json)->assertCreated();

        $count = fn (User $viewer) => count($this->actingAs($viewer, 'sanctum')->getJson("/api/v1/users/{$owner->id}/photos")->json('data'));

        $this->assertSame(5, $count($owner));
        $this->assertSame(4, $count($friend));
        $this->assertSame(2, $count($stranger));

        $first = $this->getJson("/api/v1/users/{$owner->id}/photos?limit=1")->json();
        $this->assertTrue($first['meta']['hasMore']);
    }

    public function test_a_row_without_image_rows_still_shows_its_first_image(): void
    {
        $author = User::factory()->create();
        $post = Post::forceCreate(['id' => strtolower((string) \Illuminate\Support\Str::ulid()), 'user_id' => $author->id, 'image_path' => 'posts/old.jpg', 'privacy' => 'public']);
        $this->actingAs($author, 'sanctum');

        // an old row without post_images still shows its single image
        $this->getJson("/api/v1/posts/{$post->id}")->assertJsonPath('data.imageUrl', Storage::disk('public')->url('posts/old.jpg'));
    }
}
