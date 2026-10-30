<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use RuntimeException;
use Tests\TestCase;

class ErrorShapeTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_production_500_hides_the_exception(): void
    {
        config(['app.debug' => false]);
        Route::get('/api/v1/boom', fn () => throw new RuntimeException('SQLSTATE secret /var/www/path'));

        $response = $this->actingAs(User::factory()->create(), 'sanctum')->getJson('/api/v1/boom');

        $response->assertStatus(500)->assertExactJson(['message' => 'Máy chủ gặp lỗi, hãy thử lại sau.', 'code' => 'server_error']);
        $this->assertStringNotContainsString('secret', $response->getContent());
    }

    public function test_development_keeps_the_detailed_error(): void
    {
        config(['app.debug' => true]);
        Route::get('/api/v1/boom', fn () => throw new RuntimeException('visible while debugging'));

        $this->actingAs(User::factory()->create(), 'sanctum')->getJson('/api/v1/boom')
            ->assertStatus(500)->assertJsonPath('message', 'visible while debugging');
    }

    public function test_a_wrong_method_is_a_405_with_a_code(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum')->postJson('/api/v1/feed')
            ->assertStatus(405)->assertJsonPath('code', 'method_not_allowed')->assertHeader('Allow');
    }

    public function test_known_errors_keep_their_own_shape_when_not_debugging(): void
    {
        config(['app.debug' => false]);
        $me = User::factory()->create();

        $this->actingAs($me, 'sanctum')->getJson('/api/v1/posts/missing')->assertStatus(404)->assertJsonPath('code', 'not_found');
        $this->actingAs($me, 'sanctum')->getJson('/api/v1/nope')->assertStatus(404)->assertJsonPath('code', 'not_found');
        $this->postJson('/api/v1/auth/login', [])->assertStatus(422)->assertJsonPath('code', 'validation_failed');
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/me')->assertStatus(401)->assertJsonPath('code', 'unauthenticated');
    }
}
