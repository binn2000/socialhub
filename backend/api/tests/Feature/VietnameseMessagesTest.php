<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class VietnameseMessagesTest extends TestCase
{
    use RefreshDatabase;

    public function test_validation_errors_are_in_vietnamese(): void
    {
        $this->postJson('/api/v1/auth/register', ['email' => 'nope', 'password' => 'short'])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Dữ liệu chưa hợp lệ.')
            ->assertJsonPath('errors.name.0', 'Tên là bắt buộc.')
            ->assertJsonPath('errors.email.0', 'Email phải là địa chỉ email hợp lệ.')
            ->assertJsonPath('errors.password.0', 'Mật khẩu phải có ít nhất 8 ký tự.');
    }

    public function test_a_taken_email_is_reported_in_vietnamese(): void
    {
        User::factory()->create(['email' => 'a@example.com']);

        $this->postJson('/api/v1/auth/register', [
            'name' => 'An', 'username' => 'an_user', 'email' => 'a@example.com', 'password' => 'long-enough-1',
        ])->assertStatus(422)->assertJsonPath('errors.email.0', 'Email đã được sử dụng.');
    }

    public function test_common_errors_are_in_vietnamese(): void
    {
        $this->getJson('/api/v1/me')->assertStatus(401)->assertJsonPath('message', 'Bạn cần đăng nhập.');
        $this->postJson('/api/v1/auth/login', ['email' => 'x@example.com', 'password' => 'whatever'])
            ->assertStatus(422)->assertJsonPath('message', 'Email hoặc mật khẩu không đúng.');
        $this->actingAs(User::factory()->create(), 'sanctum')
            ->getJson('/api/v1/posts/does-not-exist')->assertStatus(404)->assertJsonPath('message', 'Không tìm thấy.');
    }
}
