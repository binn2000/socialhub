<?php

namespace Tests\Feature;

use App\Jobs\DeleteStoredImage;
use App\Mail\ResetPasswordCode;
use App\Mail\VerifyEmailCode;
use App\Models\Friendship;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Tests\TestCase;

class AccountSecurityTest extends TestCase
{
    use RefreshDatabase;

    private array $registration = [
        'name' => 'Minh Ánh',
        'username' => 'minh_anh',
        'email' => 'minh@example.com',
        'password' => 'correct-horse-battery',
    ];

    private function unverifiedUser(): User
    {
        return User::factory()->unverified()->create(['email' => 'user@example.com', 'password' => 'old-password-1']);
    }

    /** The code of the most recent mail of this kind, the way the person would read it. */
    private function sentCode(string $mailable): string
    {
        $code = null;
        Mail::assertQueued($mailable, function ($mail) use (&$code) {
            $code = $mail->code;

            return true;
        });

        return $code;
    }

    private function wrongCode(string $right): string
    {
        return $right === '000000' ? '111111' : '000000';
    }

    // ---- email verification

    public function test_registering_sends_a_code_and_starts_unverified(): void
    {
        Mail::fake();

        $this->postJson('/api/v1/auth/register', $this->registration)
            ->assertCreated()->assertJsonPath('data.user.emailVerified', false);

        Mail::assertQueued(VerifyEmailCode::class, fn (VerifyEmailCode $mail) => $mail->hasTo('minh@example.com'));
    }

    public function test_the_verification_mail_shows_the_code(): void
    {
        $mail = new VerifyEmailCode('Minh', '123456');

        $mail->assertSeeInText('123456');
        $mail->assertSeeInText('15 phút');
    }

    public function test_the_right_code_verifies_the_email(): void
    {
        Mail::fake();
        $user = $this->unverifiedUser();
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/auth/email/verification')->assertStatus(202);
        $code = $this->sentCode(VerifyEmailCode::class);

        $this->postJson('/api/v1/auth/email/verify', ['code' => $this->wrongCode($code)])
            ->assertStatus(422)->assertJsonPath('code', 'invalid_code')->assertJsonStructure(['errors' => ['code']]);
        $this->assertNull($user->fresh()->email_verified_at);

        $this->postJson('/api/v1/auth/email/verify', ['code' => $code])
            ->assertOk()->assertJsonPath('data.emailVerified', true);
        $this->assertNotNull($user->fresh()->email_verified_at);

        // already verified: asking for a code is refused, confirming again is harmless
        $this->postJson('/api/v1/auth/email/verification')->assertStatus(409)->assertJsonPath('code', 'already_verified');
        $this->postJson('/api/v1/auth/email/verify', ['code' => '999999'])->assertOk();
    }

    public function test_a_code_is_single_use_and_a_new_one_replaces_the_old(): void
    {
        Mail::fake();
        $user = $this->unverifiedUser();
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/auth/email/verification');
        $first = $this->sentCode(VerifyEmailCode::class);
        $this->postJson('/api/v1/auth/email/verification');
        $second = null;
        Mail::assertQueued(VerifyEmailCode::class, function ($mail) use (&$second, $first) {
            $second = $mail->code;

            return true;
        });

        if ($first !== $second) {
            $this->postJson('/api/v1/auth/email/verify', ['code' => $first])->assertStatus(422);
        }
        $this->assertSame(1, DB::table('auth_codes')->where('user_id', $user->id)->count());
    }

    public function test_five_wrong_tries_discard_the_code(): void
    {
        Mail::fake();
        $user = $this->unverifiedUser();
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/auth/email/verification');
        $code = $this->sentCode(VerifyEmailCode::class);

        foreach (range(1, 5) as $i) {
            $this->postJson('/api/v1/auth/email/verify', ['code' => $this->wrongCode($code)])->assertStatus(422);
        }

        $this->postJson('/api/v1/auth/email/verify', ['code' => $code])->assertStatus(422);
        $this->assertSame(0, DB::table('auth_codes')->count());
    }

