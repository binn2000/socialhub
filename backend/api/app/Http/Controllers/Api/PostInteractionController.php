<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\CreateNotification;
use App\Models\Post;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * like / save / hide. Each is idempotent: the composite primary key decides whether a row
 * was really added or removed, and the counter only moves in that case.
 */
class PostInteractionController extends Controller
{
    /** The reactions a person can leave on a post; "like" is the plain Thích. */
    public const REACTIONS = ['like', 'love', 'haha', 'wow', 'sad', 'angry'];

    public function like(Request $request, Post $post): array
    {
        PostController::authorizeView($request, $post);
        $data = $request->validate(['reaction' => ['nullable', Rule::in(self::REACTIONS)]]);
        $userId = $request->user()->id;

        DB::transaction(function () use ($post, $userId, $data) {
            $added = DB::table('post_likes')->insertOrIgnore([
                'post_id' => $post->id, 'user_id' => $userId, 'created_at' => now(),
                'reaction' => $data['reaction'] ?? 'like',
            ]);

            if ($added) {
                $post->increment('likes_count');
                $this->notify($post, $userId, 'like');
            } elseif (isset($data['reaction'])) {
                // Already reacted: a different reaction replaces the old one, the count stays.
                DB::table('post_likes')->where('post_id', $post->id)->where('user_id', $userId)
                    ->update(['reaction' => $data['reaction']]);
            }
        });

        return $this->likeState($post, $userId, true);
    }

    public function unlike(Request $request, Post $post): array
    {
        PostController::authorizeView($request, $post);

        DB::transaction(function () use ($post, $request) {
            $removed = DB::table('post_likes')
                ->where('post_id', $post->id)->where('user_id', $request->user()->id)->delete();

            if ($removed) {
                Post::whereKey($post->id)->update(['likes_count' => DB::raw('GREATEST(likes_count - 1, 0)')]);
            }
        });

        return $this->likeState($post, $request->user()->id, false);
    }

    public function save(Request $request, Post $post): array
    {
        return ['data' => ['isSaved' => $this->toggleLink($request, $post, 'post_saves', true)]];
    }

    public function unsave(Request $request, Post $post): array
    {
        return ['data' => ['isSaved' => $this->toggleLink($request, $post, 'post_saves', false)]];
    }

    public function hide(Request $request, Post $post): array
    {
        return ['data' => ['isHidden' => $this->toggleLink($request, $post, 'post_hidden', true)]];
    }

    public function unhide(Request $request, Post $post): array
    {
        return ['data' => ['isHidden' => $this->toggleLink($request, $post, 'post_hidden', false)]];
    }

    public function share(Request $request, Post $post): array
    {
        PostController::authorizeView($request, $post);
        $data = $request->validate(['target' => ['nullable', 'in:link,message']]);
        $userId = $request->user()->id;

        DB::transaction(function () use ($post, $userId, $data) {
            // One row per user and post, so `shares` counts distinct people.
            $added = DB::table('post_shares')->insertOrIgnore([
                'post_id' => $post->id, 'user_id' => $userId,
                'target' => $data['target'] ?? 'link', 'created_at' => now(),
            ]);

            if ($added) {
                $post->increment('shares_count');
                $this->notify($post, $userId, 'share');
            }
        });

        return ['data' => ['shares' => (int) $post->fresh()->shares_count]];
    }

    private function toggleLink(Request $request, Post $post, string $table, bool $on): bool
    {
        PostController::authorizeView($request, $post);
        $row = ['post_id' => $post->id, 'user_id' => $request->user()->id];

        $on ? DB::table($table)->insertOrIgnore($row + ['created_at' => now()])
            : DB::table($table)->where($row)->delete();

        return $on;
    }

    private function likeState(Post $post, string $userId, bool $isLiked): array
    {
        return ['data' => [
            'isLiked' => $isLiked,
            'likes' => (int) $post->fresh()->likes_count,
            'reaction' => $isLiked
                ? DB::table('post_likes')->where('post_id', $post->id)->where('user_id', $userId)->value('reaction')
                : null,
            'reactionCounts' => (object) DB::table('post_likes')->where('post_id', $post->id)
                ->groupBy('reaction')->selectRaw('reaction, count(*) as total')->pluck('total', 'reaction')
                ->map(fn ($n) => (int) $n)->all(),
        ]];
    }

    private function notify(Post $post, string $actorId, string $type): void
    {
        // The dedupe key is unique, so like / unlike / like never notifies twice.
        CreateNotification::dispatch($post->user_id, $actorId, $type, postId: $post->id, dedupeKey: "{$type}:{$actorId}:{$post->id}")
            ->afterCommit();
    }
}
