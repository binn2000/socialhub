<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Post;
use App\Support\Blocks;
use App\Support\Cursor;
use App\Support\PostPresenter;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ExploreController extends Controller
{
    private const TRENDING_DAYS = 7;

    public function index(Request $request): array
    {
        $request->validate([
            'filter' => ['nullable', Rule::in(['for_you', 'trending', 'short_video'])],
            'q' => ['nullable', 'string', 'max:100'],
        ]);

        $filter = $request->query('filter', 'for_you');
        $q = trim((string) $request->query('q', ''));
        $scope = "explore|$filter|".mb_strtolower($q);

        // Explore ignores "hide" on purpose: it only looks at public posts.
        $query = Post::where('privacy', 'public')->has('author')->matching($q);
        Blocks::exclude($query, $request->user()->id, 'posts.user_id');

        return match ($filter) {
            'for_you' => PostController::page($request, $query, $scope),
            'trending' => self::trending($request, $query, $scope),
            // Reserved: posts have no video in v1.
            'short_video' => ['data' => [], 'meta' => ['nextCursor' => null, 'hasMore' => false]],
        };
    }

    /** Last 7 days, most liked first. Keyset on (likes_count, id); counts may move between pages. */
    public static function trending(Request $request, $query, string $scope): array
    {
        $request->validate([
            'cursor' => ['nullable', 'string'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);
        $limit = (int) $request->query('limit', 20);

        $query->where('created_at', '>=', now()->subDays(self::TRENDING_DAYS));

        if ($request->filled('cursor')) {
            [$likes, $id] = Cursor::decode($request->query('cursor'), $scope) ?? Cursor::invalid();
            $query->where(fn ($w) => $w->where('likes_count', '<', (int) $likes)
                ->orWhere(fn ($t) => $t->where('likes_count', (int) $likes)->where('id', '<', $id)));
        }

        $rows = $query->orderByDesc('likes_count')->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit);
        $last = $page->last();

        return [
            'data' => PostPresenter::many($page, $request->user()),
            'meta' => [
                'nextCursor' => $hasMore ? Cursor::encode($scope, (string) $last->likes_count, $last->id) : null,
                'hasMore' => $hasMore,
            ],
        ];
    }
}
