<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Note;
use App\Support\Blocks;
use App\Support\MusicCatalog;
use App\Support\MusicUnavailable;
use App\Support\NotePresenter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class NoteController extends Controller
{
    private const MAX_LENGTH = 60;

    /**
     * My note first, then the notes I may see, newest first: `friends` and `public` notes of my friends,
     * and `public` notes of people I follow.
     */
    public function index(Request $request): array
    {
        $me = $request->user();
        // Two IN subqueries instead of a UNION: MariaDB 10.1 rejects a parenthesised UNION inside IN().
        $friends = fn ($w) => $w
            ->whereIn('user_id', fn ($s) => $s->select('addressee_id')->from('friendships')
                ->where('requester_id', $me->id)->where('status', 'accepted'))
            ->orWhereIn('user_id', fn ($s) => $s->select('requester_id')->from('friendships')
                ->where('addressee_id', $me->id)->where('status', 'accepted'));

        $query = Note::with('user')->where('expires_at', '>', now())->has('user')
            ->where(fn ($w) => $w->where('user_id', $me->id)
                ->orWhere(fn ($f) => $f->whereIn('privacy', ['public', 'friends'])->where($friends))
                ->orWhere(fn ($p) => $p->where('privacy', 'public')
                    ->whereIn('user_id', fn ($s) => $s->select('followee_id')->from('follows')->where('follower_id', $me->id))));
        Blocks::exclude($query, $me->id, 'notes.user_id');

        $notes = $query->orderByRaw('user_id = ? desc', [$me->id])->orderByDesc('updated_at')->orderByDesc('id')
            ->limit(100)->get();

        return ['data' => $notes->map(fn (Note $n) => NotePresenter::one($n))->all()];
    }

    public function store(Request $request): array
    {
        $data = $request->validate([
            'text' => ['nullable', 'string'],
            'trackId' => ['nullable', 'string', 'max:20'],
            'privacy' => ['nullable', Rule::in(['public', 'friends', 'only_me'])],
        ]);
        $text = trim(preg_replace('/\s+/u', ' ', (string) ($data['text'] ?? '')));
        $track = $this->trackFor($data['trackId'] ?? null);

        if ($text === '' && $track === null) {
            throw ValidationException::withMessages(['text' => [__('A note cannot be empty.')]]);
        }
        if (mb_strlen($text) > self::MAX_LENGTH) {
            throw ValidationException::withMessages(['text' => [__('A note can have at most :max characters.', ['max' => self::MAX_LENGTH])]]);
        }

        $me = $request->user();
        $note = DB::transaction(function () use ($me, $text, $track, $data) {
            $note = Note::firstOrNew(['user_id' => $me->id]);
            // Leaving it out keeps the privacy of the note being replaced (friends for a new one).
            $note->privacy = $data['privacy'] ?? $note->privacy ?? 'friends';
            $note->text = $text === '' ? null : $text;
            $note->fill(MusicCatalog::columns($track));
            $note->expires_at = now()->addHours(Note::LIFETIME_HOURS);
            $note->save();

            return $note;
        });

        return ['data' => NotePresenter::one($note->setRelation('user', $me))];
    }

    public function destroy(Request $request): JsonResponse
    {
        Note::where('user_id', $request->user()->id)->delete();

        return response()->json(null, 204);
    }

    /** The song for a track id, looked up in the catalogue; null when none was asked for. */
    private function trackFor(?string $trackId): ?array
    {
        if ($trackId === null || $trackId === '') {
            return null;
        }

        try {
            $track = MusicCatalog::lookup($trackId);
        } catch (MusicUnavailable) {
            abort(response()->json(['message' => __('Music is not available right now.'), 'code' => 'music_unavailable'], 503));
        }
        if ($track === null) {
            throw ValidationException::withMessages(['trackId' => [__('This song was not found.')]]);
        }

        return MusicCatalog::withSpotify($track);
    }
}
