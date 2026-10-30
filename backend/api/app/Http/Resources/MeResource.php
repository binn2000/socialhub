<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\DB;

/** @mixin User */
class MeResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'username' => $this->username,
            'avatarUrl' => \App\Support\ImageStore::url($this->avatar_path),
            'email' => $this->email,
            'emailVerified' => $this->email_verified_at !== null,
            'bio' => $this->bio,
            'coverUrl' => \App\Support\ImageStore::url($this->cover_path),
            'about' => \App\Support\UserPresenter::about($this->resource),
            'showOnlineStatus' => (bool) $this->show_online_status,
            'followersCount' => \App\Support\UserPresenter::followersCount($this->id),
            'followingCount' => \App\Support\UserPresenter::followingCount($this->id),
            'friendsCount' => DB::table('friendships')
                ->where('status', 'accepted')
                ->where(fn ($q) => $q->where('requester_id', $this->id)->orWhere('addressee_id', $this->id))
                ->count(),
            'createdAt' => $this->created_at->utc()->format('Y-m-d\TH:i:s\Z'),
        ];
    }
}
