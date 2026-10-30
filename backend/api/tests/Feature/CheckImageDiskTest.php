<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CheckImageDiskTest extends TestCase
{
    public function test_a_working_disk_passes_and_leaves_nothing_behind(): void
    {
        Storage::fake('public');
        Http::fake(fn () => Http::response(Storage::disk('public')->get(Storage::disk('public')->allFiles()[0])));

        $this->artisan('images:check-disk')->assertSuccessful();

        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_an_unreadable_url_fails(): void
    {
        Storage::fake('public');
        Http::fake(['*' => Http::response('Access Denied', 403)]);

        $this->artisan('images:check-disk')->assertFailed();
    }

    public function test_the_url_check_can_be_skipped(): void
    {
        Storage::fake('public');

        $this->artisan('images:check-disk --skip-url')->assertSuccessful();
    }
}
