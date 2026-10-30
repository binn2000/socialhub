<?php

namespace Tests\Feature;

use App\Jobs\SendPush;
use App\Models\Friendship;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ChatAttachmentsTest extends TestCase
{
    use RefreshDatabase;

    private array $json = ['Accept' => 'application/json'];

    private User $me;

    private User $friend;

    private string $conversation;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        [$this->me, $this->friend] = User::factory()->count(2)->create();
        Friendship::create(['requester_id' => $this->me->id, 'addressee_id' => $this->friend->id, 'status' => 'accepted']);
        $this->conversation = $this->actingAs($this->me, 'sanctum')
            ->postJson('/api/v1/conversations', ['userId' => $this->friend->id])->json('data.id');
    }

    private function send(array $body)
    {
        return $this->post("/api/v1/conversations/{$this->conversation}/messages", $body, $this->json);
    }

    public function test_an_image_and_a_document_are_sent_with_text(): void
    {
        $response = $this->send([
            'text' => 'Xem giúp mình',
            'attachments' => [
                UploadedFile::fake()->image('anh.png', 80, 60),
                UploadedFile::fake()->create('hop-dong.pdf', 120, 'application/pdf'),
            ],
        ])->assertCreated();

        $response->assertJsonPath('data.text', 'Xem giúp mình');
        [$image, $file] = $response->json('data.attachments');
        $this->assertSame('image', $image['type']);
        $this->assertSame(80, $image['width']);
        $this->assertSame(60, $image['height']);
        $this->assertSame('image/png', $image['mimeType']);
        $this->assertSame('anh.png', $image['name']);
        $this->assertStringContainsString('/chat/', $image['url']);
        $this->assertGreaterThan(0, $image['sizeBytes']);
        $this->assertSame('file', $file['type']);
        $this->assertSame('hop-dong.pdf', $file['name']);
        $this->assertSame('application/pdf', $file['mimeType']);
        $this->assertNull($file['width']);
        $this->assertCount(2, Storage::disk('public')->allFiles());
        $this->assertStringEndsWith('.pdf', $file['url']);
    }

    public function test_a_message_can_be_only_attachments_and_text_only_still_works(): void
    {
        $only = $this->send(['attachments' => [UploadedFile::fake()->image('a.jpg', 20, 20)]])->assertCreated();
        $this->assertSame('', $only->json('data.text'));

        $plain = $this->postJson("/api/v1/conversations/{$this->conversation}/messages", ['text' => 'chào'])->assertCreated();
        $this->assertSame([], $plain->json('data.attachments'));
    }

    public function test_they_come_back_in_history_polling_and_the_conversation_list(): void
    {
        $first = $this->send(['text' => 'một'])->json('data.id');
        $second = $this->send(['attachments' => [UploadedFile::fake()->create('b.docx', 5)]])->json('data.id');

        $history = $this->getJson("/api/v1/conversations/{$this->conversation}/messages")->assertOk();
        $this->assertSame('b.docx', $history->json('data.0.attachments.0.name'));
        $this->assertSame([], $history->json('data.1.attachments'));

        $poll = $this->getJson("/api/v1/conversations/{$this->conversation}/messages?after=$first")->assertOk();
        $this->assertSame($second, $poll->json('data.0.id'));
        $this->assertSame('b.docx', $poll->json('data.0.attachments.0.name'));

        $list = $this->getJson('/api/v1/conversations')->assertOk();
        $this->assertSame('b.docx', $list->json('data.0.lastMessage.attachments.0.name'));
    }

    public function test_the_rules_are_checked(): void
    {
        $this->send(['text' => '  '])->assertStatus(422)->assertJsonStructure(['errors' => ['text']]);
        $this->send([])->assertStatus(422);
        $this->send(['attachments' => array_map(fn ($i) => UploadedFile::fake()->create("f$i.pdf", 5, 'application/pdf'), range(1, 6))])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['attachments']]);
        $this->send(['attachments' => [UploadedFile::fake()->create('virus.exe', 5, 'application/x-msdownload')]])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['attachments.0']]);
        $this->send(['attachments' => [UploadedFile::fake()->create('script.php', 5, 'text/x-php')]])->assertStatus(422);
        $this->send(['attachments' => [UploadedFile::fake()->create('big.pdf', 11 * 1024, 'application/pdf')]])->assertStatus(422);
        $this->send(['attachments' => [UploadedFile::fake()->createWithContent('fake.jpg', 'not an image')]])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['attachments.0']]);

        $this->assertSame([], Storage::disk('public')->allFiles());
        $this->assertSame(0, DB::table('messages')->count());
    }

    public function test_a_failed_second_file_leaves_nothing_behind(): void
    {
        $this->send(['attachments' => [
            UploadedFile::fake()->image('ok.jpg', 20, 20),
            UploadedFile::fake()->createWithContent('bad.png', 'broken'),
        ]])->assertStatus(422);

        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_the_file_name_is_cleaned_and_the_stored_name_is_random(): void
    {
        $response = $this->send(['attachments' => [UploadedFile::fake()->create("../../etc/pass\x01wd.txt", 1, 'text/plain')]])->assertCreated();

        $name = $response->json('data.attachments.0.name');
        $this->assertStringNotContainsString('/', $name);
        $this->assertStringNotContainsString("\x01", $name);
        $this->assertStringEndsWith('.txt', $name);
        $stored = Storage::disk('public')->allFiles()[0];
        $this->assertStringStartsWith('chat/', $stored);
        $this->assertStringNotContainsString('pass', $stored);
    }

    public function test_only_friends_in_the_conversation_can_send_files(): void
    {
        Friendship::query()->delete();

        $this->send(['attachments' => [UploadedFile::fake()->create('a.pdf', 5, 'application/pdf')]])->assertForbidden();
        $this->assertSame([], Storage::disk('public')->allFiles());

        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->send(['text' => 'hi'])->assertNotFound();
    }

    public function test_the_push_says_what_was_sent(): void
    {
        Queue::fake();

        $this->send(['attachments' => [UploadedFile::fake()->image('a.jpg', 20, 20)]])->assertCreated();
        $this->send(['attachments' => [UploadedFile::fake()->create('a.pdf', 5, 'application/pdf')]])->assertCreated();
        $this->send(['text' => 'chào', 'attachments' => [UploadedFile::fake()->create('a.pdf', 5, 'application/pdf')]])->assertCreated();

        $bodies = [];
        Queue::assertPushed(SendPush::class, function ($job) use (&$bodies) {
            $bodies[] = $job->body;

            return true;
        });
        $this->assertSame(['Đã gửi ảnh', 'Đã gửi tệp đính kèm', 'chào'], $bodies);
    }

    public function test_purging_an_account_removes_its_attachment_files(): void
    {
        $this->send(['attachments' => [UploadedFile::fake()->image('a.jpg', 20, 20), UploadedFile::fake()->create('a.pdf', 5, 'application/pdf')]])->assertCreated();
        $this->assertCount(2, Storage::disk('public')->allFiles());
        $this->me->forceFill(['deleted_at' => now()->subDays(31)])->save();

        $this->artisan('accounts:purge-deleted')->assertSuccessful();

        $this->assertSame([], Storage::disk('public')->allFiles());
        $this->assertSame(0, DB::table('message_attachments')->count());
    }
}
