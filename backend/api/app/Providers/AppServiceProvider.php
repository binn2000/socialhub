<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // MariaDB 10.1 limits index keys to 767 bytes unless the table uses ROW_FORMAT=DYNAMIC.
        Schema::defaultStringLength(191);

        // The email+IP key stops one client guessing a password; the two other limits stop guessing one account
        // from many IPs and one IP trying many accounts.
        RateLimiter::for('login', fn (Request $r) => [
            Limit::perMinute(5)->by('pair|'.strtolower((string) $r->input('email')).'|'.$r->ip()),
            Limit::perHour(30)->by('email|'.strtolower((string) $r->input('email'))),
            Limit::perMinute(20)->by('ip|'.$r->ip()),
        ]);
        RateLimiter::for('email-code', fn (Request $r) => Limit::perHour(5)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('email-verify', fn (Request $r) => Limit::perHour(10)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('password-forgot', fn (Request $r) => Limit::perHour(5)
            ->by(strtolower((string) $r->input('email')).'|'.$r->ip()));
        RateLimiter::for('password-reset', fn (Request $r) => Limit::perHour(10)
            ->by(strtolower((string) $r->input('email')).'|'.$r->ip()));
        RateLimiter::for('register', fn (Request $r) => Limit::perHour(10)->by($r->ip()));
        RateLimiter::for('posts', fn (Request $r) => Limit::perHour(30)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('friend-requests', fn (Request $r) => Limit::perHour(60)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('comments', fn (Request $r) => Limit::perHour(120)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('messages', fn (Request $r) => Limit::perMinute(120)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('stories', fn (Request $r) => Limit::perHour(30)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('reports', fn (Request $r) => Limit::perHour(20)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('music', fn (Request $r) => Limit::perMinute(30)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('notes', fn (Request $r) => Limit::perHour(30)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('uploads', fn (Request $r) => Limit::perHour(30)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('reactions', fn (Request $r) => Limit::perMinute(90)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('search', fn (Request $r) => Limit::perMinute(60)->by($r->user()?->id ?: $r->ip()));
        RateLimiter::for('api', fn (Request $r) => Limit::perMinute(120)->by($r->user()?->id ?: $r->ip()));
    }
}
