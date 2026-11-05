<?php

namespace App\Jobs;

use App\Http\Controllers\Api\PostInteractionController;
use App\Models\Comment;
use App\Models\Post;
use App\Models\User;
use App\Support\Blocks;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Writes one notification row. Runs on the queue, so it can arrive a few seconds
 * after the action that caused it (as the API contract says).
 */
class CreateNotification implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    /** @var list<int> seconds to wait before each retry */
    public array $backoff = [5, 30];

    /**
     * @param  string  $type  like | comment | share | friend_request | friend_accepted
     * @param  string|null  $dedupeKey  a second job with the same key does nothing (unique index)
     */
    public function __construct(
        public string $recipientId,
        public string $actorId,
        public string $type,
        public ?string $postId = null,
        public ?string $commentId = null,
        public ?string $friendshipId = null,
        public ?string $dedupeKey = null,
    ) {}

    public function handle(): void
    {
        if ($this->recipientId === $this->actorId || Blocks::either($this->recipientId, $this->actorId)) {
            return;
        }

        // The target may have been deleted while this job waited in the queue.
        if ($this->postId !== null && ! Post::whereKey($this->postId)->exists()) {
            return;
        }
        if ($this->commentId !== null && ! Comment::whereKey($this->commentId)->exists()) {
            return;
        }

        $inserted = DB::table('notifications')->insertOrIgnore([
            'id' => strtolower((string) Str::ulid()),
            'user_id' => $this->recipientId,
            'actor_id' => $this->actorId,
            'type' => $this->type,
            'post_id' => $this->postId,
            'comment_id' => $this->commentId,
            'friendship_id' => $this->friendshipId,
            'dedupe_key' => $this->dedupeKey,
            'created_at' => now(),
        ]);

        // insertOrIgnore skips a duplicate; only a new notification is pushed.
        if ($inserted > 0) {
            $this->push();
        }
    }

    private function push(): void
    {
        $actor = User::find($this->actorId);
        if (! $actor) {
            return;
        }

        $what = match ($this->type) {
            'like' => $this->likeText(),
            'comment' => 'đã bình luận bài viết của bạn',
            'share' => 'đã chia sẻ bài viết của bạn',
            'friend_request' => 'đã gửi lời mời kết bạn',
            'friend_accepted' => 'đã chấp nhận lời mời kết bạn',
            'follow' => 'đã bắt đầu theo dõi bạn',
            default => null,
        };
        if ($what === null) {
            return;
        }

        SendPush::dispatch($this->recipientId, 'SocialHub', "{$actor->name} {$what}", [
            'type' => $this->type,
            'actorId' => $this->actorId,
            'postId' => $this->postId,
        ]);
    }

    /** "đã thích bài viết của bạn", or the reaction that was left (read now, it may have changed while queued). */
    private function likeText(): string
    {
        $reaction = DB::table('post_likes')->where('post_id', $this->postId)->where('user_id', $this->actorId)->value('reaction');

        return in_array($reaction, [null, 'like'], true)
            ? 'đã thích bài viết của bạn'
            : 'đã bày tỏ cảm xúc '.PostInteractionController::REACTION_EMOJIS[$reaction].' về bài viết của bạn';
    }
}
