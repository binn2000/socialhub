<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    use HasUlids;

    const UPDATED_AT = null;

    // messages.created_at is timestamp(3): keep milliseconds so ordering matches the ULID.
    protected $dateFormat = 'Y-m-d H:i:s.v';

    protected $guarded = [];
}
