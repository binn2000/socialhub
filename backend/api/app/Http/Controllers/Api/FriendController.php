<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\CreateNotification;
use App\Models\Friendship;
use App\Models\User;
use App\Support\Blocks;
use App\Support\Cursor;
use App\Support\PostPresenter;
use App\Support\UserPresenter;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class FriendController extends Controller
{
    public function index(Request $request): array
    {
        $request->validate([
            'direction' => ['nullable', 'in:incoming,outgoing'],
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $me = $request->user();
        $direction = $request->query('direction', 'incoming');
        $limit = (int) $request->query('limit', 20);
        $scope = 'friend-requests|'.$direction;
        [$mine, $theirs] = $direction === 'incoming' ? ['addressee_id', 'requester_id'] : ['requester_id', 'addressee_id'];

        $query = Friendship::where('status', 'pending')->where($mine, $me->id)->has($direction === 'incoming' ? 'requester' : 'addressee');

        if ($request->filled('cursor')) {
            [$createdAt, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where(fn ($w) => $w->where('created_at', '<', $createdAt)
                ->orWhere(fn ($t) => $t->where('created_at', $createdAt)->where('id', '<', $id)));
        }

        $rows = $query->with(['requester', 'addressee'])->orderByDesc('created_at')->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit);
        $last = $page->last();

        return [
            'data' => $page->map(fn (Friendship $f) => $this->present($f))->values()->all(),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, $last->created_at->format('Y-m-d H:i:s'), $last->id) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate(['userId' => ['required', 'string']]);
        $me = $request->user();

        $target = User::find($data['userId']);
        if (! $target) {
            throw ValidationException::withMessages(['userId' => [__('The selected user does not exist.')]]);
        }
        if ($target->id === $me->id) {
            throw ValidationException::withMessages(['userId' => [__('You cannot send a friend request to yourself.')]]);
        }
        if (Blocks::either($me->id, $target->id)) {
            // Do not tell who blocked whom.
            throw ValidationException::withMessages(['userId' => [__('The selected user does not exist.')]]);
        }

        try {
            $friendship = DB::transaction(function () use ($me, $target) {
                $f = Friendship::create(['requester_id' => $me->id, 'addressee_id' => $target->id, 'status' => 'pending']);
                $this->notify($target->id, $me->id, 'friend_request', $f->id);

                return $f;
            });
        } catch (UniqueConstraintViolationException) {
            // The unique (user_low_id, user_high_id) index decides, also for two simultaneous requests.
            $existing = Friendship::where('user_low_id', min($me->id, $target->id))
                ->where('user_high_id', max($me->id, $target->id))->first();

            abort(response()->json($existing?->status === 'accepted'
                ? ['message' => __('You are already friends.'), 'code' => 'already_friends']
                : ['message' => __('A friend request already exists.'), 'code' => 'friend_request_exists'], 409));
        }

        return response()->json(['data' => $this->present($friendship->refresh()->load(['requester', 'addressee']))], 201);
    }

    public function accept(Request $request, string $friendRequest): array
    {
        $me = $request->user();
        $friendship = Friendship::where('id', $friendRequest)->where('addressee_id', $me->id)->first();

        if (! $friendship) {
            abort(404);
        }

        DB::transaction(function () use ($friendship, $me) {
            $changed = Friendship::where('id', $friendship->id)->where('status', 'pending')
                ->update(['status' => 'accepted', 'accepted_at' => now(), 'updated_at' => now()]);

            if ($changed) {
                $this->notify($friendship->requester_id, $me->id, 'friend_accepted', $friendship->id);
            }
        });

        $sender = User::find($friendship->requester_id) ?? abort(404);

        return ['data' => UserPresenter::profile($me, $sender)];
    }

    public function destroy(Request $request, string $friendRequest): JsonResponse
    {
        $me = $request->user();
        $deleted = Friendship::where('id', $friendRequest)->where('status', 'pending')
            ->where(fn ($q) => $q->where('requester_id', $me->id)->orWhere('addressee_id', $me->id))
            ->delete();

        if (! $deleted) {
            abort(404);
        }

        return response()->json(null, 204);
    }

    public function unfriend(Request $request, User $user): JsonResponse
    {
        $me = $request->user();

        Friendship::where('status', 'accepted')
            ->where('user_low_id', min($me->id, $user->id))->where('user_high_id', max($me->id, $user->id))
            ->delete();

        return response()->json(null, 204);
    }

    private function present(Friendship $f): array
    {
        return [
            'id' => $f->id,
            'sender' => PostPresenter::userSummary($f->requester),
            'receiver' => PostPresenter::userSummary($f->addressee),
            'createdAt' => PostPresenter::timestamp($f->created_at),
        ];
    }

    private function notify(string $recipientId, string $actorId, string $type, string $friendshipId): void
    {
        CreateNotification::dispatch($recipientId, $actorId, $type, friendshipId: $friendshipId, dedupeKey: "{$type}:{$friendshipId}")
            ->afterCommit();
    }
}
