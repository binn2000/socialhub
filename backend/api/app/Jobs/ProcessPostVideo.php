<?php

namespace App\Jobs;

use App\Models\Post;
use App\Support\VideoStore;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Throwable;

/**
 * Converts the video of a new post and marks the post ready (or failed). Until then only
 * the author sees the post.
 */
class ProcessPostVideo implements ShouldQueue
{
    use Queueable;

    public int $tries = 1;

    public int $timeout = 300;

    public function __construct(public string $postId) {}

    public function handle(): void
    {
        $post = Post::withTrashed()->find($this->postId);

        if (! $post || $post->video_status !== 'processing' || ! $post->video_source_path) {
            VideoStore::delete($post?->video_source_path);

            return;
        }

        $source = $post->video_source_path;

        if ($post->trashed()) {
            VideoStore::delete($source);

            return;
        }

        $result = VideoStore::convert($source);
        $post->forceFill([
            'video_status' => 'ready',
            'video_source_path' => null,
            'video_path' => $result['video'],
            'video_thumb_path' => $result['thumbnail'],
            'video_width' => $result['width'],
            'video_height' => $result['height'],
            'video_duration' => $result['duration'],
        ])->save();
        VideoStore::delete($source);
    }

    public function failed(?Throwable $exception): void
    {
        $post = Post::withTrashed()->find($this->postId);

        if ($post) {
            VideoStore::delete($post->video_source_path);
            $post->forceFill(['video_status' => 'failed', 'video_source_path' => null])->save();
        }
    }
}
