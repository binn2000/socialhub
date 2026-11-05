<?php

namespace Tests\Feature;

use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class RateLimitingTest extends TestCase
{
    use RefreshDatabase;

    private function login(string $email, string $ip)
    {
        return $this->withServerVariables(['REMOTE_ADDR' => $ip])
            ->postJson('/api/v1/auth/login', ['email' => $email, 'password' => 'wrong-password']);
    }

    public function test_login_is_limited_per_email_even_when_the_ip_changes(): void
    {
        foreach (range(1, 30) as $i) {
            $this->login('victim@example.com', "10.0.0.$i")->assertStatus(422);
        }

        $this->login('victim@example.com', '10.0.1.1')->assertStatus(429)->assertJsonPath('code', 'too_many_requests');
        $this->login('someone-else@example.com', '10.0.1.2')->assertStatus(422);
    }

    public function test_login_is_limited_per_ip_even_when_the_email_changes(): void
    {
        foreach (range(1, 20) as $i) {
            $this->login("user$i@example.com", '10.9.9.9')->assertStatus(422);
        }

        $this->login('user21@example.com', '10.9.9.9')->assertStatus(429)->assertHeader('Retry-After');
        $this->login('user21@example.com', '10.9.9.10')->assertStatus(422);
    }

    public function test_reactions_are_limited_per_user(): void
    {
        $author = User::factory()->create();
        $post = Post::forceCreate([
            'id' => (string) Str::ulid(), 'user_id' => $author->id, 'content' => 'hello',
            'privacy' => 'public', 'created_at' => now(), 'updated_at' => now(),
        ]);
        $this->actingAs(User::factory()->create(), 'sanctum');

        foreach (range(1, 90) as $i) {
            $this->putJson("/api/v1/posts/{$post->id}/like")->assertOk();
        }

        $this->putJson("/api/v1/posts/{$post->id}/like")->assertStatus(429);
    }

    public function test_user_search_is_limited_per_user(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');

        foreach (range(1, 60) as $i) {
            $this->getJson('/api/v1/users?q=an')->assertOk();
        }

        $this->getJson('/api/v1/users?q=an')->assertStatus(429);
    }
}
