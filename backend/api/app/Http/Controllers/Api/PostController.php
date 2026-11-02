<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessPostVideo;
use App\Models\Post;
use App\Models\PostImage;
use App\Support\Cursor;
use App\Support\ImageStore;
use App\Support\PostPresenter;
use App\Support\VideoStore;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class PostController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'content' => ['nullable', 'string', 'max:5000'],
            'image' => ImageStore::rules(),
            'video' => VideoStore::rules(),
            'images' => ['nullable', 'array', 'max:10'],
            'images.*' => ImageStore::rules(required: true),
            'feeling' => ['nullable', Rule::in(['cheerful', 'excited', 'happy'])],
            'privacy' => ['nullable', Rule::in(['public', 'friends', 'only_me'])],
        ]);

        if ($request->hasFile('image') && $request->hasFile('images')) {
            throw ValidationException::withMessages(['images' => [__('Send either image or images, not both.')]]);
        }
        if ($request->hasFile('video') && ($request->hasFile('image') || $request->hasFile('images'))) {
            throw ValidationException::withMessages(['video' => [__('A post has either images or a video, not both.')]]);
        }
        $video = $request->file('video');
        $files = $request->hasFile('images') ? $request->file('images') : array_filter([$request->file('image')]);

        $content = trim((string) ($data['content'] ?? ''));
        if ($content === '' && $files === [] && ! $video) {
            throw ValidationException::withMessages(['content' => [__('A post needs text, an image or a video.')]]);
        }
        if ($video) {
            VideoStore::probe($video->getRealPath());
        }

        $paths = [];
        $sourcePath = null;
        try {
            $sourcePath = $video ? VideoStore::storeSource($video) : null;
            foreach ($files as $index => $file) {
                $paths[] = ImageStore::store($file, 'posts', $request->hasFile('images') ? "images.$index" : 'image');
            }

            $post = DB::transaction(function () use ($request, $content, $data, $paths, $sourcePath) {
                $post = Post::create([
                    'user_id' => $request->user()->id,
                    'content' => $content === '' ? null : $content,
                    'image_path' => $paths[0] ?? null,
                    'feeling' => $data['feeling'] ?? null,
                    'privacy' => $data['privacy'] ?? 'public',
                    'video_status' => $sourcePath ? 'processing' : null,
                    'video_source_path' => $sourcePath,
                ]);
                foreach ($paths as $position => $path) {
                    PostImage::create(['post_id' => $post->id, 'path' => $path, 'position' => $position, 'created_at' => now()]);
                }

                return $post;
            });
        } catch (\Throwable $e) {
            array_map(ImageStore::delete(...), $paths);
            VideoStore::delete($sourcePath);
            throw $e;
        }

        if ($sourcePath) {
            ProcessPostVideo::dispatch($post->id)->afterCommit();
        }

        return response()->json(['data' => PostPresenter::one($post->refresh(), $request->user())], 201)
            ->header('Location', url('/api/v1/posts/'.$post->id));
    }

    public function show(Request $request, Post $post): array
    {
        $this->authorizeView($request, $post);

        return ['data' => PostPresenter::one($post, $request->user())];
    }

    public function update(Request $request, Post $post): array
    {
        $this->authorizeView($request, $post);

        if ($post->user_id !== $request->user()->id) {
            abort(response()->json(['message' => __('This action is unauthorized.'), 'code' => 'forbidden'], 403));
        }

        $data = $request->validate(['privacy' => ['required', Rule::in(['public', 'friends', 'only_me'])]]);
        $post->update(['privacy' => $data['privacy']]);

        return ['data' => PostPresenter::one($post->refresh(), $request->user())];
    }

    public function destroy(Request $request, Post $post): JsonResponse
    {
        $this->authorizeView($request, $post);

        if ($post->user_id !== $request->user()->id) {
            abort(response()->json(['message' => __('This action is unauthorized.'), 'code' => 'forbidden'], 403));
        }

        DB::transaction(function () use ($post) {
            // Foreign keys only fire on hard delete, so remove the notifications by hand.
            DB::table('notifications')->where('post_id', $post->id)->delete();
            $post->delete();
        });
        // Soft delete keeps the rows, so the files are removed here.
        PostImage::where('post_id', $post->id)->pluck('path')->push($post->image_path, $post->video_path, $post->video_thumb_path, $post->video_source_path)->filter()->unique()
            ->each(fn (string $path) => ImageStore::deleteLater($path));

        return response()->json(null, 204);
    }

    public function feed(Request $request): array
    {
        $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'filter' => ['nullable', Rule::in(['all', 'friends', 'following', 'media', 'popular'])],
        ]);
        $q = trim((string) $request->query('q', ''));
        $filter = $request->query('filter', 'all');
        $query = Post::feedFor($request->user())->matching($q);
        $scope = 'feed|'.$filter.'|'.mb_strtolower($q);

        return match ($filter) {
            'friends' => self::page($request, $query->fromFriends($request->user()), $scope),
            'following' => self::page($request, $query->whereIn('posts.user_id', fn ($s) => $s->select('followee_id')->from('follows')->where('follower_id', $request->user()->id)), $scope),
            'media' => self::page($request, $query->where(fn ($m) => $m->whereNotNull('posts.image_path')->orWhere('posts.video_status', 'ready')), $scope),
            'popular' => ExploreController::trending($request, $query, $scope),
            default => self::page($request, $query, $scope),
        };
    }

    /** My saved posts, most recently saved first. */
    public function saved(Request $request): array
    {
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $me = $request->user();
        $limit = (int) $request->query('limit', 20);
        $scope = 'saved-posts';
        // When this user saved the post. A subquery rather than a join: the
        // visibility scope names columns (user_id) that post_saves also has.
        $savedAt = '(select ps.created_at from post_saves ps where ps.post_id = posts.id and ps.user_id = ?)';

        $query = Post::visibleTo($me)
            ->whereExists(fn ($e) => $e->selectRaw('1')->from('post_saves')
                ->whereColumn('post_saves.post_id', 'posts.id')->where('post_saves.user_id', $me->id));

        if ($request->filled('cursor')) {
            [$at, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where(fn ($w) => $w->whereRaw("$savedAt < ?", [$me->id, $at])
                ->orWhere(fn ($t) => $t->whereRaw("$savedAt = ?", [$me->id, $at])->where('id', '<', $id)));
        }

        $rows = $query->select('posts.*')
            ->selectRaw("$savedAt as saved_at", [$me->id])
            ->orderByDesc('saved_at')->orderByDesc('id')
            ->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit);
        $last = $page->last();

        return [
            'data' => PostPresenter::many($page, $me),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, (string) $last->saved_at, $last->id) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    /** Keyset page of posts, newest first. $scope ties the cursor to one endpoint and its filters. */
    public static function page(Request $request, $query, string $scope): array
    {
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);
        $limit = (int) $request->query('limit', 20);

        if ($request->filled('cursor')) {
            [$createdAt, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where(fn ($w) => $w->where('created_at', '<', $createdAt)
                ->orWhere(fn ($t) => $t->where('created_at', $createdAt)->where('id', '<', $id)));
        }

        $rows = $query->orderByDesc('created_at')->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit);
        $last = $page->last();

        return [
            'data' => PostPresenter::many($page, $request->user()),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, $last->created_at->format('Y-m-d H:i:s'), $last->id) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    public static function authorizeView(Request $request, Post $post): void
    {
        if (! Post::visibleTo($request->user())->whereKey($post->id)->exists()) {
            abort(404);
        }
    }
}
