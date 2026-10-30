<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('post_images', function (Blueprint $table): void {
            $table->id();
            // Same type and collation as posts.id, so the foreign key is accepted.
            $table->char('post_id', 26);
            $table->string('path');
            $table->unsignedTinyInteger('position')->default(0);
            $table->timestamp('created_at')->nullable();

            $table->index(['post_id', 'position']);
            $table->foreign('post_id')->references('id')->on('posts')->cascadeOnDelete();
        });

        // Posts that already have an image get it as their first (and only) one.
        DB::statement('insert into post_images (post_id, path, position, created_at)
            select id, image_path, 0, created_at from posts where image_path is not null order by created_at, id');
    }

    public function down(): void
    {
        Schema::dropIfExists('post_images');
    }
};
