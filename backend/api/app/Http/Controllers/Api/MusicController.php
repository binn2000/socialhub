<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\MusicCatalog;
use App\Support\MusicUnavailable;
use Illuminate\Http\Request;

class MusicController extends Controller
{
    public function search(Request $request): array
    {
        $data = $request->validate(['q' => ['required', 'string', 'min:2', 'max:100']]);

        try {
            return ['data' => MusicCatalog::search($data['q'])];
        } catch (MusicUnavailable) {
            abort(response()->json(['message' => __('Music is not available right now.'), 'code' => 'music_unavailable'], 503));
        }
    }
}
