<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Comment;
use App\Models\Post;
use App\Models\User;
use App\Support\Blocks;
use App\Support\PostPresenter;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ReportController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'targetType' => ['required', Rule::in(['post', 'comment', 'user'])],
            'targetId' => ['required', 'string', 'max:26'],
            'reason' => ['required', Rule::in(['spam', 'harassment', 'hate', 'violence', 'nudity', 'false_info', 'other'])],
            'details' => ['nullable', 'string', 'max:500'],
        ]);
        $me = $request->user();
        $type = $data['targetType'];
        $id = strtolower($data['targetId']);

        $authorId = $this->authorOf($request, $type, $id);
        if ($authorId === $me->id) {
            throw ValidationException::withMessages(['targetId' => [__('You cannot report yourself.')]]);
        }

        $key = ['reporter_id' => $me->id, 'target_type' => $type, 'target_id' => $id];
        $details = isset($data['details']) && trim($data['details']) !== '' ? trim($data['details']) : null;
        $created = false;

        $report = DB::table('reports')->where($key)->first();
        if (! $report) {
            try {
                DB::table('reports')->insert($key + [
                    'id' => strtolower((string) Str::ulid()), 'reason' => $data['reason'],
                    'details' => $details, 'status' => 'open', 'created_at' => now(),
                ]);
                $created = true;
            } catch (UniqueConstraintViolationException) {
                // A double tap raced us; the other request stored it.
            }
            $report = DB::table('reports')->where($key)->first();
        }

        return response()->json(['data' => [
            'id' => $report->id,
            'targetType' => $type,
            'targetId' => $id,
            'reason' => $report->reason,
            'createdAt' => PostPresenter::timestamp(\Illuminate\Support\Carbon::parse($report->created_at)),
        ]], $created ? 201 : 200);
    }

    /** The user who wrote the target; 404 when the caller cannot see it. */
    private function authorOf(Request $request, string $type, string $id): string
    {
        $me = $request->user();

        return match ($type) {
            'post' => Post::visibleTo($me)->whereKey($id)->value('user_id') ?? abort(404),
            'comment' => $this->commentAuthor($request, $id),
            'user' => (! Blocks::either($me->id, $id) ? User::whereKey($id)->value('id') : null) ?? abort(404),
        };
    }

    private function commentAuthor(Request $request, string $id): string
    {
        $comment = Comment::whereKey($id)->first() ?? abort(404);
        PostController::authorizeView($request, Post::find($comment->post_id) ?? abort(404));

        return $comment->user_id;
    }
}
