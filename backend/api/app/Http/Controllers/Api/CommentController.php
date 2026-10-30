<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\CreateNotification;
use App\Models\Comment;
use App\Models\Post;
use App\Support\Blocks;
use App\Support\Cursor;
use App\Support\PostPresenter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CommentController extends Controller
{
    public function index(Request $request, Post $post): array
    {
        PostController::authorizeView($request, $post);
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $limit = (int) $request->query('limit', 20);
        $scope = 'comments|'.$post->id;
        $query = Comment::where('post_id', $post->id)->has('author');
        Blocks::exclude($query, $request->user()->id, 'comments.user_id');

        if ($request->filled('cursor')) {
            [$createdAt, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where(fn ($w) => $w->where('created_at', '<', $createdAt)
                ->orWhere(fn ($t) => $t->where('created_at', $createdAt)->where('id', '<', $id)));
        }

        $rows = $query->with('author')->orderByDesc('created_at')->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit);
        $last = $page->last();

        return [
            'data' => $page->map(fn (Comment $c) => $this->present($c))->values()->all(),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, $last->created_at->format('Y-m-d H:i:s'), $last->id) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    public function store(Request $request, Post $post): JsonResponse
    {
        PostController::authorizeView($request, $post);
        $data = $request->validate(['content' => ['required', 'string', 'max:1000']]);
        $me = $request->user();

        $comment = DB::transaction(function () use ($post, $me, $data) {
            $comment = Comment::create(['post_id' => $post->id, 'user_id' => $me->id, 'content' => trim($data['content'])]);
            Post::whereKey($post->id)->increment('comments_count');

            // No dedupe key: every comment notifies.
            CreateNotification::dispatch($post->user_id, $me->id, 'comment', postId: $post->id, commentId: $comment->id)
                ->afterCommit();

            return $comment;
        });

        return response()->json([
            'data' => $this->present($comment->refresh()->setRelation('author', $me)),
            'meta' => ['commentsCount' => (int) $post->fresh()->comments_count],
        ], 201);
    }

    public function destroy(Request $request, Comment $comment): JsonResponse
    {
        $post = Post::find($comment->post_id) ?? abort(404);
        PostController::authorizeView($request, $post);

        $me = $request->user();
        if ($comment->user_id !== $me->id && $post->user_id !== $me->id) {
            abort(response()->json(['message' => __('This action is unauthorized.'), 'code' => 'forbidden'], 403));
        }

        DB::transaction(function () use ($comment, $post) {
            // Foreign keys only fire on hard delete, so remove the notifications by hand.
            DB::table('notifications')->where('comment_id', $comment->id)->delete();
            $comment->delete();
            Post::whereKey($post->id)->update(['comments_count' => DB::raw('GREATEST(comments_count - 1, 0)')]);
        });

        return response()->json(null, 204);
    }

    private function present(Comment $c): array
    {
        return [
            'id' => $c->id,
            'postId' => $c->post_id,
            'author' => PostPresenter::userSummary($c->author),
            'content' => $c->content,
            'createdAt' => PostPresenter::timestamp($c->created_at),
        ];
    }
}
