<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Friendship extends Model
{
    use HasUlids;

    protected $guarded = [];

    /**
     * Keeps the pair columns in step with the two users, whichever of them asked. The
     * unique (user_low_id, user_high_id) index then allows one row per pair.
     */
    protected static function booted(): void
    {
        static::creating(function (Friendship $friendship): void {
            $friendship->user_low_id = min($friendship->requester_id, $friendship->addressee_id);
            $friendship->user_high_id = max($friendship->requester_id, $friendship->addressee_id);
        });
    }

    protected function casts(): array
    {
        return ['accepted_at' => 'datetime'];
    }

    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    public function addressee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'addressee_id');
    }
}
