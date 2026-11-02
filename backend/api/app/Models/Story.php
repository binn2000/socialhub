<?php

namespace App\Models;

use App\Support\Blocks;
use App\Support\ImageStore;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Story extends Model
{
    use HasUlids;

    protected $guarded = [];

    protected static function booted(): void
    {
        static::deleted(fn (Story $story) => ImageStore::deleteLater($story->image_path));
    }

    protected function casts(): array
    {
        return ['expires_at' => 'datetime'];
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Stories $viewer may see: not expired, and their own; `friends` and `public` ones of an accepted
     * friend; `public` ones of anyone (people who blocked each other excluded).
     */
    public function scopeVisibleTo(Builder $query, User $viewer): void
    {
        $query->has('author')->where('expires_at', '>', now())->where(function (Builder $q) use ($viewer) {
            $q->where('user_id', $viewer->id)
                ->orWhere('privacy', 'public')
                ->orWhere(fn (Builder $f) => $f->where('privacy', 'friends')->where(fn ($w) => $w
                    ->whereIn('user_id', fn ($s) => $s->select('addressee_id')->from('friendships')
                        ->where('requester_id', $viewer->id)->where('status', 'accepted'))
                    ->orWhereIn('user_id', fn ($s) => $s->select('requester_id')->from('friendships')
                        ->where('addressee_id', $viewer->id)->where('status', 'accepted'))));
        });
        Blocks::exclude($query, $viewer->id, 'stories.user_id');
    }

    /**
     * The stories tray: what $viewer may see from themself, their friends and the people they follow.
     * (A stranger's public story is not in the tray; it opens from that person's profile.)
     */
    public function scopeInTrayOf(Builder $query, User $viewer): void
    {
        $query->visibleTo($viewer)->where(function (Builder $q) use ($viewer) {
            $q->where('user_id', $viewer->id)
                ->orWhereIn('user_id', fn ($s) => $s->select('followee_id')->from('follows')->where('follower_id', $viewer->id))
                ->orWhereIn('user_id', fn ($s) => $s->select('addressee_id')->from('friendships')
                    ->where('requester_id', $viewer->id)->where('status', 'accepted'))
                ->orWhereIn('user_id', fn ($s) => $s->select('requester_id')->from('friendships')
                    ->where('addressee_id', $viewer->id)->where('status', 'accepted'));
        });
    }
}
