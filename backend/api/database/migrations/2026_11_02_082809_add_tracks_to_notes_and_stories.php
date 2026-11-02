<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /** @var list<string> */
    private array $tables = ['notes', 'stories'];

    public function up(): void
    {
        foreach ($this->tables as $name) {
            Schema::table($name, function (Blueprint $table): void {
                $table->string('track_id', 20)->nullable();
                $table->string('track_title', 200)->nullable();
                $table->string('track_artist', 200)->nullable();
                $table->string('track_artwork_url', 500)->nullable();
                $table->string('track_preview_url', 500)->nullable();
                $table->string('track_apple_url', 500)->nullable();
                $table->string('track_spotify_url', 500)->nullable();
            });
        }

        // A note can be only a song.
        Schema::table('notes', function (Blueprint $table): void {
            $table->string('text', 60)->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('notes', function (Blueprint $table): void {
            $table->string('text', 60)->nullable(false)->change();
        });

        foreach ($this->tables as $name) {
            Schema::table($name, function (Blueprint $table): void {
                $table->dropColumn([
                    'track_id', 'track_title', 'track_artist', 'track_artwork_url',
                    'track_preview_url', 'track_apple_url', 'track_spotify_url',
                ]);
            });
        }
    }
};
