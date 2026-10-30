<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_blocks', function (Blueprint $table): void {
            $table->id();
            // Same type and collation as users.id, so the foreign keys are accepted.
            $table->char('blocker_id', 26);
            $table->char('blocked_id', 26);
            $table->timestamp('created_at')->nullable();

            $table->unique(['blocker_id', 'blocked_id']);
            $table->index('blocked_id');
            $table->foreign('blocker_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('blocked_id')->references('id')->on('users')->cascadeOnDelete();
        });

        Schema::create('reports', function (Blueprint $table): void {
            $table->char('id', 26)->primary();
            $table->char('reporter_id', 26);
            $table->string('target_type', 10)->comment('post | comment | user');
            $table->char('target_id', 26);
            $table->string('reason', 20);
            $table->string('details', 500)->nullable();
            $table->string('status', 10)->default('open');
            $table->timestamp('created_at')->nullable();

            $table->unique(['reporter_id', 'target_type', 'target_id']);
            $table->foreign('reporter_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reports');
        Schema::dropIfExists('user_blocks');
    }
};
