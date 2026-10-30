<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('cover_path')->nullable()->after('avatar_path');
            $table->string('location', 100)->nullable()->after('bio');
            $table->string('hometown', 100)->nullable()->after('location');
            $table->string('workplace', 100)->nullable()->after('hometown');
            $table->string('education', 100)->nullable()->after('workplace');
            $table->string('website', 200)->nullable()->after('education');
            $table->date('birthday')->nullable()->after('website');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn(['cover_path', 'location', 'hometown', 'workplace', 'education', 'website', 'birthday']);
        });
    }
};
