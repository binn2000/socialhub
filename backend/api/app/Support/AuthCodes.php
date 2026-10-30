<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * The 6-digit codes behind email verification and password reset. Only a keyed hash of
 * a code is stored; the plain code exists in the email alone.
 */
class AuthCodes
{
    public const VERIFY_EMAIL = 'verify_email';

    public const RESET_PASSWORD = 'reset_password';

    private const LIFETIME_MINUTES = 15;

    private const MAX_ATTEMPTS = 5;

    /**
     * Creates a new code for the user, replacing any earlier one (so the old code stops
     * working and the failed-attempt count starts again).
     */
    public static function issue(User $user, string $purpose): string
    {
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        DB::table('auth_codes')->upsert(
            [[
                'user_id' => $user->id,
                'purpose' => $purpose,
                'code_hash' => self::hash($code),
                'attempts' => 0,
                'expires_at' => now()->addMinutes(self::LIFETIME_MINUTES),
                'created_at' => now(),
            ]],
            ['user_id', 'purpose'],
            ['code_hash', 'attempts', 'expires_at', 'created_at'],
        );

        return $code;
    }

    /**
     * Checks a code and uses it up when it is right. A wrong guess counts against the
     * code; after MAX_ATTEMPTS it is thrown away.
     */
    public static function verify(User $user, string $purpose, string $code): bool
    {
        $row = DB::table('auth_codes')->where(['user_id' => $user->id, 'purpose' => $purpose])->first();

        if (! $row) {
            return false;
        }
        if (now()->greaterThan($row->expires_at)) {
            self::forget($user, $purpose);

            return false;
        }
        if (! hash_equals($row->code_hash, self::hash($code))) {
            if ($row->attempts + 1 >= self::MAX_ATTEMPTS) {
                self::forget($user, $purpose);
            } else {
                DB::table('auth_codes')->where('id', $row->id)->increment('attempts');
            }

            return false;
        }

        self::forget($user, $purpose);

        return true;
    }

    public static function forget(User $user, string $purpose): void
    {
        DB::table('auth_codes')->where(['user_id' => $user->id, 'purpose' => $purpose])->delete();
    }

    private static function hash(string $code): string
    {
        return hash_hmac('sha256', $code, (string) config('app.key'));
    }
}
