<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /** Friends follow each other, as new friends now do when a request is accepted. */
    public function up(): void
    {
        foreach ([['requester_id', 'addressee_id'], ['addressee_id', 'requester_id']] as [$follower, $followee]) {
            // INSERT IGNORE keeps the follows that already exist (unique follower/followee pair).
            DB::statement("insert ignore into follows (follower_id, followee_id, created_at)
                select {$follower}, {$followee}, coalesce(accepted_at, now()) from friendships where status = 'accepted'");
        }
    }

    public function down(): void
    {
        // The follows cannot be told apart from the ones people made themselves, so none are removed.
    }
};
