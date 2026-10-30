<?php

namespace App\Support;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Sends push notifications through Firebase Cloud Messaging (HTTP v1), which
 * delivers to both Android and iOS. Does nothing until FCM_PROJECT_ID and
 * FCM_CREDENTIALS (the service account JSON file) are set.
 */
class PushSender
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public static function enabled(): bool
    {
        return config('services.fcm.project_id') && is_file((string) config('services.fcm.credentials'));
    }

    /**
     * @param  array<string, scalar|null>  $data  delivered with the push (all values become strings)
     */
    public static function sendToUser(string $userId, string $title, string $body, array $data = []): void
    {
        if (! self::enabled()) {
            return;
        }

        $tokens = DB::table('device_tokens')->where('user_id', $userId)->get(['token_hash', 'token', 'platform']);
        if ($tokens->isEmpty()) {
            return;
        }

        $accessToken = self::accessToken();
        if ($accessToken === null) {
            return;
        }

        $data = array_map(fn ($v) => (string) $v, array_filter($data, fn ($v) => $v !== null));

        foreach ($tokens as $device) {
            $response = Http::withToken($accessToken)->timeout(10)->post(
                'https://fcm.googleapis.com/v1/projects/'.config('services.fcm.project_id').'/messages:send',
                ['message' => [
                    'token' => $device->token,
                    'notification' => ['title' => $title, 'body' => $body],
                    'data' => (object) $data,
                    'android' => ['priority' => 'HIGH', 'notification' => ['sound' => 'default']],
                    'apns' => ['payload' => ['aps' => ['sound' => 'default']]],
                ]],
            );

            if ($response->successful()) {
                continue;
            }
            // A token that is gone (app removed, token refreshed) will never work again.
            $status = $response->json('error.status');
            if (in_array($status, ['NOT_FOUND', 'UNREGISTERED', 'INVALID_ARGUMENT'], true)) {
                DB::table('device_tokens')->where('token_hash', $device->token_hash)->delete();
            } else {
                Log::warning('Push not sent', ['status' => $response->status(), 'error' => $response->json('error.message')]);
            }
        }
    }

    /** An OAuth token for the service account, kept for 50 minutes (they last an hour). */
    private static function accessToken(): ?string
    {
        return Cache::remember('fcm_access_token', now()->addMinutes(50), function () {
            $credentials = json_decode((string) file_get_contents(config('services.fcm.credentials')), true);
            if (! is_array($credentials) || ! isset($credentials['client_email'], $credentials['private_key'])) {
                Log::error('FCM credentials file is not a service account key');

                return null;
            }

            $now = time();
            $b64 = fn (string $s) => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
            $unsigned = $b64(json_encode(['alg' => 'RS256', 'typ' => 'JWT'])).'.'.$b64(json_encode([
                'iss' => $credentials['client_email'],
                'scope' => self::SCOPE,
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ]));
            openssl_sign($unsigned, $signature, $credentials['private_key'], OPENSSL_ALGO_SHA256);

            $response = Http::asForm()->timeout(10)->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $unsigned.'.'.$b64($signature),
            ]);

            return $response->successful() ? $response->json('access_token') : null;
        });
    }
}
