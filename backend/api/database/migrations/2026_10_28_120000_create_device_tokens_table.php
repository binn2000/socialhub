<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_tokens', function (Blueprint $table): void {
            $table->id();
            // Same type and collation as users.id, so the foreign key is accepted.
            $table->char('user_id', 26);
            // The push token is long, so the unique index is on its hash.
            $table->char('token_hash', 64)->unique();
            $table->string('token', 512);
            $table->string('platform', 10)->comment('ios | android');
            $table->timestamps();

            $table->index('user_id');
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_tokens');
    }
};
