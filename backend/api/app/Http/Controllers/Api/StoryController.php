<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Story;
use App\Models\User;
use App\Support\Blocks;
use App\Support\Cursor;
use App\Support\ImageStore;
use App\Support\MusicCatalog;
use App\Support\MusicUnavailable;
use App\Support\PostPresenter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class StoryController extends Controller
{
    public function index(Request $request): array
    {
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $me = $request->user();
        $limit = (int) $request->query('limit', 30);
        $scope = 'stories';
        $query = Story::inTrayOf($me);

        if ($request->filled('cursor')) {
            // The cursor holds "<bucket>|<createdAt>": m = my stories (listed first), o = everyone else's.
            [$mark, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            [$bucket, $createdAt] = array_pad(explode('|', $mark, 2), 2, null);
            $after = fn ($w) => $w->where('created_at', '<', $createdAt)
                ->orWhere(fn ($t) => $t->where('created_at', $createdAt)->where('id', '<', $id));

            if ($bucket === 'm') {
                $query->where(fn ($w) => $w->where('user_id', '!=', $me->id)
                    ->orWhere(fn ($m) => $m->where('user_id', $me->id)->where($after)));
            } elseif ($bucket === 'o') {
                $query->where('user_id', '!=', $me->id)->where($after);
            } else {
                Cursor::invalid();
            }
        }

        $rows = $query->orderByRaw('user_id = ? desc', [$me->id])->orderByDesc('created_at')->orderByDesc('id')
            ->with('author')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit)->values();
        $last = $page->last();

        $viewed = DB::table('story_views')->where('user_id', $me->id)->whereIn('story_id', $page->pluck('id'))
            ->pluck('story_id')->flip();

        return [
            'data' => $page->map(fn (Story $s) => $this->present($s, $me->id !== $s->user_id && $viewed->has($s->id)))->all(),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode(
                    $scope,
                    ($last->user_id === $me->id ? 'm' : 'o').'|'.$last->created_at->format('Y-m-d H:i:s'),
                    $last->id,
                ) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'text' => ['nullable', 'string', 'max:500'],
            'image' => ImageStore::rules(),
            'background' => ['nullable', Rule::in(['indigo', 'sunset', 'mint', 'berry'])],
            'trackId' => ['nullable', 'string', 'max:20'],
            'privacy' => ['nullable', Rule::in(['public', 'friends', 'only_me'])],
        ]);

        $text = trim((string) ($data['text'] ?? ''));
        if ($text === '' && ! $request->hasFile('image')) {
            throw ValidationException::withMessages(['text' => [__('A story needs text or an image.')]]);
        }

        $track = null;
        if (filled($data['trackId'] ?? null)) {
            try {
                $track = MusicCatalog::lookup($data['trackId']);
            } catch (MusicUnavailable) {
                abort(response()->json(['message' => __('Music is not available right now.'), 'code' => 'music_unavailable'], 503));
            }
            if ($track === null) {
                throw ValidationException::withMessages(['trackId' => [__('This song was not found.')]]);
            }
            $track = MusicCatalog::withSpotify($track);
        }

        $imagePath = $request->hasFile('image') ? ImageStore::store($request->file('image'), 'stories') : null;

        try {
            $story = Story::create([
                'user_id' => $request->user()->id,
                'text' => $text === '' ? null : $text,
                'image_path' => $imagePath,
                'background' => $data['background'] ?? 'indigo',
                'privacy' => $data['privacy'] ?? 'friends',
                'expires_at' => now()->addHours(24),
            ] + MusicCatalog::columns($track));
        } catch (\Throwable $e) {
            ImageStore::delete($imagePath);
            throw $e;
        }

        return response()->json(['data' => $this->present($story->refresh()->setRelation('author', $request->user()), false)], 201);
    }

    /** The unexpired stories of one person that the caller may see (their profile opens them). */
    public function forUser(Request $request, User $user): array
    {
        $me = $request->user();
        if (Blocks::blockedBy($user->id, $me->id)) {
            abort(404);
        }

        $stories = Story::visibleTo($me)->where('user_id', $user->id)->with('author')
            ->orderByDesc('created_at')->orderByDesc('id')->limit(30)->get();
        $viewed = DB::table('story_views')->where('user_id', $me->id)->whereIn('story_id', $stories->pluck('id'))
            ->pluck('story_id')->flip();

        return ['data' => $stories->map(fn (Story $s) => $this->present($s, $me->id !== $s->user_id && $viewed->has($s->id)))->all()];
    }

    public function update(Request $request, Story $story): array
    {
        $this->authorizeView($request, $story);

        if ($story->user_id !== $request->user()->id) {
            abort(response()->json(['message' => __('This action is unauthorized.'), 'code' => 'forbidden'], 403));
        }

        $data = $request->validate(['privacy' => ['required', Rule::in(['public', 'friends', 'only_me'])]]);
        $story->update(['privacy' => $data['privacy']]);

        return ['data' => $this->present($story->refresh()->setRelation('author', $request->user()), false)];
    }

    public function destroy(Request $request, Story $story): JsonResponse
    {
        $this->authorizeView($request, $story);

        if ($story->user_id !== $request->user()->id) {
            abort(response()->json(['message' => __('This action is unauthorized.'), 'code' => 'forbidden'], 403));
        }

        $story->delete();

        return response()->json(null, 204);
    }

    public function view(Request $request, Story $story): JsonResponse
    {
        $this->authorizeView($request, $story);

        if ($story->user_id !== $request->user()->id) {
            DB::table('story_views')->insertOrIgnore([
                'story_id' => $story->id, 'user_id' => $request->user()->id, 'viewed_at' => now(),
            ]);
        }

        return response()->json(null, 204);
    }

    private function authorizeView(Request $request, Story $story): void
    {
        if (! Story::visibleTo($request->user())->whereKey($story->id)->exists()) {
            abort(404);
        }
    }

    private function present(Story $s, bool $isViewed): array
    {
        return [
            'id' => $s->id,
            'author' => PostPresenter::userSummary($s->author),
            'text' => $s->text,
            'imageUrl' => ImageStore::url($s->image_path),
            'background' => $s->background,
            'createdAt' => PostPresenter::timestamp($s->created_at),
            'expiresAt' => PostPresenter::timestamp($s->expires_at),
            'isViewed' => $isViewed,
            'track' => MusicCatalog::present($s),
            'privacy' => $s->privacy,
        ];
    }
}
