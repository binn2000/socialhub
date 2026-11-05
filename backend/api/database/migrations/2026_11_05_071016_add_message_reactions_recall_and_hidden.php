<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table): void {
            // Set when the sender takes the message back; the text and files are gone for both people.
            $table->timestamp('recalled_at')->nullable();
        });

        // One reaction per person and message (changing it replaces the row).
        Schema::create('message_reactions', function (Blueprint $table): void {
            $table->char('message_id', 26);
            $table->char('user_id', 26);
            $table->string('emoji', 16);
            $table->timestamp('created_at')->nullable();
            $table->primary(['message_id', 'user_id']);
            $table->foreign('message_id')->references('id')->on('messages')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });

        // "Xóa ở phía tôi": the message stays for the other person.
        Schema::create('message_hidden', function (Blueprint $table): void {
            $table->char('message_id', 26);
            $table->char('user_id', 26);
            $table->timestamp('created_at')->nullable();
            $table->primary(['message_id', 'user_id']);
            $table->foreign('message_id')->references('id')->on('messages')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('message_hidden');
        Schema::dropIfExists('message_reactions');
        Schema::table('messages', function (Blueprint $table): void {
            $table->dropColumn('recalled_at');
        });
    }
};
