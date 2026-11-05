<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\VideoCatalog;
use App\Support\VideoUnavailable;
use Illuminate\Http\Request;

class VideoSearchController extends Controller
{
    public function search(Request $request): array
    {
        $data = $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            // YouTube's own page token: letters, digits, "_" and "-" only.
            'cursor' => ['nullable', 'string', 'max:100', 'regex:/^[A-Za-z0-9_-]+$/'],
        ]);

        try {
            $page = VideoCatalog::search($data['q'] ?? '', $data['cursor'] ?? null);
        } catch (VideoUnavailable) {
            abort(response()->json(['message' => __('Videos are not available right now.'), 'code' => 'video_unavailable'], 503));
        }

        return ['data' => $page['data'], 'meta' => ['nextCursor' => $page['nextCursor'], 'hasMore' => $page['nextCursor'] !== null]];
    }
}
