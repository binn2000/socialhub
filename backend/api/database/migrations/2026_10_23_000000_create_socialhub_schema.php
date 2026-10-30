<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// The schema is hand-written SQL (database/schema.sql) because it relies on MariaDB 10.1
// specifics: ROW_FORMAT=DYNAMIC and PERSISTENT generated columns.
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('users')) {
            return; // already imported by hand
        }

        // schema.sql also creates/selects `socialhub` for manual imports; skip that so the
        // migration builds in whichever database the connection points at (e.g. socialhub_test).
        $sql = preg_replace('/^(CREATE DATABASE|USE)\b[^;]*;/mi', '', file_get_contents(database_path('schema.sql')));

        DB::unprepared($sql);
    }

    public function down(): void
    {
        Schema::disableForeignKeyConstraints();
        foreach ([
            'idempotency_keys', 'notifications', 'conversation_participants', 'messages',
            'conversations', 'story_views', 'stories', 'comments', 'post_shares', 'post_hidden',
            'post_saves', 'post_likes', 'posts', 'friendships', 'personal_access_tokens', 'users',
        ] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::enableForeignKeyConstraints();
    }
};
