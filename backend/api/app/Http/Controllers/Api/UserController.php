<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;
use App\Models\PostImage;
use App\Models\User;
use App\Support\Blocks;
use App\Support\Cursor;
use App\Support\ImageStore;
use App\Support\PostPresenter;
use App\Support\UserPresenter;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index(Request $request): array
    {
        $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'relationship' => ['nullable', Rule::in(['none', 'pending_outgoing', 'pending_incoming', 'friends'])],
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $me = $request->user();
        $q = trim((string) $request->query('q', ''));
        $relationship = $request->query('relationship');
        $limit = (int) $request->query('limit', 20);
        $scope = 'users|'.mb_strtolower($q).'|'.$relationship;

        $query = User::where('id', '!=', $me->id);
        Blocks::exclude($query, $me->id, 'users.id');

        if ($q !== '') {
            $like = '%'.addcslashes($q, '\\%_').'%';
            $query->where(fn ($w) => $w->where('name', 'like', $like)->orWhere('username', 'like', $like));
        }

        if ($relationship !== null) {
            $this->filterByRelationship($query, $me, $relationship);
        }

        return $this->pageUsers($request, $query, $scope, $limit);
    }

    /** Keyset page of users ordered by name, then id. */
    private function pageUsers(Request $request, $query, string $scope, int $limit): array
    {
        $me = $request->user();

        if ($request->filled('cursor')) {
            [$name, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where(fn ($w) => $w->where('name', '>', $name)
                ->orWhere(fn ($t) => $t->where('name', $name)->where('id', '>', $id)));
        }

        $rows = $query->orderBy('name')->orderBy('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit);
        $last = $page->last();

        return [
            'data' => UserPresenter::listItems($me, $page),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, $last->name, $last->id) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    /** The accepted friends of $user. */
    public function friends(Request $request, User $user): array
    {
        $this->hideIfBlockedByThem($request, $user);
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $me = $request->user();
        // Two IN subqueries instead of a UNION: MariaDB 10.1 rejects a parenthesised UNION inside IN().
        $query = User::where('id', '!=', $me->id)->where(fn ($w) => $w
            ->whereIn('id', fn ($s) => $s->select('addressee_id')->from('friendships')
                ->where('requester_id', $user->id)->where('status', 'accepted'))
            ->orWhereIn('id', fn ($s) => $s->select('requester_id')->from('friendships')
                ->where('addressee_id', $user->id)->where('status', 'accepted')));
        Blocks::exclude($query, $me->id, 'users.id');

        return $this->pageUsers($request, $query, 'user-friends|'.$user->id, (int) $request->query('limit', 20));
    }

    public function followers(Request $request, User $user): array
    {
        return $this->followList($request, $user, 'follower_id', 'followee_id', 'user-followers|');
    }

    public function following(Request $request, User $user): array
    {
        return $this->followList($request, $user, 'followee_id', 'follower_id', 'user-following|');
    }

    /** Users on the $listed side of the follows of $user (who sits on the $owner side). */
    private function followList(Request $request, User $user, string $listed, string $owner, string $scope): array
    {
        $this->hideIfBlockedByThem($request, $user);
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $me = $request->user();
        $query = User::where('id', '!=', $me->id)->whereIn('id', fn ($s) => $s->select($listed)->from('follows')->where($owner, $user->id));
        Blocks::exclude($query, $me->id, 'users.id');

        return $this->pageUsers($request, $query, $scope.$user->id, (int) $request->query('limit', 20));
    }

    /** One item per image of the visible posts of $user, newest image first. */
    public function photos(Request $request, User $user): array
    {
        $this->hideIfBlockedByThem($request, $user);
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $limit = (int) $request->query('limit', 20);
        $scope = 'user-photos|'.$user->id;
        $query = PostImage::whereIn('post_id', Post::visibleTo($request->user())->where('user_id', $user->id)->select('posts.id'));

        if ($request->filled('cursor')) {
            [, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where('id', '<', (int) $id);
        }

        $rows = $query->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit)->values();

        return [
            'data' => $page->map(fn (PostImage $i) => [
                'postId' => $i->post_id,
                'imageUrl' => ImageStore::url($i->path),
                'createdAt' => PostPresenter::timestamp($i->created_at),
            ])->all(),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, 'id', (string) $page->last()->id) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    /**
     * People with no relationship to the caller, most friends in common first, then the newest
     * accounts. The cursor holds the offset into that computed order.
     */
    public function suggestions(Request $request): array
    {
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $me = $request->user();
        $limit = (int) $request->query('limit', 20);
        $scope = 'suggestions';
        $offset = $request->filled('cursor')
            ? (int) (Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid())[0]
            : 0;
        $want = $offset + $limit + 1;

        $mine = DB::table('friendships')->where(fn ($q) => $q->where('requester_id', $me->id)->orWhere('addressee_id', $me->id))
            ->get(['requester_id', 'addressee_id', 'status']);
        $friends = [];
        $related = [$me->id => true];
        foreach ($mine as $row) {
            $other = $row->requester_id === $me->id ? $row->addressee_id : $row->requester_id;
            $related[$other] = true;
            if ($row->status === 'accepted') {
                $friends[$other] = true;
            }
        }
        foreach (DB::table('user_blocks')->where('blocker_id', $me->id)->pluck('blocked_id') as $id) {
            $related[$id] = true;
        }
        foreach (DB::table('user_blocks')->where('blocked_id', $me->id)->pluck('blocker_id') as $id) {
            $related[$id] = true;
        }

        $mutual = [];
        if ($friends) {
            $ids = array_keys($friends);
            $rows = DB::table('friendships')->where('status', 'accepted')
                ->where(fn ($q) => $q->whereIn('requester_id', $ids)->orWhereIn('addressee_id', $ids))
                ->get(['requester_id', 'addressee_id']);
            foreach ($rows as $row) {
                foreach ([[$row->requester_id, $row->addressee_id], [$row->addressee_id, $row->requester_id]] as [$friend, $candidate]) {
                    if (isset($friends[$friend]) && ! isset($related[$candidate])) {
                        $mutual[$candidate] = ($mutual[$candidate] ?? 0) + 1;
                    }
                }
            }
        }

        $alive = $mutual ? User::whereIn('id', array_keys($mutual))->pluck('id')->flip() : collect();
        $ranked = collect($mutual)->filter(fn ($count, $id) => $alive->has($id))->all();
        uksort($ranked, fn ($a, $b) => [$ranked[$b], $a] <=> [$ranked[$a], $b]);
        $ids = array_keys($ranked);

        if (count($ids) < $want) {
            $filler = User::whereNotIn('id', array_merge(array_keys($related), $ids))
                ->orderByDesc('id')->limit($want - count($ids))->pluck('id')->all();
            $ids = array_merge($ids, $filler);
        }

        $hasMore = count($ids) > $offset + $limit;
        $pageIds = array_slice($ids, $offset, $limit);
        $users = User::whereIn('id', $pageIds)->get()->keyBy('id');
        $page = collect($pageIds)->map(fn ($id) => $users[$id])->values();

        return [
            'data' => UserPresenter::listItems($me, $page),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, (string) ($offset + $limit), 'offset') : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    public function show(Request $request, User $user): array
    {
        $this->hideIfBlockedByThem($request, $user);

        return ['data' => UserPresenter::profile($request->user(), $user)];
    }

    public function posts(Request $request, User $user): array
    {
        $this->hideIfBlockedByThem($request, $user);
        $query = Post::visibleTo($request->user())->where('user_id', $user->id);

        return PostController::page($request, $query, 'user-posts|'.$user->id);
    }

    /** Someone who blocked the caller looks like a missing account. */
    private function hideIfBlockedByThem(Request $request, User $user): void
    {
        if (Blocks::blockedBy($user->id, $request->user()->id)) {
            abort(404);
        }
    }

    /** One indexed lookup on the (user_low_id, user_high_id) pair per candidate user. */
    private function filterByRelationship($query, User $me, string $relationship): void
    {
        $pair = fn ($f) => $f->from('friendships')
            ->whereRaw('friendships.user_low_id = LEAST(?, users.id)', [$me->id])
            ->whereRaw('friendships.user_high_id = GREATEST(?, users.id)', [$me->id]);

        match ($relationship) {
            'none' => $query->whereNotExists(fn ($f) => $pair($f->selectRaw('1'))),
            'friends' => $query->whereExists(fn ($f) => $pair($f->selectRaw('1'))->where('friendships.status', 'accepted')),
            'pending_outgoing' => $query->whereExists(fn ($f) => $pair($f->selectRaw('1'))
                ->where('friendships.status', 'pending')->where('friendships.requester_id', $me->id)),
            'pending_incoming' => $query->whereExists(fn ($f) => $pair($f->selectRaw('1'))
                ->where('friendships.status', 'pending')->where('friendships.addressee_id', $me->id)),
        };
    }
}
