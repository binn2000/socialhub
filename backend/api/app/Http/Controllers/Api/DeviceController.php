<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** Push tokens of the signed-in user's phones. */
class DeviceController extends Controller
{
    /** Registers a token, or moves it to this user when the phone changed accounts. */
    public function store(Request $request): Response
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['required', Rule::in(['ios', 'android'])],
        ]);

        DB::table('device_tokens')->upsert([[
            'user_id' => $request->user()->id,
            'token_hash' => hash('sha256', $data['token']),
            'token' => $data['token'],
            'platform' => $data['platform'],
            'created_at' => now(),
            'updated_at' => now(),
        ]], ['token_hash'], ['user_id', 'token', 'platform', 'updated_at']);

        return response()->noContent();
    }

    /** Forgets a token (sign-out). Unknown tokens are not an error. */
    public function destroy(Request $request): Response
    {
        $data = $request->validate(['token' => ['required', 'string', 'max:512']]);

        DB::table('device_tokens')
            ->where('user_id', $request->user()->id)
            ->where('token_hash', hash('sha256', $data['token']))
            ->delete();

        return response()->noContent();
    }
}
