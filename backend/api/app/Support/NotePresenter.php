<?php

namespace App\Support;

use App\Models\Note;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class NotePresenter
{
    public static function one(Note $note): array
    {
        return [
            'user' => PostPresenter::userSummary($note->user),
            'text' => (string) $note->text,
            'track' => MusicCatalog::present($note),
            'privacy' => $note->privacy,
            'createdAt' => PostPresenter::timestamp($note->updated_at),
            'expiresAt' => PostPresenter::timestamp($note->expires_at),
        ];
    }

    /** The unexpired note of $owner that $viewer may see (public, friends-only for a friend, or their own). */
    public static function visibleOn(User $viewer, User $owner): ?Note
    {
        $note = Note::with('user')->where('user_id', $owner->id)->where('expires_at', '>', now())->first();
        if ($note === null) {
            return null;
        }
        if ($viewer->id === $owner->id || $note->privacy === 'public') {
            return $note;
        }

        return $note->privacy === 'friends' && self::friends($viewer->id, $owner->id) ? $note : null;
    }

    private static function friends(string $a, string $b): bool
    {
        return DB::table('friendships')->where('status', 'accepted')
            ->where('user_low_id', min($a, $b))->where('user_high_id', max($a, $b))->exists();
    }
}
