<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('conversation_participants', function (Blueprint $table): void {
            // The newest message this person's app has fetched ("Đã nhận"); last_read_message_id is "Đã xem".
            $table->char('last_delivered_message_id', 26)->nullable();
        });

        Schema::table('conversations', function (Blueprint $table): void {
            // One pinned message per conversation, for both people.
            $table->char('pinned_message_id', 26)->nullable();
            $table->foreign('pinned_message_id')->references('id')->on('messages')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('conversations', function (Blueprint $table): void {
            $table->dropForeign(['pinned_message_id']);
            $table->dropColumn('pinned_message_id');
        });
        Schema::table('conversation_participants', function (Blueprint $table): void {
            $table->dropColumn('last_delivered_message_id');
        });
    }
};
