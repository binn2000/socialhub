<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('auth_codes', function (Blueprint $table): void {
            $table->id();
            // Same type and collation as users.id, so the foreign key is accepted.
            $table->char('user_id', 26);
            $table->string('purpose', 20)->comment('verify_email | reset_password');
            $table->char('code_hash', 64);
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->timestamp('expires_at');
            $table->timestamp('created_at')->nullable();

            $table->unique(['user_id', 'purpose']);
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('auth_codes');
    }
};
