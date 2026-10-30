<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\CreateNotification;
use App\Models\User;
use App\Support\Blocks;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class FollowController extends Controller
{
    public function store(Request $request, User $user): JsonResponse
    {
        $me = $request->user();
        if ($user->id === $me->id) {
            throw ValidationException::withMessages(['userId' => [__('You cannot follow yourself.')]]);
        }
        if (Blocks::either($me->id, $user->id)) {
            abort(404);
        }

        $created = DB::table('follows')->insertOrIgnore([
            'follower_id' => $me->id, 'followee_id' => $user->id, 'created_at' => now(),
        ]);
        if ($created > 0) {
            CreateNotification::dispatch($user->id, $me->id, 'follow', dedupeKey: "follow:{$me->id}:{$user->id}")->afterCommit();
        }

        return response()->json(null, 204);
    }

    public function destroy(Request $request, string $user): JsonResponse
    {
        DB::table('follows')->where('follower_id', $request->user()->id)->where('followee_id', $user)->delete();

        return response()->json(null, 204);
    }
}
