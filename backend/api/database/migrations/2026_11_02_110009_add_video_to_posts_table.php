<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('posts', function (Blueprint $table): void {
            // 'processing' | 'ready' | 'failed'; null for posts without a video. Laravel
            // validation holds the rule (MariaDB 10.1 does not enforce CHECK).
            $table->string('video_status', 12)->nullable();
            // The upload as sent, kept only until the queue job has converted it.
            $table->string('video_source_path')->nullable();
            $table->string('video_path')->nullable();
            $table->string('video_thumb_path')->nullable();
            $table->unsignedSmallInteger('video_duration')->nullable();
            $table->unsignedSmallInteger('video_width')->nullable();
            $table->unsignedSmallInteger('video_height')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('posts', function (Blueprint $table): void {
            $table->dropColumn([
                'video_status', 'video_source_path', 'video_path', 'video_thumb_path',
                'video_duration', 'video_width', 'video_height',
            ]);
        });
    }
};
