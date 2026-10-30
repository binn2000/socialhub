<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\Cursor;
use App\Support\PostPresenter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class BlockController extends Controller
{
    public function index(Request $request): array
    {
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $me = $request->user();
        $limit = (int) $request->query('limit', 20);
        $scope = 'blocks';
        $query = DB::table('user_blocks')->where('blocker_id', $me->id)
            ->whereExists(fn ($e) => $e->selectRaw('1')->from('users')
                ->whereColumn('users.id', 'user_blocks.blocked_id')->whereNull('users.deleted_at'));

        if ($request->filled('cursor')) {
            [, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where('user_blocks.id', '<', (int) $id);
        }

        $rows = $query->orderByDesc('user_blocks.id')->limit($limit + 1)->get(['user_blocks.id', 'blocked_id']);
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit)->values();
        $users = User::whereIn('id', $page->pluck('blocked_id'))->get()->keyBy('id');

        return [
            'data' => $page->map(fn ($row) => PostPresenter::userSummary($users[$row->blocked_id]))->all(),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, 'id', (string) $page->last()->id) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    public function store(Request $request, User $user): JsonResponse
    {
        $me = $request->user();
        if ($user->id === $me->id) {
            throw ValidationException::withMessages(['userId' => [__('You cannot block yourself.')]]);
        }

        DB::transaction(function () use ($me, $user) {
            DB::table('user_blocks')->insertOrIgnore([
                'blocker_id' => $me->id, 'blocked_id' => $user->id, 'created_at' => now(),
            ]);
            // Friends or pending requests, in either direction, end here.
            DB::table('friendships')
                ->where('user_low_id', min($me->id, $user->id))->where('user_high_id', max($me->id, $user->id))
                ->delete();
            DB::table('follows')
                ->where(fn ($w) => $w->where('follower_id', $me->id)->where('followee_id', $user->id))
                ->orWhere(fn ($w) => $w->where('follower_id', $user->id)->where('followee_id', $me->id))
                ->delete();
        });

        return response()->json(null, 204);
    }

    public function destroy(Request $request, string $user): JsonResponse
    {
        DB::table('user_blocks')->where('blocker_id', $request->user()->id)->where('blocked_id', $user)->delete();

        return response()->json(null, 204);
    }
}
