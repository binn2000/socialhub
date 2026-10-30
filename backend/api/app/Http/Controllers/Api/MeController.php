<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MeResource;
use App\Support\ImageStore;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Http\Request;

class MeController extends Controller
{
    public function show(Request $request): array
    {
        return ['data' => (new MeResource($request->user()))->resolve()];
    }

    public function update(Request $request): array
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'min:2', 'max:50'],
            'bio' => ['sometimes', 'nullable', 'string', 'max:300'],
            'showOnlineStatus' => ['sometimes', 'boolean'],
            'location' => ['sometimes', 'nullable', 'string', 'max:100'],
            'hometown' => ['sometimes', 'nullable', 'string', 'max:100'],
            'workplace' => ['sometimes', 'nullable', 'string', 'max:100'],
            'education' => ['sometimes', 'nullable', 'string', 'max:100'],
            'website' => ['sometimes', 'nullable', 'string', 'max:200', 'url:http,https'],
            'birthday' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'after:1900-01-01', 'before:today'],
        ]);

        $user = $request->user();

        if (array_key_exists('name', $data)) {
            $user->name = trim($data['name']);
            if (mb_strlen($user->name) < 2) {
                abort(response()->json([
                    'message' => __('Validation failed.'),
                    'code' => 'validation_failed',
                    'errors' => ['name' => ['The name field must be at least 2 characters.']],
                ], 422));
            }
        }
        if (array_key_exists('bio', $data)) {
            $user->bio = $data['bio'] === null || trim($data['bio']) === '' ? null : trim($data['bio']);
        }
        if (array_key_exists('showOnlineStatus', $data)) {
            $user->show_online_status = $data['showOnlineStatus'];
        }
        // A blank text clears the field, like the bio.
        foreach (['location', 'hometown', 'workplace', 'education', 'website', 'birthday'] as $field) {
            if (array_key_exists($field, $data)) {
                $user->{$field} = $data[$field] === null || trim($data[$field]) === '' ? null : trim($data[$field]);
            }
        }
        $user->save();

        return ['data' => (new MeResource($user))->resolve()];
    }

    /** TouchLastSeen has already noted the request; this call is only a heartbeat. */
    public function presence(): JsonResponse
    {
        return response()->json(null, 204);
    }

    public function setCover(Request $request): array
    {
        $request->validate(['cover' => ImageStore::rules(required: true)]);

        $user = $request->user();
        $old = $user->cover_path;
        $user->cover_path = ImageStore::store($request->file('cover'), 'covers', 'cover');
        $user->save();
        ImageStore::deleteLater($old);

        return ['data' => (new MeResource($user))->resolve()];
    }

    public function removeCover(Request $request): array
    {
        $user = $request->user();
        $old = $user->cover_path;
        $user->cover_path = null;
        $user->save();
        ImageStore::deleteLater($old);

        return ['data' => (new MeResource($user))->resolve()];
    }

    public function setAvatar(Request $request): array
    {
        $request->validate(['avatar' => ImageStore::rules(required: true)]);

        $user = $request->user();
        $old = $user->avatar_path;
        $user->avatar_path = ImageStore::store($request->file('avatar'), 'avatars', 'avatar');
        $user->save();
        ImageStore::deleteLater($old);

        return ['data' => (new MeResource($user))->resolve()];
    }

    public function removeAvatar(Request $request): array
    {
        $user = $request->user();
        $old = $user->avatar_path;
        $user->avatar_path = null;
        $user->save();
        ImageStore::deleteLater($old);

        return ['data' => (new MeResource($user))->resolve()];
    }

    /**
     * Soft-deletes the account at once (so it vanishes for everyone else) and leaves the
     * rows for the `accounts:purge-deleted` job to remove after the retention period.
     */
    public function destroy(Request $request): JsonResponse
    {
        $request->validate(['password' => ['required', 'string']]);
        $user = $request->user();

        if (! Hash::check($request->input('password'), $user->password)) {
            throw new HttpResponseException(response()->json([
                'message' => __('The password is incorrect.'),
                'code' => 'invalid_credentials',
                'errors' => ['password' => [__('The password is incorrect.')]],
            ], 422));
        }

        $avatar = $user->avatar_path;
        $cover = $user->cover_path;

        DB::transaction(function () use ($user): void {
            $user->tokens()->delete();
            DB::table('auth_codes')->where('user_id', $user->id)->delete();
            DB::table('device_tokens')->where('user_id', $user->id)->delete();
            // Friends lists and counts must not include someone who is gone.
            DB::table('friendships')->where('requester_id', $user->id)->orWhere('addressee_id', $user->id)->delete();
            DB::table('follows')->where('follower_id', $user->id)->orWhere('followee_id', $user->id)->delete();
            $user->delete();
        });
        ImageStore::deleteLater($avatar);
        ImageStore::deleteLater($cover);

        return response()->json(null, 204);
    }
}
