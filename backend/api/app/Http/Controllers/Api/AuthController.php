<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MeResource;
use App\Mail\ResetPasswordCode;
use App\Mail\VerifyEmailCode;
use App\Models\User;
use App\Support\AuthCodes;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:50'],
            'username' => ['required', 'string', 'regex:/^[a-z0-9_]{3,30}$/', 'unique:users,username'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'max:72'],
            'deviceName' => ['nullable', 'string', 'max:60'],
        ]);

        try {
            $user = User::create([
                'name' => trim($data['name']),
                'username' => $data['username'],
                'email' => $data['email'],
                'password' => $data['password'],
            ]);
        } catch (UniqueConstraintViolationException) {
            // The unique indexes are the source of truth; the rule above can lose a race.
            throw ValidationException::withMessages([
                'username' => [__('The username or email has already been taken.')],
            ]);
        }

        $this->sendVerificationCode($user);

        return $this->authResult($user, $data['deviceName'] ?? null, 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'deviceName' => ['nullable', 'string', 'max:60'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw new HttpResponseException(response()->json([
                'message' => __('The email or password is incorrect.'),
                'code' => 'invalid_credentials',
            ], 422));
        }

        return $this->authResult($user, $data['deviceName'] ?? null, 200);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(null, 204);
    }

    public function sendEmailVerification(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->email_verified_at !== null) {
            abort(response()->json(['message' => __('The email is already verified.'), 'code' => 'already_verified'], 409));
        }

        $this->sendVerificationCode($user);

        return response()->json(null, 202);
    }

    public function verifyEmail(Request $request): array
    {
        $data = $request->validate(['code' => ['required', 'string', 'regex:/^[0-9]{6}$/']]);
        $user = $request->user();

        if ($user->email_verified_at === null) {
            if (! AuthCodes::verify($user, AuthCodes::VERIFY_EMAIL, $data['code'])) {
                $this->invalidCode();
            }

            $user->forceFill(['email_verified_at' => now()])->save();
        }

        return ['data' => (new MeResource($user))->resolve()];
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $data = $request->validate(['email' => ['required', 'email']]);
        $user = User::where('email', $data['email'])->first();

        // The same answer whether or not the account exists, so this cannot be used to look
        // up who has an account.
        if ($user) {
            Mail::to($user)->queue(new ResetPasswordCode($user->name, AuthCodes::issue($user, AuthCodes::RESET_PASSWORD)));
        }

        return response()->json(null, 202);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'code' => ['required', 'string', 'regex:/^[0-9]{6}$/'],
            'password' => ['required', 'string', 'min:8', 'max:72'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! AuthCodes::verify($user, AuthCodes::RESET_PASSWORD, $data['code'])) {
            $this->invalidCode();
        }

        $user->forceFill([
            'password' => $data['password'],
            // They just proved they can read mail sent to this address.
            'email_verified_at' => $user->email_verified_at ?? now(),
        ])->save();
        // Whoever knew the old password (or had a stolen token) is signed out everywhere.
        $user->tokens()->delete();

        return response()->json(null, 204);
    }

    private function sendVerificationCode(User $user): void
    {
        Mail::to($user)->queue(new VerifyEmailCode($user->name, AuthCodes::issue($user, AuthCodes::VERIFY_EMAIL)));
    }

    private function invalidCode(): never
    {
        throw new HttpResponseException(response()->json([
            'message' => __('The code is invalid or has expired.'),
            'code' => 'invalid_code',
            'errors' => ['code' => [__('The code is invalid or has expired.')]],
        ], 422));
    }

    private function authResult(User $user, ?string $deviceName, int $status): JsonResponse
    {
        $expiresAt = now()->addDays(30);
        $token = $user->createToken($deviceName ?: 'unknown', ['*'], $expiresAt);

        return response()->json([
            'data' => [
                'user' => (new MeResource($user))->resolve(),
                'token' => [
                    'accessToken' => $token->plainTextToken,
                    'tokenType' => 'Bearer',
                    'expiresAt' => $expiresAt->utc()->format('Y-m-d\TH:i:s\Z'),
                ],
            ],
        ], $status);
    }
}
