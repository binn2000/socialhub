<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    private array $payload = [
        'name' => 'Minh Ánh',
        'username' => 'minh_anh',
        'email' => 'minh@example.com',
        'password' => 'correct-horse-battery',
        'deviceName' => 'iPhone 17 Pro',
    ];

    public function test_register_returns_user_and_token(): void
    {
        $this->postJson('/api/v1/auth/register', $this->payload)
            ->assertCreated()
            ->assertJsonPath('data.user.username', 'minh_anh')
            ->assertJsonPath('data.user.friendsCount', 0)
            ->assertJsonPath('data.user.avatarUrl', null)
            ->assertJsonPath('data.token.tokenType', 'Bearer')
            ->assertJsonMissingPath('data.user.password');

        $this->assertDatabaseHas('users', ['email' => 'minh@example.com']);
    }

    public function test_register_rejects_duplicate_username_case_insensitively(): void
    {
        $this->postJson('/api/v1/auth/register', $this->payload)->assertCreated();

        $this->postJson('/api/v1/auth/register', [...$this->payload, 'email' => 'other@example.com', 'username' => 'minh_anh'])
            ->assertStatus(422)
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonStructure(['errors' => ['username']]);

        $this->postJson('/api/v1/auth/register', [...$this->payload, 'username' => 'x_other', 'email' => 'MINH@example.com'])
            ->assertStatus(422)
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonStructure(['errors' => ['email']]);
    }

    public function test_register_validates_username_and_password(): void
    {
        $this->postJson('/api/v1/auth/register', [...$this->payload, 'username' => 'Bad Name', 'password' => 'short'])
            ->assertStatus(422)
            ->assertJsonStructure(['message', 'code', 'errors' => ['username', 'password']]);
    }

    public function test_login_and_me(): void
    {
        $this->postJson('/api/v1/auth/register', $this->payload);

        $token = $this->postJson('/api/v1/auth/login', ['email' => 'minh@example.com', 'password' => 'correct-horse-battery'])
            ->assertOk()
            ->json('data.token.accessToken');

        $this->withToken($token)->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.email', 'minh@example.com')
            ->assertJsonPath('data.bio', null);
    }

    public function test_wrong_password_is_generic_422(): void
    {
        $this->postJson('/api/v1/auth/register', $this->payload);

        $this->postJson('/api/v1/auth/login', ['email' => 'minh@example.com', 'password' => 'wrong-password'])
            ->assertStatus(422)->assertJsonPath('code', 'invalid_credentials');
        $this->postJson('/api/v1/auth/login', ['email' => 'nobody@example.com', 'password' => 'wrong-password'])
            ->assertStatus(422)->assertJsonPath('code', 'invalid_credentials');
    }

    public function test_login_is_rate_limited(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/login', ['email' => 'a@example.com', 'password' => 'x'])->assertStatus(422);
        }

        $this->postJson('/api/v1/auth/login', ['email' => 'a@example.com', 'password' => 'x'])
            ->assertStatus(429)->assertJsonPath('code', 'too_many_requests')->assertHeader('Retry-After');
    }

    public function test_me_requires_token(): void
    {
        $this->getJson('/api/v1/me')->assertStatus(401)->assertJsonPath('code', 'unauthenticated');
    }

    public function test_logout_revokes_only_current_token(): void
    {
        $this->postJson('/api/v1/auth/register', $this->payload);
        $login = fn () => $this->postJson('/api/v1/auth/login', ['email' => 'minh@example.com', 'password' => 'correct-horse-battery'])
            ->json('data.token.accessToken');
        $first = $login();
        $second = $login();

        $this->withToken($first)->postJson('/api/v1/auth/logout')->assertNoContent();

        $this->assertDatabaseCount('personal_access_tokens', 2); // register + second login
        $this->app['auth']->forgetGuards();
        $this->withToken($second)->getJson('/api/v1/me')->assertOk();
    }

    public function test_update_me_changes_only_sent_fields(): void
    {
        $user = User::factory()->create(['name' => 'Old Name', 'username' => 'old_name', 'bio' => 'keep me']);

        $this->actingAs($user, 'sanctum')->patchJson('/api/v1/me', ['name' => '  Lê Anh Hùng '])
            ->assertOk()
            ->assertJsonPath('data.name', 'Lê Anh Hùng')
            ->assertJsonPath('data.bio', 'keep me');

        $this->actingAs($user, 'sanctum')->patchJson('/api/v1/me', ['bio' => ''])
            ->assertOk()->assertJsonPath('data.bio', null);

        $this->actingAs($user, 'sanctum')->patchJson('/api/v1/me', ['name' => ' a '])
            ->assertStatus(422)->assertJsonPath('code', 'validation_failed');
    }
}
