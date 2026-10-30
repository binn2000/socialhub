<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('follows', function (Blueprint $table): void {
            $table->id();
            $table->char('follower_id', 26);
            $table->char('followee_id', 26);
            $table->timestamp('created_at')->nullable();

            $table->unique(['follower_id', 'followee_id']);
            $table->index('followee_id');
            $table->foreign('follower_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('followee_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('follows');
    }
};
