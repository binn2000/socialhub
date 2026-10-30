<?php

namespace App\Models;

use App\Support\Blocks;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\DB;

#[Fillable(['user_id', 'content', 'image_path', 'feeling', 'privacy'])]
class Post extends Model
{
    use HasUlids, SoftDeletes;

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Restricts $query's user_id to accepted friends of $userId. Two IN subqueries instead of
     * one UNION: MariaDB 10.1 rejects a parenthesised UNION inside IN().
     */
    private static function byFriendOf(Builder $query, string $userId): void
    {
        $query->where(function (Builder $q) use ($userId) {
            $q->whereIn('user_id', fn ($s) => $s->select('addressee_id')->from('friendships')
                ->where('requester_id', $userId)->where('status', 'accepted'))
                ->orWhereIn('user_id', fn ($s) => $s->select('requester_id')->from('friendships')
                    ->where('addressee_id', $userId)->where('status', 'accepted'));
        });
    }

    /** Posts $viewer may see: own, public, or friends-only from an accepted friend. */
    public function scopeVisibleTo(Builder $query, User $viewer): void
    {
        $query->has('author')->where(function (Builder $q) use ($viewer) {
            $q->where('user_id', $viewer->id)
                ->orWhere('privacy', 'public')
                ->orWhere(function (Builder $f) use ($viewer) {
                    $f->where('privacy', 'friends');
                    self::byFriendOf($f, $viewer->id);
                });
        });
        Blocks::exclude($query, $viewer->id, 'posts.user_id');
    }

    /** The home feed: own posts plus visible posts of friends, minus what $viewer hid. */
    public function scopeFeedFor(Builder $query, User $viewer): void
    {
        $query->has('author')
            ->where(function (Builder $q) use ($viewer) {
                $q->where('user_id', $viewer->id)
                    ->orWhere(function (Builder $f) use ($viewer) {
                        $f->whereIn('privacy', ['public', 'friends']);
                        self::byFriendOf($f, $viewer->id);
                    })
                    // People the viewer follows: their public posts only.
                    ->orWhere(fn (Builder $f) => $f->where('privacy', 'public')
                        ->whereIn('user_id', fn ($s) => $s->select('followee_id')->from('follows')->where('follower_id', $viewer->id)));
            })
            ->whereNotExists(fn ($h) => $h->select(DB::raw(1))->from('post_hidden')
                ->whereColumn('post_hidden.post_id', 'posts.id')->where('post_hidden.user_id', $viewer->id));
        Blocks::exclude($query, $viewer->id, 'posts.user_id');
    }

    /** Narrows to posts of accepted friends of $viewer. */
    public function scopeFromFriends(Builder $query, User $viewer): void
    {
        self::byFriendOf($query, $viewer->id);
    }

    /** Search box: content or author name contains $q (accent-insensitive by collation; % and _ are literal). */
    public function scopeMatching(Builder $query, string $q): void
    {
        if ($q === '') {
            return;
        }

        $like = '%'.addcslashes($q, '\\%_').'%';
        $query->where(fn (Builder $w) => $w->where('content', 'like', $like)
            ->orWhereHas('author', fn ($a) => $a->where('name', 'like', $like)));
    }
}
