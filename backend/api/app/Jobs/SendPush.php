<?php

namespace App\Jobs;

use App\Support\PushSender;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/** Pushes one message to all phones of a user. Runs on the queue, like notifications. */
class SendPush implements ShouldQueue
{
    use Queueable;

    public int $tries = 2;

    /** @var list<int> */
    public array $backoff = [10];

    /** @param array<string, scalar|null> $data */
    public function __construct(
        public string $userId,
        public string $title,
        public string $body,
        public array $data = [],
    ) {
    }

    public function handle(): void
    {
        PushSender::sendToUser($this->userId, $this->title, $this->body, $this->data);
    }
}
