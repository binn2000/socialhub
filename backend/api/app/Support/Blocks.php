<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;

/** Blocking hides two people from each other, whichever of them blocked. */
class Blocks
{
    /** Leaves out rows whose $column (a user id) is blocked by, or has blocked, $viewerId. */
    public static function exclude($query, string $viewerId, string $column): void
    {
        $query->whereNotExists(fn ($b) => $b->selectRaw('1')->from('user_blocks')
            ->where(fn ($w) => $w
                ->where(fn ($x) => $x->where('blocker_id', $viewerId)->whereColumn('blocked_id', $column))
                ->orWhere(fn ($x) => $x->where('blocked_id', $viewerId)->whereColumn('blocker_id', $column))));
    }

    public static function either(string $a, string $b): bool
    {
        return DB::table('user_blocks')
            ->where(fn ($w) => $w->where('blocker_id', $a)->where('blocked_id', $b))
            ->orWhere(fn ($w) => $w->where('blocker_id', $b)->where('blocked_id', $a))
            ->exists();
    }

    public static function followedBy(string $followerId, string $followeeId): bool
    {
        return DB::table('follows')->where('follower_id', $followerId)->where('followee_id', $followeeId)->exists();
    }

    public static function blockedBy(string $blockerId, string $blockedId): bool
    {
        return DB::table('user_blocks')->where('blocker_id', $blockerId)->where('blocked_id', $blockedId)->exists();
    }
}
