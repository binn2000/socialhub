<?php

namespace Tests\Feature;

use App\Models\Friendship;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ConversationThemeAndMediaTest extends TestCase
{
    use RefreshDatabase;

    private function chat(): array
    {
        [$a, $b] = User::factory()->count(2)->create();
        Friendship::create(['requester_id' => $a->id, 'addressee_id' => $b->id, 'status' => 'accepted']);
        $c = $this->actingAs($a, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $b->id])->json('data.id');

        return [$a, $b, $c];
    }

    public function test_the_theme_is_shared_by_both_people_and_validated(): void
    {
        [$a, $b, $c] = $this->chat();

        $this->postJson("/api/v1/conversations/$c/messages", ['text' => 'Chào'])->assertCreated();
        $this->getJson('/api/v1/conversations')->assertJsonPath('data.0.theme', 'blue');
        $this->putJson("/api/v1/conversations/$c/theme", ['theme' => 'neon'])->assertUnprocessable();
        $this->putJson("/api/v1/conversations/$c/theme", ['theme' => 'sunset'])->assertOk()->assertJsonPath('data.theme', 'sunset');

        $this->actingAs($b, 'sanctum')->getJson('/api/v1/conversations')->assertJsonPath('data.0.theme', 'sunset');
        $this->getJson("/api/v1/conversations/$c/messages")->assertJsonPath('meta.theme', 'sunset');
    }

    public function test_the_quick_reaction_is_shared_and_limited_to_the_list(): void
    {
        [$a, $b, $c] = $this->chat();
        $this->postJson("/api/v1/conversations/$c/messages", ['text' => 'Chào'])->assertCreated();

        $this->getJson('/api/v1/conversations')->assertJsonPath('data.0.quickReaction', '👍');
        $this->putJson("/api/v1/conversations/$c/quick-reaction", ['emoji' => ''])->assertUnprocessable();
        $this->putJson("/api/v1/conversations/$c/quick-reaction", ['emoji' => 'abc'])->assertUnprocessable();
        $this->putJson("/api/v1/conversations/$c/quick-reaction", ['emoji' => '<b>'])->assertUnprocessable();
        $this->putJson("/api/v1/conversations/$c/quick-reaction", ['emoji' => '🦄'])->assertOk()->assertJsonPath('data.quickReaction', '🦄');
        // Without the variation selector it is still the same heart.
        $this->putJson("/api/v1/conversations/$c/quick-reaction", ['emoji' => "\u{2764}"])
            ->assertOk()->assertJsonPath('data.quickReaction', '❤️');

        $this->actingAs($b, 'sanctum')->getJson('/api/v1/conversations')->assertJsonPath('data.0.quickReaction', '❤️');
        $this->getJson("/api/v1/conversations/$c/messages")->assertJsonPath('meta.quickReaction', '❤️');

        $this->actingAs(User::factory()->create(), 'sanctum')
            ->putJson("/api/v1/conversations/$c/quick-reaction", ['emoji' => '🔥'])->assertNotFound();
    }

    public function test_a_stranger_cannot_change_the_theme(): void
    {
        [, , $c] = $this->chat();
        $this->actingAs(User::factory()->create(), 'sanctum')
            ->putJson("/api/v1/conversations/$c/theme", ['theme' => 'sunset'])->assertNotFound();
    }

    public function test_media_lists_all_pictures_and_files_beyond_the_message_page(): void
    {
        Storage::fake('public');
        [$a, $b, $c] = $this->chat();
        $first = $this->postJson("/api/v1/conversations/$c/messages", [
            'attachments' => [UploadedFile::fake()->image('a.jpg'), UploadedFile::fake()->create('doc.pdf', 10, 'application/pdf')],
        ])->assertCreated()->json('data.id');
        for ($i = 0; $i < 3; $i++) {
            $this->postJson("/api/v1/conversations/$c/messages", ['text' => "chữ $i"])->assertCreated();
        }
        $this->postJson("/api/v1/conversations/$c/messages", ['attachments' => [UploadedFile::fake()->image('b.png')]])->assertCreated();

        $images = $this->getJson("/api/v1/conversations/$c/media?type=image&limit=1")->assertOk();
        $this->assertCount(1, $images->json('data'));
        $this->assertTrue($images->json('meta.hasMore'));
        $next = $this->getJson("/api/v1/conversations/$c/media?type=image&limit=1&cursor=".$images->json('meta.nextCursor'))->json();
        $this->assertSame($first, $next['data'][0]['messageId']);

        $files = $this->getJson("/api/v1/conversations/$c/media?type=file")->json('data');
        $this->assertCount(1, $files);
        $this->assertSame('doc.pdf', $files[0]['name']);

        // A recalled message leaves the lists.
        $this->deleteJson("/api/v1/conversations/$c/messages/$first")->assertOk();
        $this->assertCount(0, $this->getJson("/api/v1/conversations/$c/media?type=file")->json('data'));
        $this->assertCount(1, $this->getJson("/api/v1/conversations/$c/media?type=image")->json('data'));

        $this->actingAs(User::factory()->create(), 'sanctum')->getJson("/api/v1/conversations/$c/media?type=image")->assertNotFound();
        $this->actingAs($b, 'sanctum')->getJson("/api/v1/conversations/$c/media?type=bad")->assertUnprocessable();
    }
}
