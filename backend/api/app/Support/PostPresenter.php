<?php

namespace App\Support;

use App\Models\Post;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class PostPresenter
{
    public static function timestamp($date): string
    {
        return $date->utc()->format('Y-m-d\TH:i:s\Z');
    }

    public static function userSummary(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'avatarUrl' => \App\Support\ImageStore::url($user->avatar_path),
        ];
    }

    /** Presents posts with the viewer's own like/save/hide flags, using one query per flag. */
    public static function many(Collection $posts, User $viewer): array
    {
        $posts->loadMissing('author');
        $ids = $posts->pluck('id');
        $flag = fn (string $table) => DB::table($table)->where('user_id', $viewer->id)
            ->whereIn('post_id', $ids)->pluck('post_id')->flip();
        $liked = $flag('post_likes');
        $saved = $flag('post_saves');
        $hidden = $flag('post_hidden');
        $images = DB::table('post_images')->whereIn('post_id', $ids)->orderBy('position')->orderBy('id')->get()
            ->groupBy('post_id');

        return $posts->map(fn (Post $p) => [
            'id' => $p->id,
            'author' => self::userSummary($p->author),
            'content' => $p->content ?? '',
            'imageUrl' => \App\Support\ImageStore::url($p->image_path),
            'imageUrls' => ($images[$p->id] ?? collect())->map(fn ($i) => \App\Support\ImageStore::url($i->path))->values()->all(),
            'feeling' => $p->feeling,
            'privacy' => $p->privacy,
            'createdAt' => self::timestamp($p->created_at),
            'likes' => $p->likes_count,
            'comments' => $p->comments_count,
            'shares' => $p->shares_count,
            'isLiked' => $liked->has($p->id),
            'isSaved' => $saved->has($p->id),
            'isHidden' => $hidden->has($p->id),
        ])->all();
    }

    public static function one(Post $post, User $viewer): array
    {
        return self::many(new Collection([$post]), $viewer)[0];
    }
}
