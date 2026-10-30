<?php

namespace App\Jobs;

use App\Support\ImageStore;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Removes an uploaded image file after its post, story or avatar is gone.
 */
class DeleteStoredImage implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    /** @var list<int> seconds to wait before each retry */
    public array $backoff = [10, 60];

    public function __construct(public string $path)
    {
    }

    public function handle(): void
    {
        ImageStore::delete($this->path);
    }
}