    public function test_an_expired_code_is_refused(): void
    {
        Mail::fake();
        $user = $this->unverifiedUser();
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/auth/email/verification');
        $code = $this->sentCode(VerifyEmailCode::class);

        $this->travel(16)->minutes();

        $this->postJson('/api/v1/auth/email/verify', ['code' => $code])->assertStatus(422)->assertJsonPath('code', 'invalid_code');
    }

    public function test_the_code_format_and_authentication_are_checked(): void
    {
        $this->postJson('/api/v1/auth/email/verify', ['code' => '123456'])->assertStatus(401);
        $this->postJson('/api/v1/auth/email/verification')->assertStatus(401);

        $this->actingAs($this->unverifiedUser(), 'sanctum');
        $this->postJson('/api/v1/auth/email/verify', ['code' => '12ab'])->assertStatus(422)->assertJsonPath('code', 'validation_failed');
        $this->postJson('/api/v1/auth/email/verify', [])->assertStatus(422);
    }

    public function test_asking_for_codes_is_rate_limited(): void
    {
        Mail::fake();
        $this->actingAs($this->unverifiedUser(), 'sanctum');

        foreach (range(1, 5) as $i) {
            $this->postJson('/api/v1/auth/email/verification')->assertStatus(202);
        }

        $this->postJson('/api/v1/auth/email/verification')->assertStatus(429)->assertHeader('Retry-After');
    }

    // ---- forgot / reset password

    public function test_forgot_password_answers_the_same_for_unknown_emails(): void
    {
        Mail::fake();
        $this->unverifiedUser();

        $known = $this->postJson('/api/v1/auth/password/forgot', ['email' => 'user@example.com']);
        $unknown = $this->postJson('/api/v1/auth/password/forgot', ['email' => 'nobody@example.com']);

        $known->assertStatus(202);
        $unknown->assertStatus(202);
        $this->assertSame($known->getContent(), $unknown->getContent());
        Mail::assertQueued(ResetPasswordCode::class, 1);
        Mail::assertQueued(ResetPasswordCode::class, fn (ResetPasswordCode $mail) => $mail->hasTo('user@example.com'));
    }

