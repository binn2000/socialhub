<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Existing notes and stories were only for friends, which is still the default.
        foreach (['notes', 'stories'] as $name) {
            Schema::table($name, function (Blueprint $table): void {
                $table->string('privacy', 10)->default('friends');
            });
        }
    }

    public function down(): void
    {
        foreach (['notes', 'stories'] as $name) {
            Schema::table($name, function (Blueprint $table): void {
                $table->dropColumn('privacy');
            });
        }
    }
};
