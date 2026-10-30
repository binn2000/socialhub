<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

// Databases created from the first version of schema.sql have user_low_id / user_high_id as
// generated columns, which MariaDB 10.2+ cannot create. Turn them into plain columns that the
// app fills in, keeping the data and the indexes. A database made from the current schema.sql
// already has plain columns, so this does nothing there.
return new class extends Migration
{
    public function up(): void
    {
        $generated = DB::selectOne(
            "select count(*) as n from information_schema.columns
             where table_schema = database() and table_name = 'friendships'
               and column_name in ('user_low_id', 'user_high_id')
               and (extra like '%GENERATED%' or extra like '%PERSISTENT%' or extra like '%STORED%' or extra like '%VIRTUAL%')"
        )->n;

        if ((int) $generated === 0) {
            return;
        }

        DB::unprepared('
            ALTER TABLE friendships
              DROP INDEX friendships_pair_unique,
              DROP INDEX friendships_low_status_index,
              DROP INDEX friendships_high_status_index
        ');
        DB::unprepared('ALTER TABLE friendships DROP COLUMN user_low_id, DROP COLUMN user_high_id');
        DB::unprepared('
            ALTER TABLE friendships
              ADD COLUMN user_low_id char(26) NULL AFTER addressee_id,
              ADD COLUMN user_high_id char(26) NULL AFTER user_low_id
        ');
        DB::unprepared('
            UPDATE friendships
               SET user_low_id = IF(requester_id < addressee_id, requester_id, addressee_id),
                   user_high_id = IF(requester_id < addressee_id, addressee_id, requester_id)
        ');
        DB::unprepared('
            ALTER TABLE friendships
              MODIFY user_low_id char(26) NOT NULL,
              MODIFY user_high_id char(26) NOT NULL,
              ADD UNIQUE KEY friendships_pair_unique (user_low_id, user_high_id),
              ADD KEY friendships_low_status_index (user_low_id, status),
              ADD KEY friendships_high_status_index (user_high_id, status)
        ');
    }

    public function down(): void
    {
        // Not reversible: the generated-column version does not work on current MariaDB.
    }
};
