<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BlockController;
use App\Http\Controllers\Api\CommentController;
use App\Http\Controllers\Api\ConversationController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\ExploreController;
use App\Http\Controllers\Api\FollowController;
use App\Http\Controllers\Api\FriendController;
use App\Http\Controllers\Api\MeController;
use App\Http\Controllers\Api\MusicController;
use App\Http\Controllers\Api\NoteController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\PostController;
use App\Http\Controllers\Api\PostInteractionController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\StoryController;
use App\Http\Controllers\Api\UserController;
use App\Http\Middleware\TouchLastSeen;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('auth/register', [AuthController::class, 'register'])->middleware('throttle:register');
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:login');
    Route::post('auth/password/forgot', [AuthController::class, 'forgotPassword'])->middleware('throttle:password-forgot');
    Route::post('auth/password/reset', [AuthController::class, 'resetPassword'])->middleware('throttle:password-reset');

    Route::middleware(['auth:sanctum', TouchLastSeen::class, 'throttle:api'])->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::post('auth/email/verification', [AuthController::class, 'sendEmailVerification'])->middleware('throttle:email-code');
        Route::post('auth/email/verify', [AuthController::class, 'verifyEmail'])->middleware('throttle:email-verify');
        Route::delete('me', [MeController::class, 'destroy']);
        Route::get('me', [MeController::class, 'show']);
        Route::patch('me', [MeController::class, 'update']);
        Route::put('me/devices', [DeviceController::class, 'store']);
        Route::delete('me/devices', [DeviceController::class, 'destroy']);
        Route::post('me/avatar', [MeController::class, 'setAvatar'])->middleware('throttle:uploads');
        Route::delete('me/avatar', [MeController::class, 'removeAvatar']);
        Route::put('me/note', [NoteController::class, 'store'])->middleware('throttle:notes');
        Route::delete('me/note', [NoteController::class, 'destroy']);
        Route::get('notes', [NoteController::class, 'index']);
        Route::get('music/search', [MusicController::class, 'search'])->middleware('throttle:music');
        Route::post('me/presence', [MeController::class, 'presence']);
        Route::post('me/cover', [MeController::class, 'setCover'])->middleware('throttle:uploads');
        Route::delete('me/cover', [MeController::class, 'removeCover']);
        Route::get('me/saved-posts', [PostController::class, 'saved']);

        Route::get('me/blocks', [BlockController::class, 'index']);
        Route::post('reports', [ReportController::class, 'store'])->middleware('throttle:reports');
        Route::put('users/{user}/follow', [FollowController::class, 'store'])->middleware('throttle:friend-requests');
        Route::delete('users/{user}/follow', [FollowController::class, 'destroy']);
        Route::get('users/{user}/followers', [UserController::class, 'followers']);
        Route::get('users/{user}/following', [UserController::class, 'following']);
        Route::put('users/{user}/block', [BlockController::class, 'store'])->middleware('throttle:friend-requests');
        Route::delete('users/{user}/block', [BlockController::class, 'destroy']);

        Route::get('users', [UserController::class, 'index'])->middleware('throttle:search');
        Route::get('users/suggestions', [UserController::class, 'suggestions'])->middleware('throttle:search');
        Route::get('users/{user}', [UserController::class, 'show']);
        Route::get('users/{user}/posts', [UserController::class, 'posts']);
        Route::get('users/{user}/friends', [UserController::class, 'friends']);
        Route::get('users/{user}/photos', [UserController::class, 'photos']);

        Route::get('friend-requests', [FriendController::class, 'index']);
        Route::post('friend-requests', [FriendController::class, 'store'])->middleware('throttle:friend-requests');
        Route::post('friend-requests/{friendRequest}/accept', [FriendController::class, 'accept']);
        Route::delete('friend-requests/{friendRequest}', [FriendController::class, 'destroy']);
        Route::delete('friends/{user}', [FriendController::class, 'unfriend']);

        Route::get('explore', [ExploreController::class, 'index'])->middleware('throttle:search');
        Route::post('posts/{post}/shares', [PostInteractionController::class, 'share'])->middleware('throttle:reactions');
        Route::get('posts/{post}/comments', [CommentController::class, 'index']);
        Route::post('posts/{post}/comments', [CommentController::class, 'store'])->middleware(['throttle:comments', 'idempotent']);
        Route::delete('comments/{comment}', [CommentController::class, 'destroy']);

        Route::get('notifications', [NotificationController::class, 'index']);
        Route::get('notifications/unread-count', [NotificationController::class, 'unreadCount']);
        Route::post('notifications/read', [NotificationController::class, 'readAll']);
        Route::post('notifications/{notification}/read', [NotificationController::class, 'read']);

        Route::get('conversations', [ConversationController::class, 'index']);
        Route::post('conversations', [ConversationController::class, 'store']);
        Route::get('conversations/{conversation}/messages', [ConversationController::class, 'messages']);
        Route::post('conversations/{conversation}/messages', [ConversationController::class, 'send'])->middleware(['throttle:messages', 'idempotent']);
        Route::put('conversations/{conversation}/typing', [ConversationController::class, 'typing']);
        Route::delete('conversations/{conversation}/typing', [ConversationController::class, 'stopTyping']);
        Route::put('conversations/{conversation}/theme', [ConversationController::class, 'setTheme'])->middleware('throttle:reactions');
        Route::get('conversations/{conversation}/media', [ConversationController::class, 'media']);
        Route::put('conversations/{conversation}/pin', [ConversationController::class, 'pin'])->middleware('throttle:reactions');
        Route::delete('conversations/{conversation}/pin', [ConversationController::class, 'unpin'])->middleware('throttle:reactions');
        Route::post('conversations/{conversation}/read', [ConversationController::class, 'read']);
        Route::put('conversations/{conversation}/messages/{message}/reaction', [ConversationController::class, 'react'])->middleware('throttle:reactions');
        Route::delete('conversations/{conversation}/messages/{message}/reaction', [ConversationController::class, 'unreact'])->middleware('throttle:reactions');
        Route::delete('conversations/{conversation}/messages/{message}', [ConversationController::class, 'recall'])->middleware('throttle:reactions');
        Route::put('conversations/{conversation}/messages/{message}/hide', [ConversationController::class, 'hide'])->middleware('throttle:reactions');

        Route::get('stories', [StoryController::class, 'index']);
        Route::post('stories', [StoryController::class, 'store'])->middleware(['throttle:stories', 'idempotent']);
        Route::patch('stories/{story}', [StoryController::class, 'update']);
        Route::delete('stories/{story}', [StoryController::class, 'destroy']);
        Route::get('users/{user}/stories', [StoryController::class, 'forUser']);
        Route::post('stories/{story}/view', [StoryController::class, 'view']);

        Route::get('feed', [PostController::class, 'feed']);
        Route::post('posts', [PostController::class, 'store'])->middleware(['throttle:posts', 'idempotent']);
        Route::get('posts/{post}', [PostController::class, 'show']);
        Route::patch('posts/{post}', [PostController::class, 'update']);
        Route::delete('posts/{post}', [PostController::class, 'destroy']);

        Route::put('posts/{post}/like', [PostInteractionController::class, 'like'])->middleware('throttle:reactions');
        Route::delete('posts/{post}/like', [PostInteractionController::class, 'unlike'])->middleware('throttle:reactions');
        Route::put('posts/{post}/save', [PostInteractionController::class, 'save'])->middleware('throttle:reactions');
        Route::delete('posts/{post}/save', [PostInteractionController::class, 'unsave'])->middleware('throttle:reactions');
        Route::put('posts/{post}/hide', [PostInteractionController::class, 'hide'])->middleware('throttle:reactions');
        Route::delete('posts/{post}/hide', [PostInteractionController::class, 'unhide'])->middleware('throttle:reactions');
    });
});
