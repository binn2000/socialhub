<?php

namespace App\Models;

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
        static::deleted(fn (Story $story) => \App\Support\ImageStore::deleteLater($story->image_path));
    }

    protected function casts(): array
    {
        return ['expires_at' => 'datetime'];
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /** Stories $viewer may see: not expired, written by $viewer or by an accepted friend. */
    public function scopeVisibleTo(Builder $query, User $viewer): void
    {
        $query->has('author')->where('expires_at', '>', now())->where(function (Builder $q) use ($viewer) {
            $q->where('user_id', $viewer->id)
                ->orWhereIn('user_id', fn ($s) => $s->select('addressee_id')->from('friendships')
                    ->where('requester_id', $viewer->id)->where('status', 'accepted'))
                ->orWhereIn('user_id', fn ($s) => $s->select('requester_id')->from('friendships')
                    ->where('addressee_id', $viewer->id)->where('status', 'accepted'));
        });
    }
}
