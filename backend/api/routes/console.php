<?php

use App\Models\Note;
use App\Models\Story;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Expired stories are already hidden by every query; this frees the rows (and their views).
Artisan::command('stories:purge-expired', function () {
    $deleted = Story::where('expires_at', '<=', now())->get()->each->delete()->count();
    $this->info("Deleted {$deleted} expired stories.");
})->purpose('Delete stories older than 24 hours');

Schedule::command('stories:purge-expired')->hourly();

Artisan::command('idempotency:purge', function () {
    $deleted = DB::table('idempotency_keys')->where('created_at', '<', now()->subHours(24))->delete();
    $this->info("Deleted {$deleted} idempotency keys.");
})->purpose('Delete idempotency keys older than 24 hours');

Schedule::command('idempotency:purge')->hourly();

// Expired notes are already hidden by every query; this frees the rows.
Artisan::command('notes:purge-expired', function () {
    $deleted = Note::where('expires_at', '<=', now())->delete();
    $this->info("Deleted {$deleted} expired notes.");
})->purpose('Delete notes older than 24 hours');

Schedule::command('notes:purge-expired')->hourly();

// Housekeeping: expired API tokens and old failed queue jobs.
Schedule::command('sanctum:prune-expired --hours=24')->daily();
Schedule::command('queue:prune-failed --hours=168')->daily();

// Accounts deleted more than 30 days ago are removed for good.
Schedule::command('accounts:purge-deleted')->daily();
