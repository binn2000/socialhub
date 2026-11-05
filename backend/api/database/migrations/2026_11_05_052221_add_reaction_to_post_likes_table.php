<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('post_likes', function (Blueprint $table): void {
            // like | love | haha | wow | sad | angry. Every existing like stays a plain "like".
            // Laravel validation holds the rule (MariaDB 10.1 does not enforce CHECK).
            $table->string('reaction', 8)->default('like');
        });
    }

    public function down(): void
    {
        Schema::table('post_likes', function (Blueprint $table): void {
            $table->dropColumn('reaction');
        });
    }
};
