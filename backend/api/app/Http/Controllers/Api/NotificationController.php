<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Comment;
use App\Models\Notification;
use App\Models\Post;
use App\Support\Blocks;
use App\Support\Cursor;
use App\Support\PostPresenter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class NotificationController extends Controller
{
    public function index(Request $request): array
    {
        $request->validate([
            'category' => ['nullable', 'in:interactions,friends'],
            'unread' => ['nullable', 'in:true,false,1,0'],
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $limit = (int) $request->query('limit', 20);
        $category = $request->query('category');
        $unread = $request->boolean('unread');
        $scope = 'notifications|'.$category.'|'.($unread ? 'unread' : 'all');
        $query = $this->mine($request);

        if ($category !== null) {
            $query->whereIn('type', $category === 'friends' ? ['friend_request', 'friend_accepted', 'follow'] : ['like', 'comment', 'share']);
        }
        if ($unread) {
            $query->whereNull('read_at');
        }

        if ($request->filled('cursor')) {
            [$createdAt, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where(fn ($w) => $w->where('created_at', '<', $createdAt)
                ->orWhere(fn ($t) => $t->where('created_at', $createdAt)->where('id', '<', $id)));
        }

        $rows = $query->with('actor')->orderByDesc('created_at')->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit)->values();
        $last = $page->last();

        // relatedContent and the pending state are read now, not stored.
        $posts = Post::whereIn('id', $page->pluck('post_id')->filter())->pluck('content', 'id');
        $comments = Comment::whereIn('id', $page->pluck('comment_id')->filter())->pluck('content', 'id');
        // What each person reacted with, for the like notifications (read now, so a changed reaction shows).
        $reactions = DB::table('post_likes')->whereIn('post_id', $page->where('type', 'like')->pluck('post_id'))
            ->whereIn('user_id', $page->where('type', 'like')->pluck('actor_id'))
            ->get(['post_id', 'user_id', 'reaction'])
            ->mapWithKeys(fn ($r) => [$r->post_id.'|'.$r->user_id => $r->reaction]);
        $pending = DB::table('friendships')->whereIn('id', $page->pluck('friendship_id')->filter())
            ->where('status', 'pending')->pluck('id')->flip();

        return [
            'data' => $page->map(fn (Notification $n) => [
                'id' => $n->id,
                'type' => $n->type,
                'actor' => PostPresenter::userSummary($n->actor),
                'isRead' => $n->read_at !== null,
                'createdAt' => PostPresenter::timestamp($n->created_at),
                'postId' => $n->post_id,
                'reaction' => $n->type === 'like' ? ($reactions[$n->post_id.'|'.$n->actor_id] ?? 'like') : null,
                'commentId' => $n->comment_id,
                'friendRequestId' => $n->type === 'friend_request' && $pending->has($n->friendship_id) ? $n->friendship_id : null,
                'relatedContent' => $this->excerpt(match ($n->type) {
                    'comment' => $comments[$n->comment_id] ?? null,
                    'like', 'share' => $posts[$n->post_id] ?? null,
                    default => null,
                }),
            ])->all(),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, $last->created_at->format('Y-m-d H:i:s'), $last->id) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    public function unreadCount(Request $request): array
    {
        return ['data' => ['count' => $this->mine($request)->whereNull('read_at')->count()]];
    }

    public function readAll(Request $request): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)->whereNull('read_at')->update(['read_at' => now()]);

        return response()->json(null, 204);
    }

    public function read(Request $request, string $notification): JsonResponse
    {
        $owned = Notification::where('id', $notification)->where('user_id', $request->user()->id);

        if (! (clone $owned)->exists()) {
            abort(404);
        }

        $owned->whereNull('read_at')->update(['read_at' => now()]);

        return response()->json(null, 204);
    }

    /** The caller's notifications; those whose actor account is gone are not listed or counted. */
    private function mine(Request $request)
    {
        $query = Notification::where('user_id', $request->user()->id)->has('actor');
        Blocks::exclude($query, $request->user()->id, 'notifications.actor_id');

        return $query;
    }

    private function excerpt(?string $text): ?string
    {
        $text = trim((string) $text);

        return $text === '' ? null : Str::limit($text, 100, '');
    }
}
