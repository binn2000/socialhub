<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('message_attachments', function (Blueprint $table): void {
            $table->id();
            $table->char('message_id', 26);
            $table->string('type', 10)->comment('image | file');
            $table->string('path');
            $table->string('name');
            $table->string('mime_type', 100);
            $table->unsignedInteger('size_bytes');
            $table->unsignedSmallInteger('width')->nullable();
            $table->unsignedSmallInteger('height')->nullable();
            $table->timestamp('created_at')->nullable();

            $table->index('message_id');
            $table->foreign('message_id')->references('id')->on('messages')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('message_attachments');
    }
};
