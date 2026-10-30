<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/** Who may see that a user is online, and when they were last active. */
class Presence
{
    public const ONLINE_SECONDS = 120;

    /**
     * Friends (and the user themself) see the real state of users who left "show online status" on;
     * everyone else gets the same answer as for an offline user, which does not reveal the setting.
     *
     * @param  Collection<int, User>  $users
     * @return array<string, array{isOnline: bool, lastSeenAt: ?string}>
     */
    public static function forUsers(User $viewer, Collection $users): array
    {
        $ids = $users->pluck('id')->reject(fn ($id) => $id === $viewer->id);
        $friends = DB::table('friendships')->where('status', 'accepted')
            ->where(fn ($q) => $q
                ->where(fn ($a) => $a->where('requester_id', $viewer->id)->whereIn('addressee_id', $ids))
                ->orWhere(fn ($b) => $b->where('addressee_id', $viewer->id)->whereIn('requester_id', $ids)))
            ->get(['requester_id', 'addressee_id'])
            ->flatMap(fn ($row) => [$row->requester_id, $row->addressee_id])->flip();

        $result = [];
        foreach ($users as $user) {
            $visible = $user->id === $viewer->id || ($friends->has($user->id) && $user->show_online_status);
            $seen = $visible ? $user->last_seen_at : null;
            $result[$user->id] = [
                'isOnline' => $seen !== null && $seen->gt(now()->subSeconds(self::ONLINE_SECONDS)),
                'lastSeenAt' => $seen ? PostPresenter::timestamp($seen) : null,
            ];
        }

        return $result;
    }
}
