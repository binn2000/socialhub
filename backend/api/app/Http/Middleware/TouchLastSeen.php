<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

/** Notes that the signed-in user is active, with at most one write a minute. */
class TouchLastSeen
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && (! $user->last_seen_at || $user->last_seen_at->lt(now()->subMinute()))) {
            DB::table('users')->where('id', $user->id)->update(['last_seen_at' => now()]);
            $user->setAttribute('last_seen_at', now());
            $user->syncOriginalAttribute('last_seen_at');
        }

        return $next($request);
    }
}
