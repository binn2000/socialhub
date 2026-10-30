<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Support\ImageStore;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class PurgeDeletedAccounts extends Command
{
    protected $signature = 'accounts:purge-deleted {--days=30 : Keep a deleted account this long first}';

    protected $description = 'Permanently delete accounts that were deleted more than --days ago';

    public function handle(): int
    {
        $purged = 0;

        User::onlyTrashed()->where('deleted_at', '<', now()->subDays((int) $this->option('days')))
            ->each(function (User $user) use (&$purged): void {
                $this->purge($user);
                $purged++;
            });

        $this->info("Purged {$purged} accounts.");

        return self::SUCCESS;
    }

    private function purge(User $user): void
    {
        $paths = collect([$user->avatar_path, $user->cover_path])
            ->merge(DB::table('posts')->where('user_id', $user->id)->pluck('image_path'))
            ->merge(DB::table('post_images')->whereIn('post_id', DB::table('posts')->where('user_id', $user->id)->select('id'))->pluck('path'))
            ->merge(DB::table('message_attachments')->whereIn('message_id', DB::table('messages')->where('sender_id', $user->id)->select('id'))->pluck('path'))
            ->merge(DB::table('stories')->where('user_id', $user->id)->pluck('image_path'))
            ->filter()->unique();

        // Posts of other people that this user liked, commented on or shared: their
        // counters drop when the rows go, so they are recounted afterwards.
        $affected = collect(['post_likes', 'post_shares', 'comments'])
            ->flatMap(fn (string $table) => DB::table($table)->where('user_id', $user->id)->pluck('post_id'))
            ->unique()->values();

        // The foreign keys remove everything that belongs to the user.
        DB::transaction(fn () => $user->forceDelete());

        foreach ($paths as $path) {
            ImageStore::deleteLater($path);
        }

        foreach ($affected->chunk(200) as $ids) {
            DB::table('posts')->whereIn('id', $ids)->update([
                'likes_count' => DB::raw('(select count(*) from post_likes where post_likes.post_id = posts.id)'),
                'shares_count' => DB::raw('(select count(*) from post_shares where post_shares.post_id = posts.id)'),
                'comments_count' => DB::raw('(select count(*) from comments where comments.post_id = posts.id and comments.deleted_at is null)'),
            ]);
        }
    }
}
