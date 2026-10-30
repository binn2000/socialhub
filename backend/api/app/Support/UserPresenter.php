<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/** Builds the user shapes that depend on the caller (friendship status, mutual friends). */
class UserPresenter
{
    /** @return array<string, array{status: string, requestId: ?string}> keyed by user id */
    public static function friendshipMap(User $viewer, Collection $userIds): array
    {
        $map = [];
        $rows = DB::table('friendships')->where(fn ($q) => $q
            ->where(fn ($a) => $a->where('requester_id', $viewer->id)->whereIn('addressee_id', $userIds))
            ->orWhere(fn ($b) => $b->where('addressee_id', $viewer->id)->whereIn('requester_id', $userIds)))
            ->get();

        foreach ($rows as $row) {
            $otherId = $row->requester_id === $viewer->id ? $row->addressee_id : $row->requester_id;
            $pending = $row->status === 'pending';
            $map[$otherId] = [
                'status' => $pending ? ($row->requester_id === $viewer->id ? 'pending_outgoing' : 'pending_incoming') : 'friends',
                'requestId' => $pending ? $row->id : null,
            ];
        }

        return $map;
    }

    /** @return array<string, array<string, true>> accepted friend ids of each user, keyed by user id */
    private static function friendSets(Collection $userIds): array
    {
        $sets = [];
        $rows = DB::table('friendships')->where('status', 'accepted')
            ->where(fn ($q) => $q->whereIn('requester_id', $userIds)->orWhereIn('addressee_id', $userIds))
            ->get(['requester_id', 'addressee_id']);

        foreach ($rows as $row) {
            $sets[$row->requester_id][$row->addressee_id] = true;
            $sets[$row->addressee_id][$row->requester_id] = true;
        }

        return $sets;
    }

    /** @param Collection<int, User> $users */
    public static function listItems(User $viewer, Collection $users): array
    {
        $ids = $users->pluck('id');
        $friendship = self::friendshipMap($viewer, $ids);
        $sets = self::friendSets($ids->push($viewer->id));
        $mine = $sets[$viewer->id] ?? [];
        $following = DB::table('follows')->where('follower_id', $viewer->id)->whereIn('followee_id', $ids)
            ->pluck('followee_id')->flip();
        $presence = Presence::forUsers($viewer, $users);

        return $users->map(fn (User $u) => PostPresenter::userSummary($u) + $presence[$u->id] + [
            'isFollowing' => $following->has($u->id),
            'mutualFriendsCount' => count(array_intersect_key($mine, $sets[$u->id] ?? [])),
            'friendship' => $friendship[$u->id] ?? ['status' => 'none', 'requestId' => null],
        ])->all();
    }

    public static function followersCount(string $userId): int
    {
        return DB::table('follows')->join('users', 'users.id', '=', 'follows.follower_id')
            ->where('follows.followee_id', $userId)->whereNull('users.deleted_at')->count();
    }

    public static function followingCount(string $userId): int
    {
        return DB::table('follows')->join('users', 'users.id', '=', 'follows.followee_id')
            ->where('follows.follower_id', $userId)->whereNull('users.deleted_at')->count();
    }

    /** The "About" fields of a profile. */
    public static function about(User $user): array
    {
        return [
            'location' => $user->location,
            'hometown' => $user->hometown,
            'workplace' => $user->workplace,
            'education' => $user->education,
            'website' => $user->website,
            'birthday' => $user->birthday?->format('Y-m-d'),
        ];
    }

    public static function profile(User $viewer, User $user): array
    {
        $isSelf = $viewer->id === $user->id;
        $ids = collect([$user->id, $viewer->id]);
        $sets = self::friendSets($ids);
        $friendship = $isSelf
            ? ['status' => 'self', 'requestId' => null]
            : (self::friendshipMap($viewer, collect([$user->id]))[$user->id] ?? ['status' => 'none', 'requestId' => null]);

        return PostPresenter::userSummary($user) + Presence::forUsers($viewer, collect([$user]))[$user->id] + [
            'bio' => $user->bio,
            'coverUrl' => ImageStore::url($user->cover_path),
            'about' => self::about($user),
            'createdAt' => PostPresenter::timestamp($user->created_at),
            'friendsCount' => count($sets[$user->id] ?? []),
            'followersCount' => self::followersCount($user->id),
            'followingCount' => self::followingCount($user->id),
            'isFollowing' => ! $isSelf && Blocks::followedBy($viewer->id, $user->id),
            'followsYou' => ! $isSelf && Blocks::followedBy($user->id, $viewer->id),
            'mutualFriendsCount' => $isSelf ? null : count(array_intersect_key($sets[$viewer->id] ?? [], $sets[$user->id] ?? [])),
            'friendship' => $friendship,
            'isBlocked' => ! $isSelf && Blocks::blockedBy($viewer->id, $user->id),
        ];
    }
}