    public function test_forgot_password_validates_the_email_and_is_rate_limited(): void
    {
        Mail::fake();
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'not-an-email'])->assertStatus(422);

        foreach (range(1, 5) as $i) {
            $this->postJson('/api/v1/auth/password/forgot', ['email' => 'user@example.com'])->assertStatus(202);
        }
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'user@example.com'])->assertStatus(429);
    }

    public function test_the_code_resets_the_password_and_signs_everyone_out(): void
    {
        Mail::fake();
        $user = $this->unverifiedUser();
        $oldToken = $user->createToken('phone')->plainTextToken;
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'user@example.com']);
        $code = $this->sentCode(ResetPasswordCode::class);

        $this->postJson('/api/v1/auth/password/reset', ['email' => 'user@example.com', 'code' => $code, 'password' => 'brand-new-pass-9'])
            ->assertNoContent();

        $this->postJson('/api/v1/auth/login', ['email' => 'user@example.com', 'password' => 'old-password-1'])->assertStatus(422);
        $this->postJson('/api/v1/auth/login', ['email' => 'user@example.com', 'password' => 'brand-new-pass-9'])->assertOk();
        $this->assertNotNull($user->fresh()->email_verified_at); // reading the mail proved the address
        $this->assertTrue(Hash::check('brand-new-pass-9', $user->fresh()->password));

        $this->app['auth']->forgetGuards();
        $this->withToken($oldToken)->getJson('/api/v1/me')->assertStatus(401);

        // the code worked once
        $this->postJson('/api/v1/auth/password/reset', ['email' => 'user@example.com', 'code' => $code, 'password' => 'another-pass-123'])
            ->assertStatus(422)->assertJsonPath('code', 'invalid_code');
    }

    public function test_a_wrong_code_or_email_is_one_generic_error(): void
    {
        Mail::fake();
        $this->unverifiedUser();
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'user@example.com']);
        $code = $this->sentCode(ResetPasswordCode::class);
        $body = fn (string $email, string $c) => ['email' => $email, 'code' => $c, 'password' => 'brand-new-pass-9'];

        $wrongCode = $this->postJson('/api/v1/auth/password/reset', $body('user@example.com', $this->wrongCode($code)));
        $unknown = $this->postJson('/api/v1/auth/password/reset', $body('nobody@example.com', $code));

        $wrongCode->assertStatus(422)->assertJsonPath('code', 'invalid_code');
        $this->assertSame($wrongCode->getContent(), $unknown->getContent());
        $this->postJson('/api/v1/auth/login', ['email' => 'user@example.com', 'password' => 'old-password-1'])->assertOk();
    }

    public function test_the_new_password_follows_the_register_rules(): void
    {
        Mail::fake();
        $this->unverifiedUser();
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'user@example.com']);
        $code = $this->sentCode(ResetPasswordCode::class);

        $this->postJson('/api/v1/auth/password/reset', ['email' => 'user@example.com', 'code' => $code, 'password' => 'short'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['password']]);
        // a rejected password does not use up the code
        $this->postJson('/api/v1/auth/password/reset', ['email' => 'user@example.com', 'code' => $code, 'password' => 'long-enough-pass'])->assertNoContent();
    }

    public function test_five_wrong_reset_codes_discard_it(): void
    {
        Mail::fake();
        $this->unverifiedUser();
        $this->postJson('/api/v1/auth/password/forgot', ['email' => 'user@example.com']);
        $code = $this->sentCode(ResetPasswordCode::class);

        foreach (range(1, 5) as $i) {
            $this->postJson('/api/v1/auth/password/reset', ['email' => 'user@example.com', 'code' => $this->wrongCode($code), 'password' => 'long-enough-pass'])
                ->assertStatus(422);
        }

        $this->postJson('/api/v1/auth/password/reset', ['email' => 'user@example.com', 'code' => $code, 'password' => 'long-enough-pass'])->assertStatus(422);
    }

    // ---- delete account

    private function makePost(User $author, string $content = 'hello'): Post
    {
        return Post::forceCreate([
            'id' => (string) Str::ulid(), 'user_id' => $author->id, 'content' => $content,
            'privacy' => 'public', 'created_at' => now(), 'updated_at' => now(),
        ]);
    }

    public function test_deleting_needs_the_current_password(): void
    {
        $user = $this->unverifiedUser();
        $this->actingAs($user, 'sanctum');

        $this->deleteJson('/api/v1/me', ['password' => 'wrong-password'])
            ->assertStatus(422)->assertJsonPath('code', 'invalid_credentials')->assertJsonStructure(['errors' => ['password']]);
        $this->deleteJson('/api/v1/me', [])->assertStatus(422);
        $this->assertNull($user->fresh()->deleted_at);
    }

    public function test_a_deleted_account_vanishes_for_everyone_else(): void
    {
        [$leaver, $friend] = [$this->unverifiedUser(), User::factory()->create()];
        Friendship::create(['requester_id' => $leaver->id, 'addressee_id' => $friend->id, 'status' => 'accepted']);
        $post = $this->makePost($leaver, 'leaving soon');
        $token = $leaver->createToken('phone')->plainTextToken;

        $this->actingAs($friend, 'sanctum');
        $this->assertCount(1, $this->getJson('/api/v1/feed')->json('data'));
        $this->assertSame(1, $this->getJson("/api/v1/users/{$friend->id}")->json('data.friendsCount'));
        $this->assertSame(1, $this->actingAs($leaver, 'sanctum')->getJson('/api/v1/explore')->json('data.0') ? 1 : 0);

        $this->actingAs($leaver, 'sanctum')->deleteJson('/api/v1/me', ['password' => 'old-password-1'])->assertNoContent();

        $this->assertSoftDeleted('users', ['id' => $leaver->id]);
        $this->actingAs($friend, 'sanctum');
        $this->assertCount(0, $this->getJson('/api/v1/feed')->json('data'));
        $this->assertCount(0, $this->getJson('/api/v1/explore')->json('data'));
        $this->getJson("/api/v1/posts/{$post->id}")->assertNotFound();
        $this->getJson("/api/v1/users/{$leaver->id}")->assertNotFound();
        $this->assertSame(0, $this->getJson("/api/v1/users/{$friend->id}")->json('data.friendsCount'));
        $this->assertCount(0, $this->getJson('/api/v1/users?q=')->json('data'));
        $this->assertSame(0, DB::table('friendships')->count());

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/me')->assertStatus(401);
        $this->postJson('/api/v1/auth/login', ['email' => 'user@example.com', 'password' => 'old-password-1'])->assertStatus(422);
    }

    public function test_the_email_and_username_stay_reserved(): void
    {
        $user = User::factory()->create(['email' => 'taken@example.com', 'username' => 'taken_name', 'password' => 'old-password-1']);
        $this->actingAs($user, 'sanctum')->deleteJson('/api/v1/me', ['password' => 'old-password-1'])->assertNoContent();

        $this->postJson('/api/v1/auth/register', [...$this->registration, 'email' => 'taken@example.com'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['email']]);
        $this->postJson('/api/v1/auth/register', [...$this->registration, 'username' => 'taken_name'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['username']]);
    }

    public function test_a_chat_with_a_deleted_account_is_not_listed(): void
    {
        [$me, $leaver] = [User::factory()->create(), $this->unverifiedUser()];
        Friendship::create(['requester_id' => $me->id, 'addressee_id' => $leaver->id, 'status' => 'accepted']);
        $conversation = $this->actingAs($me, 'sanctum')->postJson('/api/v1/conversations', ['userId' => $leaver->id])->json('data.id');
        $this->postJson("/api/v1/conversations/$conversation/messages", ['text' => 'hi'])->assertCreated();
        $this->assertCount(1, $this->getJson('/api/v1/conversations')->json('data'));

        $this->actingAs($leaver, 'sanctum')->deleteJson('/api/v1/me', ['password' => 'old-password-1'])->assertNoContent();

        $this->actingAs($me, 'sanctum')->getJson('/api/v1/conversations')->assertOk()->assertJsonCount(0, 'data');
        $this->postJson("/api/v1/conversations/$conversation/messages", ['text' => 'anyone?'])->assertForbidden();
    }

    public function test_the_purge_removes_old_deleted_accounts_for_good(): void
    {
        Queue::fake();
        [$old, $recent, $other] = User::factory()->count(3)->create();
        $this->makePost($old, 'old post');
        $kept = $this->makePost($other, 'kept');
        $keptLiked = $this->makePost($other, 'liked by the leaver');
        DB::table('post_likes')->insert(['post_id' => $keptLiked->id, 'user_id' => $old->id, 'created_at' => now()]);
        DB::table('post_likes')->insert(['post_id' => $keptLiked->id, 'user_id' => $recent->id, 'created_at' => now()]);
        $keptLiked->update(['likes_count' => 2]);
        $old->forceFill(['avatar_path' => 'avatars/2026/10/old.png', 'deleted_at' => now()->subDays(31)])->save();
        $recent->forceFill(['deleted_at' => now()->subDays(10)])->save();

        $this->artisan('accounts:purge-deleted')->assertSuccessful();

        $this->assertDatabaseMissing('users', ['id' => $old->id]);
        $this->assertDatabaseHas('users', ['id' => $recent->id]); // still inside the retention period
        $this->assertSame(0, Post::withTrashed()->where('user_id', $old->id)->count());
        $this->assertSame(1, $keptLiked->fresh()->likes_count);   // recounted without the leaver's like
        $this->assertNotNull($kept->fresh());
        Queue::assertPushed(DeleteStoredImage::class, fn (DeleteStoredImage $job) => $job->path === 'avatars/2026/10/old.png');
    }

    public function test_the_retention_period_can_be_chosen(): void
    {
        $user = User::factory()->create();
        $user->forceFill(['deleted_at' => now()->subDays(3)])->save();

        $this->artisan('accounts:purge-deleted --days=2')->assertSuccessful();

        $this->assertDatabaseMissing('users', ['id' => $user->id]);
    }
}
