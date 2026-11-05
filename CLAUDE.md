# CLAUDE.md

Guidance for AI assistants and developers working in this repository. Everything here was checked against the source; items marked **Proposed** are recommendations, not current conventions.

## 1. Project overview

**SocialHub** is a Flutter social-network UI MVP (Vietnamese UI). It is a **learning project**: frontend only, mock data, no backend, no auth, no persistence. Keeping the code simple and beginner-readable is a core requirement (see `.github/copilot-instructions.md` §3, §27).

- Stack: Flutter (Material 3) / Dart `^3.11.1`. Dependencies: `flutter`, `dio` (HTTP), `flutter_secure_storage` (token), `image_picker` (avatar photo), `firebase_core` + `firebase_messaging` (push), `just_audio` (song previews), `video_player` (post videos), `video_compress` (shrinks a picked video on the phone), `youtube_player_iframe` (YouTube's embedded player for the Video tab); dev: `flutter_test`, `flutter_lints`. `pubspec.lock` is checked in.
- Platforms present: `android/`, `ios/` (design target: iPhone 17 Pro).
- Architecture: **one `StatefulWidget` (`MainScreen` in `lib/main.dart`) owns all mutable app state via `setState`.** Screens are given data and callbacks through constructors. `lib/data/mock_data.dart` is the *initial seed only*.
- **Backend (started):** `backend/api` is a Laravel 13 project (run it with PHP 8.5: `/opt/homebrew/opt/php@8.5/bin/php`; the default `php` is 7.4) connected to the `socialhub` database in Homebrew MariaDB 10.11 on port 3307 (started with `backend/run-mariadb.sh`; its data is in `/opt/homebrew/var/mariadb-socialhub`, admin = the OS user through the socket `/tmp/socialhub-mariadb.sock`; XAMPP's MariaDB 10.1.38 on 3306 still holds the old copy and the user's other projects, so leave it alone), with Sanctum installed and the `User` model on ULIDs. The tables come from `backend/api/database/schema.sql`. Implemented endpoints: `POST /auth/register`, `/auth/login`, `/auth/logout`, `GET/PATCH /me`, `POST/DELETE /me/avatar`, `GET /me/saved-posts`, `GET/POST /stories`, `DELETE /stories/{id}`, `POST /stories/{id}/view`, `GET/POST /conversations`, `GET/POST /conversations/{id}/messages`, `POST /conversations/{id}/read`, `PUT /conversations/{id}/theme`, `PUT /conversations/{id}/quick-reaction`, `GET /videos/search`, `GET /conversations/{id}/media`, `GET /notifications`, `GET /notifications/unread-count`, `POST /notifications/read`, `POST /notifications/{id}/read`, `POST /auth/email/verification`, `POST /auth/email/verify`, `POST /auth/password/forgot`, `POST /auth/password/reset`, `DELETE /me` (account deletion), `POST/DELETE /me/cover`, `GET /users/suggestions`, `GET /users/{user}/friends`, `GET /users/{user}/photos`, `PUT/DELETE /users/{user}/block`, `GET /me/blocks`, `POST /reports`, `PATCH /posts/{post}` (privacy only), `GET /explore`, `POST /posts/{post}/shares`, `GET/POST /posts/{post}/comments`, `DELETE /comments/{comment}`, `GET /users`, `GET /users/{user}`, `GET /users/{user}/posts`, `GET/POST /friend-requests`, `POST /friend-requests/{id}/accept`, `DELETE /friend-requests/{id}`, `DELETE /friends/{user}`, `GET /feed`, `POST /posts`, `GET/DELETE /posts/{post}`, `PUT/DELETE /posts/{post}/like|save|hide` (images upload as multipart to `POST /posts`, `POST /stories`, `POST /me/avatar` and are re-encoded onto the `public` disk, which needs `artisan storage:link`; PHP's default `upload_max_filesize` of 2M must be raised to 10M to match the contract; `Idempotency-Key` is honoured on the four create POSTs (posts, comments, stories, messages); tests: `cd backend/api && /opt/homebrew/opt/php@8.5/bin/php artisan test`, uses the `socialhub_test` database). The Flutter app still uses mock data only. The single source of truth for the future API is **`docs/api/openapi.yaml`** (see section 7). Do not describe the backend as existing.
- Tabs (`AppTab` enum in `lib/widgets/bottom_nav.dart`): Home, Explore, Friends, Create Post, Notifications, Profile. Messages/Chat, Edit Profile and the story screens are pushed routes, not tabs.

## 2. Repository structure

```
lib/main.dart            SocialHubApp (themes, dark-mode flag, sign-in gate) + MainScreen (all app state, tab switching)
lib/services/            SocialApi (interface), MockSocialApi (offline seed), HttpSocialApi (dio, Laravel API),
                         api_mappers.dart (JSON -> models), token_store.dart, photo_picker.dart
lib/data/mock_data.dart  Seed data: currentUser, mockUsers/Posts/Stories/Notifications/Conversations
lib/models/              Immutable data classes (post, user, story, message, notification)
lib/screens/             One screen per file (home, explore, friends, create_post, notifications,
                         profile, edit_profile, messages, chat, story_viewer, story_creator)
lib/widgets/             bottom_nav.dart (SocialBottomNav + AppTab), mock_image.dart (PostMedia,
                         MockImagePreview, canLoadAssetImage), story_item.dart, user_avatar.dart
lib/utils/post_search.dart  searchPosts(): matching rule shared by Home and Explore
test/                    One file per feature + test_helpers.dart
assets/placeholder.png   1x1 pixel file (see gotchas)
docs/api/openapi.yaml    Draft API contract (OpenAPI 3.1) + proposed MariaDB 10.1 schema (`x-database`) for the approved Laravel backend
.github/copilot-instructions.md  Older project spec (partly outdated, see gotchas)
```

## 3. Development commands (verified)

```sh
flutter pub get                         # install dependencies
flutter analyze                         # static analysis (flutter_lints); must report no issues
flutter test                            # full suite (~147 tests, ~15 s)
flutter test test/explore_test.dart     # one file
flutter test --plain-name 'text'        # tests whose name contains "text"
dart format .                           # format
```

`flutter run` is documented in the README but was not run while writing this file. No build, lint-config or CI commands exist beyond the above (no CI config, no scripts).

## 4. Architecture rules (current practice)

- **State lives in `MainScreen`.** Screens never import `mock_data.dart` for runtime data (only `MockSocialApi` does); they receive lists/objects as constructor parameters and report changes through callbacks (`onToggleLike`, `onPostCreated`, ...). Only `main.dart` imports the mock data.
- **Screens keep only UI state** (search text, selected filter, open/closed search, friend-request statuses). Search/filter results are **derived in `build`** from the input lists, never stored as a second list.
- **Hide/save are ID sets** (`_hiddenPostIds`, `_savedPostIds`) in `MainScreen`; `Post` is not modified for them. `_posts` is the single source of posts. Home receives `_posts` **minus hidden IDs**; Explore and Profile receive all of `_posts` (intentional).
- Models are immutable; change them with `copyWith` (`Post`, `UserModel`) or by rebuilding the object. Do not mutate model objects or the `mock*` lists.
- Shared behavior lives in one place: search matching in `lib/utils/post_search.dart`, the placeholder-asset rule in `canLoadAssetImage()`, post image rendering in `PostMedia`. Reuse them instead of copying.
- Navigation: plain `Navigator.push` and the `AppTab` enum. Use `AppTab.x.index`, not bare tab numbers.

## 5. Coding conventions (observed)

- Files `snake_case.dart`; classes `UpperCamelCase`; private members `_prefix`. One screen per file, named `*_screen.dart`.
- Callback parameters are named `onSomething`; `MainScreen` handlers are `_handleSomething` (use `ValueChanged<String>` for typed callbacks).
- `const` constructors/widgets wherever possible; `package:flutter_learning/...` imports; `dart format` output is the formatting standard.
- Comments explain **why**, not what. Do not add comments that restate the code.
- Colors: use `Theme.of(context).colorScheme` (Material 3). Explicit `Color(...)`/`Colors.*` are intentional only for brand gradients, accent icons, and the black full-screen story screens. Use `onPrimary` / `onSurface` for text on `primary` / surfaces (not `Colors.white`).
- UI text is Vietnamese. Error handling is minimal by design (no I/O). No logging framework and no `print`.

## 6. State management

- **Do not add** Provider, Riverpod, Bloc, GetX, Redux, MobX, etc. unless the user explicitly asks; explain first why `setState` is no longer enough.
- Global (app-session) state: `MainScreen`. Local UI state: the screen's own `State`. There is no server state or cache.
- `IndexedStack` keeps all six tab screens alive, so their local state persists across tab switches (and `MainScreen.build` rebuilds every tab on each `setState`).
- `_conversations` is updated **in place** on purpose: an open `ChatScreen` reads that same list after sending.

## 7. API / data layer, 8. Database

**Building the APK:** run `scripts/build-apk.sh` (release APK in `build/app/outputs/flutter-apk/app-release.apk`; it uses Flutter 3.47 from `~/flutter_new` and sets `google-services.json` aside when it is not for this application id). `main()` now talks to the ngrok test server by default (`API_BASE_URL` overrides it) and only runs the offline mock with `--dart-define=USE_MOCK=true`, so a plain `flutter build apk` can no longer produce the mock app; the tests still use the mock through `SocialHubApp()`.

**Flutter side today:** `lib/services/` holds `SocialApi`. `MockSocialApi` (the default, offline, no sign-in) feeds `MainScreen` synchronously from the seed data, so every pre-existing test runs unchanged. `HttpSocialApi` talks to the Laravel API and is selected by `--dart-define=API_BASE_URL=http://localhost:8000/api/v1` (Android emulator: `http://10.0.2.2:8000/api/v1`; start the server with `php artisan serve` from `backend/api` using PHP 8.5). With a server the app shows `AuthScreen` first, the token is kept in `flutter_secure_storage`, and `MainScreen` loads feed/explore/stories/users/conversations/notifications once, then re-loads when a tab is tapped more than 15 s after the last load. Changes (like, save, hide, post, story, message, profile) are applied locally at once and rolled back with a SnackBar if the server refuses; a 401 returns to sign-in. `SocialApi.isRemote` switches the few UI differences (logout button, avatar picker, real friend requests).

**Photos:** with a server, Create Post, Story and Edit Profile pick real photos with `image_picker` (`MainScreen._pickPhoto`, injectable through `SocialHubApp(pickPhoto:)` for tests). The picked file path travels in `Post.imageUrl` / `Story.imageUrl`; `HttpSocialApi` uploads it as multipart when it is a local file path (not `http…` or `assets/…`), and the stored server version replaces the local draft. The mock app keeps its mock image picker.

**Social screens (server only):** `PostInteractions` (passed to `HomeScreen`) turns the post card's comment button into `CommentsSheet` (list, add, delete for the comment's author and the post's author), records shares (`Sao chép liên kết` copies `socialhub://posts/{id}` to the clipboard) and makes author names/photos open `UserProfileScreen`. `FriendsScreen` lists incoming requests (`Chấp nhận` / `Từ chối`) above the users, and tapping a user opens their profile, where the buttons follow the `Friendship` state (Thêm bạn / Hủy lời mời / Chấp nhận + Từ chối / Bạn bè → Hủy kết bạn). `MainScreen._openProfile` wires the profile actions to the app state; all of this is off on the mock app (`interactions` and the callbacks are null), which keeps its session-only comment box and share sheet.

**Starting a chat (server only):** `SocialApi.startConversation(friend)` (`POST /conversations`, friends only) backs the "Tin nhắn mới" button on Messages (friend picker) and the "Nhắn tin" button on a friend's profile; `MainScreen._startConversation` reuses an existing conversation from `_conversations` or inserts the new one, then opens the chat.

**Also server-only:** the Home post menu has "Xóa bài viết" for your own posts (confirm dialog, optimistic removal, rolled back on failure; its notifications disappear with it). Tapping a notification opens `PostDetailScreen` (like, comments, delete if yours) for like/comment/share, or the actor's profile for friend notifications (where a request can be answered). `StoryViewerScreen.onViewed` reports each story shown (after the first frame, once per story) and `MainScreen._handleStoryViewed` sends `POST /stories/{id}/view` for other people's unseen stories; a seen story gets a grey ring.

**Polling and refresh (server only):** with an open chat `MainScreen` asks `loadNewMessages(id, afterMessageId:)` every 4 s (`GET .../messages?after=`), appends only unseen ids, marks the conversation read when the other person wrote, and waits while one of our own messages is still being sent (otherwise the poll could return it before the send's answer replaces the local copy). The whole time the app is open (server only) `MainScreen._inboxTimer` re-reads `loadConversations()` every 10 s (`_refreshConversations`) and keeps the messages already loaded (a full `_load` keeps them too); an open conversation never gets an unread badge. The sum of the unread counts is the small number on the Messages icon of Home, and a message that arrives while another screen is open shows a SnackBar "<name>: <text>" with "Xem" (`_announceNewMessages`); messages are not notification rows, so nothing appears in the Notifications tab. The chat timer stops when the chat closes. `ChatScreen` and `MessagesScreen` take a `refresh` Listenable (`MainScreen._chatChanges`) because they are separate routes that the app's `setState` does not rebuild; the chat also scrolls to the newest message. Home, Explore, Friends and Notifications support pull-to-refresh (`onRefresh` → `MainScreen._refreshAll`, a full `load()`, errors shown in a SnackBar); on the mock app all of these callbacks are null.

**Explore (server only):** the details sheet of an Explore post gets the same social actions as Home (comments via `CommentsSheet`, the shared `showShareSheet`, save/unsave with a bookmark on the tile, and the author opens the profile). The sheet is a separate route, so `ExploreScreen` bumps a `_postsVersion` notifier after each frame in which MainScreen gave it new posts, and the sheet re-reads the post and saved state from it; do not bump it inside `didUpdateWidget` directly (it marks the sheet dirty while building).

**Saved posts:** `GET /me/saved-posts` (added to `docs/api/openapi.yaml` first) lists what the user saved, newest save first, skipping posts that were deleted or are no longer visible. The Profile tab has "Bài đã lưu" next to "Edit Profile" (same row, so the posts below do not move) opening `SavedPostsScreen` (pull to refresh, unsave removes the card). Unsaving goes through `MainScreen._setSaved(id, false)` and never a toggle, because a saved post that is not on Home is not in `_savedPostIds` and a toggle would save it. The mock app lists the posts saved in the current session from `_savedPostIds` (newest first).

**Backend operations:** notifications (`App\Jobs\CreateNotification`) and image-file removal (`App\Jobs\DeleteStoredImage`) run on the database queue, dispatched `afterCommit`, so a worker must be running or notifications never appear (tests use the sync queue). `backend/run-dev.sh` starts the API (4 server workers), the queue worker and the scheduler together, with the PHP upload limits and the right PHP binary; stop it with Ctrl+C. Production samples (not applied anywhere): `backend/api/.env.production.example`, `backend/deploy/` (supervisor queue worker, cron line, nginx site). Uploaded images go to the disk named by `IMAGES_DISK` (`public` locally, `s3` in production, needs `AWS_*`; files must be publicly readable by URL). Production errors never leak details: `bootstrap/app.php` maps every API exception to `{message, code}` and a non-debug 500 to `server_error`; `TRUSTED_PROXIES` makes Laravel trust the load balancer's forwarded headers. The app connects as the MariaDB user `socialhub_app` (created by `backend/api/database/create-db-user.sh`; `--dml-only` makes a runtime-only account for production), not root; its password is only in `backend/api/.env`. The scheduler also prunes expired Sanctum tokens and old failed jobs daily. Laravel Boost (`composer require --dev laravel/boost`, `.mcp.json`, `.claude/skills`, `boost.json`, `backend/api/CLAUDE.md`) was installed because `backend/api/CLAUDE.md` asked for it.

**Account security (server only):** registration queues a 6-digit email code (`App\Support\AuthCodes`, table `auth_codes`, HMAC-hashed, 15 min, 5 tries, one per user+purpose, mail via queued Mailables, so `MAIL_MAILER=log` in development writes the code to `storage/logs`; production needs real SMTP). Verification blocks nothing; `Me.emailVerified` drives the Profile banner "Email chưa được xác thực" (`VerifyEmailScreen`). "Quên mật khẩu?" on `AuthScreen` opens `ForgotPasswordScreen` (email, then code + new password); the forgot endpoint answers 202 for unknown emails too, and a reset revokes every token. "Xóa tài khoản" in Edit Profile asks for the password (`showDeleteAccountDialog`), soft-deletes the user (tokens and friendships removed, posts/comments/chats disappear for others), keeps the email/username reserved, and `accounts:purge-deleted` (daily, 30 days) removes the rows and queues image deletion. `php artisan images:check-disk` writes, fetches by URL and deletes a test file on `IMAGES_DISK`: run it once against a real S3 bucket (never done yet, only `Storage::fake` is tested). The `friendships.user_low_id/user_high_id` columns are plain app-filled columns (MariaDB 10.2+ rejects the old generated ones); Homebrew MariaDB 10.11 passes the whole suite.

**Push, paging, search, Vietnamese (server only):** `PUT/DELETE /me/devices` store FCM tokens (`device_tokens`); `CreateNotification` dispatches `SendPush`, and `App\Support\PushSender` sends through FCM HTTP v1 when `FCM_PROJECT_ID` and `FCM_CREDENTIALS` (service-account JSON path) are set, otherwise it only logs. In the app `PushService` (`lib/services/push_service.dart`) is the only code that touches `firebase_core`/`firebase_messaging` (approved for push); `FirebasePushService` is used only with `API_BASE_URL`, returns null from `start()` when Firebase is not configured, and the app then works without push. **To get real pushes:** create a Firebase project, put `google-services.json` in `android/app/` (the `com.google.gms.google-services` Gradle plugin is already declared and applied automatically once that file exists) and `GoogleService-Info.plist` in `ios/Runner/` (plus an APNs key in Firebase); neither file exists yet, so push has only been tested with fakes. Opening Home/Explore/Notifications/Friends near the end of a list loads the next cursor page (`MainScreen._loadMore`, `LoadMoreListener`); Friends searches on the server (`GET /users?q=`, debounced). Server messages are Vietnamese (`APP_LOCALE=vi`, `lang/vi.json`, `lang/vi/validation.php`); the app shows them as they come.

**Reporting, blocking, post privacy (server only):** `POST /reports` stores a report (post, comment or user; reasons in `report_sheet.dart`, same list as the API) in `reports`; there is no admin screen or endpoint, so operators read the table (`select * from reports where status = 'open'`). A block (`user_blocks`, `App\Support\Blocks`) deletes any friendship between the two and hides each from the other: posts (`Post::visibleTo/feedFor`, Explore), comments, notifications (also no new ones), user lists, conversations, friend requests; the blocked person gets 404 for the blocker's profile, the blocker still opens it (`isBlocked`) to unblock; the list is under Edit Profile → "Người đã chặn". In the app `PostInteractions.report/blockUser/changePrivacy` add "Báo cáo bài viết", "Chặn <tên>" (others' posts) and "Đổi quyền riêng tư" (own posts, `PATCH /posts/{id}`) to the Home post menu, a flag button on others' comments and a menu on `UserProfileScreen`; all are null on the mock app. Explore's details sheet and `PostDetailScreen` use the same actions through `PostModerationMenu` (`lib/widgets/post_moderation.dart`, which Home's menu also calls); in Explore a post that stops being public closes the sheet, because Explore lists public posts only.

**Profile and list support added for the UI redesign (cover, About, Ảnh/Bạn bè tabs and friend suggestions are used by the Flutter app; follow, multiple images, attachments, presence and typing are not yet):** `Me` and `UserProfile` carry `coverUrl`, `about` (`location`, `hometown`, `workplace`, `education`, `website`, `birthday`) and, on profiles, `createdAt`; `PATCH /me` edits the about fields and `POST/DELETE /me/cover` the cover (columns in migration `add_profile_fields_to_users_table`). `GET /users/{id}/friends` and `/photos` back the profile tabs, `GET /users/suggestions` is "people you may know" (mutual friends first, offset cursor), `GET /conversations?q=` searches by the other person's name/username, `GET /notifications?category=interactions|friends&unread=true` filters, `GET /feed?filter=all|friends|popular` gives the feed tabs. In the app (server only; every callback is null on the mock app, which keeps its local tabs): `UserModel.about` (`UserAbout`) and a real `coverUrl` come from `userFromJson`; `ProfileScreen` gets `loadPhotos`/`loadFriends` (paged with a "Xem thêm" button, reloaded each time the tab opens) and `onChangeCover` ("Đổi ảnh bìa" on your own cover, `SocialApi.uploadCover`); `UserProfileScreen` passes the same loaders for the viewed user and opens a tapped friend; `EditProfileScreen(editAbout: true)` edits the About fields (website must be http/https, birthday through the date picker) and `HttpSocialApi.updateProfile` always sends them (empty = clear); `FriendsScreen(onLoadSuggestions:)` fills the "Người bạn có thể biết" chip from `GET /users/suggestions`.

**Video posts (server only):** `POST /posts` takes one `video` (mp4/mov/webm, max 50 MB and 60 s, not together with images). `App\Support\VideoStore` checks it with ffprobe, keeps the upload (`posts.video_source_path`) and `App\Jobs\ProcessPostVideo` converts it on the queue with ffmpeg into H.264/AAC mp4 (720 px wide at most, faststart) plus a JPEG thumbnail, then sets `video_status` to `ready` (or `failed`). **ffmpeg and ffprobe must be installed where the queue worker runs** (`brew install ffmpeg` locally, `apt install ffmpeg` on a server; binaries can be set with `FFMPEG_BINARY` / `FFPROBE_BINARY`), the worker needs `--timeout=320` (run-dev.sh and the supervisor sample have it) and PHP needs `upload_max_filesize=52M`, `post_max_size=56M` (run-dev.sh sets them; the nginx sample allows 56 MB). While `processing`/`failed` only the author sees the post (`Post::hideUnfinishedVideos` in `visibleTo`, `feedFor`, Explore); `GET /explore?filter=short_video` lists ready videos and `filter=media` includes them. The post JSON has `video` (`status`, `url`, `thumbnailUrl`, `durationSeconds`, `width`, `height`; urls only when ready). In the app (`Post.video`, `PostVideo`) Create Post has a "Chọn video" row (`onPickVideo` / `onVideoPostCreated`, server only, `pickVideoPath` with a 60 s limit; picking a photo clears the video and the other way round), `PostVideoView` (in `PostMedia`) shows the still with a play button, "Đang xử lý video..." or "Không xử lý được video", tapping opens `VideoPlayerScreen` (full screen, `video_player`); Explore tiles pass `playable: false` so the tap still opens the post. After posting, `MainScreen._watchVideos` asks `GET /posts/{id}` every 5 s (max 5 min) until my video is ready. A picked video is first re-encoded at 720p on the phone (`compressVideoFile` in `lib/services/video_compressor.dart`, `video_compress`; injectable as `SocialHubApp(compressVideo:)`; `VideoRejected` carries the message when the clip is longer than 60 s or still over 50 MB), because phone clips of a few seconds are often over 50 MB; Create Post shows "Đang nén video..." meanwhile. Videos upload through the API (no presigned upload yet). A lost or too large upload now answers 422 (`Idempotent::rejectBrokenUploads`) and the PHP reason is in `storage/logs/laravel.log`. The real conversion is covered by `VideoPostTest` (it runs ffmpeg; skipped when ffmpeg is missing); `video_player` itself is not exercised in widget tests.

**Multiple images, chat attachments, follow, presence, typing (all used by the Flutter app):** `POST /posts` takes `images[]` (up to 10; `image` still works) stored in `post_images`, and posts return `imageUrls` (`imageUrl` stays the first one); `GET /users/{id}/photos` lists one item per image. `POST /conversations/{id}/messages` takes `attachments[]` (up to 5, 10 MB each: jpg/png/webp re-encoded, or pdf/doc(x)/xls(x)/ppt(x)/txt/csv/zip stored as is under a random name in `chat/`); messages carry `attachments` and `text` may be empty. `PUT/DELETE /users/{id}/follow` is one-way follow (`follows`): followed people's public posts join the feed, `GET /feed?filter=following` (friends are followed automatically, see below), `GET /users/{id}/followers|following`, profiles carry `followersCount`, `followingCount`, `isFollowing`, `followsYou`, and a `follow` notification exists (the Flutter mapper shows it as "đã bắt đầu theo dõi bạn"). Presence: `App\Http\Middleware\TouchLastSeen` writes `users.last_seen_at` at most once a minute; friends see `isOnline` (active in the last 2 minutes) and `lastSeenAt` on profiles, user lists and conversation participants unless the user turned `showOnlineStatus` off (then they look offline); `POST /me/presence` is a heartbeat. Typing: `PUT/DELETE /conversations/{id}/typing` keeps a 6-second flag in the cache and `GET .../messages` returns `meta.otherTyping`.

**Post reactions (server only):** `PUT /posts/{id}/like` takes an optional `{"reaction": like|love|haha|wow|sad|angry}` (`post_likes.reaction`, default `like`; a new reaction on an already liked post replaces the old one without changing the count; `PostInteractionController::REACTIONS`). Posts carry `myReaction` and `reactionCounts` (`{love: 2, sad: 1}`; an empty object when nobody reacted) and the like state answers with the same two. In the app `Post.reaction`/`reactionCounts` come from `postFromJson`; `PostActionBar` (long press on Thích opens the capsule) shows the server's reaction and calls `onReactionSelected` → `HomeScreen.onReact` → `MainScreen._handleReaction` (optimistic via `_applyReaction`, rolled back on failure; choosing the same reaction again unlikes). On the web `PostCard` does the same, also on touch screens (long press) and shows the top three reaction emojis before the count. A `like` notification carries `reaction` (read from `post_likes` when the list is requested, so a changed reaction shows; `like` for a plain Thích) and its text and push say "đã bày tỏ cảm xúc 😆 về bài viết của bạn" (`notificationFromJson`/`_likeLook` in the app, `getNotificationMeta(type, reaction)` on the web, `CreateNotification::likeText` for the push). The mock app keeps the local-only reaction.

**Message reactions, recall, delete for me, reply, forward (server only):** reactions are on the server (`message_reactions`, one per person, six emojis `ConversationController::REACTIONS`; `PUT/DELETE /conversations/{c}/messages/{m}/reaction`), "Thu hồi" is `DELETE /conversations/{c}/messages/{m}` (sender only; sets `messages.recalled_at`, removes text, files and reactions for both people) and "Xóa ở phía tôi" is `PUT .../hide` (`message_hidden`, only for the caller; hidden messages are left out of lists and polls). A message carries `isRecalled`, `reactions` (`{emoji: count}`) and `myReaction`; the poll with `?after=` also answers `meta.states` for the latest 100 messages so an open chat follows reactions and recalls of old messages (`MainScreen._applyMessageStates`, `applyStates` on the web). A reply is plain text: `[reply:id:name:quote]\n<text>` (`chat_interactions.dart`, `chat-interactions.ts`) and `formatMessagePreview` (app, web, push) shows only what was written; forwarding sends the text (or sticker) to a conversation picked in a sheet (`ForwardMessageModal` on the web), images and files are not forwarded. Without the callbacks (mock app) `ChatScreen` keeps reactions, recalls and deletions in its own state. The pinned message and the in-chat search are not shared: the web remembers the pin in `localStorage`, the app only while the chat is open.

**Delivered / seen ticks, pin, in-chat search (server only):** `conversation_participants.last_delivered_message_id` is set when a person's app fetches the conversation list or the messages (reading also counts), `last_read_message_id` is the existing read marker; the conversation and every messages answer carry `partnerLastDeliveredMessageId`, `partnerLastReadMessageId` and `pinnedMessage` (`meta` of `GET .../messages`). Ids are ULIDs, so a message of mine is *sent* (one tick), *delivered* (two grey ticks) or *seen* (two blue ticks, the other person's small avatar under the last one they have seen) by comparing its id with those markers (`sendState`/`lastSeenOfMine` in `lib/utils/message_status.dart` and `web/src/lib/message-status.ts`; the mock app keeps its old demo ticks). The pin is one per conversation for both people (`conversations.pinned_message_id`, `PUT/DELETE /conversations/{c}/pin`, cleared when the message is recalled, hidden from a person who deleted it for themselves). In-chat search is done on the loaded messages (the latest 100): it ignores accents and case and skips quotes, stickers and recalled messages (`chat_search.dart`, `chat-search.ts`).

**Typing and the "Đang theo dõi" tab (server only):** `SocialApi.loadNewMessages` returns a `MessagePoll` (`messages` + `otherTyping` from `meta.otherTyping`); `MainScreen._pollOpenChat` copies it into `_partnerTyping`, which the chat route listens to (`ChatScreen.isPartnerTyping`) and which is cleared when the chat closes. The Home tab "Đang theo dõi" loads `GET /feed?filter=following` through `SocialApi.loadFeedFilter` when opened or refreshed and pages on scroll (`MainScreen._loadFollowing`); the posts are merged into `_posts` and `_feedPostIds` like any others, and `_followingPostIds` says which belong to the tab. The "Đa phương tiện" tab works the same way with `GET /feed?filter=media` (posts with at least one image); both feed tabs and the notification filters "Tương tác"/"Kết bạn" (`GET /notifications?category=`) are generic `_ServerTab`s in `MainScreen` (ids + cursor + loading + error, passed to the screens as `ServerTabState`, loaded by `_loadFeedTab`/`_loadNotificationTab`). The Messages search shows the loaded conversations that match plus what `GET /conversations?q=` finds (`_searchConversations` adds unknown ones to `_conversations` so they can be opened). The Notifications badge uses the server's `GET /notifications/unread-count` (`AppSnapshot.unreadNotificationCount`, cleared when the tab opens) and falls back to counting loaded notifications. In a chat, a picture opens full screen (`showImageViewer`, pinch to zoom) and tapping a file copies its link, and the website in a profile's Giới thiệu does the same, because opening links/files needs a package such as `url_launcher` that is not approved yet. Uploads (any `FormData` request) get 120 s to send and to answer (`HttpSocialApi._uploadTimeout`) instead of the normal 20 s. Your own story can be deleted from the story viewer (`DELETE /stories/{id}`, optimistic, rolled back on failure). Friends follow each other: accepting a friend request creates both follows on the server (`FriendController::accept`, `insertOrIgnore`, no `follow` notification), existing follows are kept and not doubled, declining/cancelling creates none, unfriending keeps the follows and unfollowing keeps the friendship (blocking still removes both), and becoming friends again follows again even after an unfollow. The migration `follow_between_existing_friends` did this once for the friends that already existed. The app reloads silently after an accept so the follower counts and "Đang theo dõi" match.

**Chat theme and shared media (server only):** the bubble theme is one per conversation for both people (`conversations.theme`, ids `blue|purple|sunset|midnight|emerald` = `ConversationController::THEMES`, default `blue`; `PUT /conversations/{c}/theme`; the id comes back in every conversation and in `meta.theme` of the messages answers, so a poll shows the other person's change). The colours live in the clients (`web/src/lib/chat-theme.ts`, `lib/models/chat_theme.dart`); the web used `localStorage` and the app memory before, which only changed the colours for that browser. Both apply a change at once and roll it back if the server refuses (`pendingThemeRef` / `MainScreen._pendingThemes` stop a poll that was already on its way from putting the old colour back). The details drawer/screen ("Chi tiết hội thoại") lists pictures and files from `GET /conversations/{c}/media?type=image|file` (cursor paged, newest first, recalled and deleted-for-me messages left out; `SharedMediaDrawer`, `ChatDetailScreen.loadMedia`), not from the loaded messages, which are only the latest page; chat attachments are pictures and documents, never videos. `ChatDetailScreen` reads the chat through getters plus the `refresh` Listenable because it is a separate route. The mock app lists what is loaded.

**Quick like, paste, drag & drop, story/note answers:** with an empty box (spaces count as empty) the chat's send button becomes a 👍 that is sent at once (as a reply when one is being answered); in the app only that button rebuilds while typing (`ValueListenableBuilder` on the controller), so widget tests must `pump()` after `enterText` before tapping send. On the web, pasted pictures (Ctrl/Cmd+V) and dropped files go through `web/src/lib/chat-files.ts` (`checkChatFiles`, `namePastedImage`): the same rule as the server (5 files, 10 MB, jpg/png/webp + pdf/doc(x)/xls(x)/ppt(x)/txt/csv/zip), because one refused file makes `POST .../messages` reject the whole message, and a pasted picture is renamed to match its real type (clipboards call everything `image.png`); gif/heic are refused with a message. The drop overlay only reacts to files, and previews (object URLs) are revoked. The app answers stories and notes in writing like the web: a box in `StoryViewerScreen` (`onReply`, the story waits while it has focus) and in the note sheet (`showNoteDetail(onReplyText:)`), sending "Đã phản hồi tin của bạn: …" / "Đã phản hồi ghi chú của bạn: …" through `MainScreen._sendQuickMessage` (server only).

**Quick reaction emoji (server only, local on the mock app):** the emoji of the quick send button is one per conversation for both people, like the theme: `conversations.quick_reaction`, `PUT /conversations/{c}/quick-reaction {emoji}` (one of the 12 in `ConversationController::QUICK_REACTIONS`, with or without U+FE0F; the canonical form is stored), `quickReaction` in every conversation and in `meta` of the messages answers (default 👍). The list is repeated in `web/src/lib/quick-reactions.ts` and `lib/data/quick_reactions.dart`. Web: right click (long press on a phone) on the button or the "Biểu tượng cảm xúc nhanh" row of the details drawer; app: long press on the button (`showQuickReactionPicker`) or "Cảm xúc nhanh" in `ChatDetailScreen`; both optimistic with rollback (`pendingQuickRef` / `MainScreen._pendingQuickReactions`).

**YouTube "Video" tab (server only):** Explore has a "Bài viết | Video" switch (web: `YoutubeVideos` in `/explore`; app: `YoutubeVideosView`, shown when `ExploreScreen.searchVideos` is set, which only a server provides). `GET /videos/search?q=&cursor=` (`VideoSearchController`, `App\Support\VideoCatalog`) calls the YouTube Data API v3 with `YOUTUBE_API_KEY` from `backend/api/.env` (Google Cloud Console, free; `YOUTUBE_REGION`, default `VN`, picks the popular list shown while the box is empty). Free quota is 10,000 units a day and one search costs 100 (the details call and the popular list cost 1), so answers are cached 1 hour, the route allows 20 a minute, and the clients wait 600 ms after typing. Only 11-character ids, embeddable videos and `ytimg.com` thumbnails are passed on; without a key, or when the quota is used up, the answer is 503 `video_unavailable` and both clients show "Hiện chưa tìm được video". Nothing is downloaded: the web uses an `<iframe>` on `youtube-nocookie.com` (`frame-src` was added to the CSP in `web/next.config.mjs`), the app `youtube_player_iframe` in `YoutubePlayerScreen` (the only file that touches it; web view, so widget tests inject `ExploreScreen.onPlayVideo`). The package adds native plugins (`webview_flutter`): iOS needs `pod install` once and a full rebuild.

**Notes (server only):** a note is a text of 1-60 characters (emoji count as one) that friends see for 24 hours: `PUT /me/note` (create or replace, restarts the 24 hours, 30 per hour), `DELETE /me/note`, `GET /notes` (mine first, then my friends', max 100; strangers, blocked people and deleted accounts never appear); table `notes` (one row per user), hourly `notes:purge-expired`. In the app the Messages screen shows a `NotesRow` (`lib/widgets/notes_row.dart`) above the search box: my item opens a sheet to share, change or remove my note, a friend's note starts a chat with them. `MainScreen._notes` is updated in place (the Messages route keeps the list) and reloaded on load, on opening Messages and every 15 s with the conversation poll; the mock app has no row.

**Note and story privacy (server only):** notes and stories carry `privacy` (`public` | `friends` | `only_me`, default `friends`; replacing a note without `privacy` keeps its value). Notes: the Messages row shows mine, my friends' (`public`/`friends`) and followed people's `public` notes; a profile's `note` is visible to anyone if `public`, to friends if `friends`, only to the owner if `only_me`. Stories: `Story::visibleTo` (own, `public` from anyone, `friends` from friends, minus blocks) and `Story::inTrayOf` (that ∩ own/friends/followed) build the tray; strangers' public stories open from their profile ("Xem tin", `profile.hasStories`, `GET /users/{id}/stories`); `PATCH /stories/{id}` changes the audience (lock button in the viewer, optimistic with rollback). The note sheet has "Ai xem được ghi chú", the story creator an "Ai xem được: …" chip (`showPrivacy`, server only). Profiles show the note with its song. A note's song plays when a note is opened (own notes have a play/pause button); if Spotify denies search (the app owner needs Premium) the Spotify link is a Spotify search URL. Audio needs a full rebuild (native plugin) and `API_BASE_URL`.

**Music in notes and stories (server only):** a note (`PUT /me/note {text, trackId}`, text may be empty with a song) or a story (`POST /stories` with `trackId`) can carry one song. `GET /music/search?q=` searches the Apple Music / iTunes catalogue (`App\Support\MusicCatalog`, the iTunes Search API, no key, storefront `MUSIC_COUNTRY=VN` so Vietnamese songs are found, cached 1 hour, 30 per minute, 503 `music_unavailable` when the catalogue fails) and returns 30-second previews. The client sends only the track id: the server looks it up again (`/lookup`) and stores a snapshot in `track_*` columns, and only https URLs on `apple.com` / `mzstatic.com` are ever kept, so a client cannot make friends' phones fetch an arbitrary address. If `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` are set in `backend/api/.env` the server also finds the song on Spotify (client-credentials token, best match by title and artist) and stores `spotifyUrl`; Spotify gives no previews to new apps (since Nov 2024) so it is only a link, and any failure just leaves the link empty. Apple's previews are meant for promotion, so the app always shows "Nguồn nhạc: Apple Music · nghe thử 30 giây" and the Apple Music link next to the player; reread Apple's terms before shipping. In the app `AudioPreview` (`lib/services/audio_preview.dart`) is the only code that touches `just_audio` (`JustAudioPreview` in the real app, `NoAudioPreview` in the mock app and tests; `SocialHubApp(audio:)`), `showTrackPicker` (search with debounce, play/pause, pick) and `TrackCard` live in `lib/widgets/track_picker.dart`, the note sheet has "Thêm nhạc", a friend's note that has a song opens a player sheet (links are copied, not opened, for lack of `url_launcher`), `StoryCreatorScreen` has a music button, and `StoryViewerScreen` loops the song of the story on show with a mute button and stops it on leaving.

**Test hosting (ngrok):** the Mac is the server and `ngrok http --url=imminent-ninetieth-stark.ngrok-free.dev 8000` (free static domain, 1 GB/month, run beside `backend/run-dev.sh`) makes it reachable over HTTPS; `APP_URL` and `TRUSTED_PROXIES=*` in `backend/api/.env` match it. ngrok shows a warning page to browser user agents only, the Dart HTTP client is not affected (checked with curl). Build the APK with `--dart-define=API_BASE_URL=https://imminent-ninetieth-stark.ngrok-free.dev/api/v1`; HTTPS means a release APK works (it is signed with the debug key; `android/app/google-services.json` must be moved aside while the Firebase app is not registered for `io.github.binn2000.socialhub`). Mail goes through Brevo SMTP (`MAIL_*` in `.env`; the From address must be a verified Brevo sender), files through Cloudflare R2 (`IMAGES_DISK=s3`; keep only one `AWS_*` block in `.env`).

**Known gaps with a server:** a message can take up to 4 s to show while the app is open (polling); email verification is not enforced (only a banner).

**Approved target (not built):** Laravel API-only, **MariaDB 10.1.38** (the version bundled with the project's local XAMPP install — not MySQL; see below), Sanctum bearer tokens, `/api/v1`, JSON, cursor pagination, Laravel Storage (local in development, S3-compatible in production), polling chat, database queue driver. The contract is `docs/api/openapi.yaml`:

- It is a **draft**. Change the contract first, then the code, and keep Flutter models and Laravel resources in step with it (JSON is camelCase; IDs are ULID strings; timestamps are UTC ISO 8601; enums are identifiers such as `only_me`, never Vietnamese labels).
- Flutter packages `dio`, `flutter_secure_storage`, `image_picker`, (for push only) `firebase_core`/`firebase_messaging` and (for song previews only) `just_audio` are added and used. No other new dependency.
- The mock implementation stays behind the same `SocialApi` interface so the tests run without a server. Keep `setState`; Bloc/Riverpod are not approved. Flutter models still differ from the contract (Vietnamese labels, relative-time strings); `api_mappers.dart` is the only place that translates.
- **MariaDB 10.1.38 is old (EOL October 2020) and the schema in `docs/api/openapi.yaml`'s `x-database` section is adjusted around three of its limitations, explained there: unique indexes on long `utf8mb4` columns need `ROW_FORMAT=DYNAMIC` plus `innodb_large_prefix`/`innodb_file_format=Barracuda` server settings; `CHECK` constraints are parsed but not enforced, so the same rule must also live in Laravel validation; there is no native `JSON` column type, so `idempotency_keys.response_body` is `text` with manual encode/decode. Do not silently assume MySQL-8 behavior (e.g. `utf8mb4_0900_ai_ci`, enforced `CHECK`, real `JSON`) when writing migrations — check the contract's notes first.

## 9. Testing rules

- Framework: `flutter_test` only; no mocking libraries. Tests run the real app (`pumpSocialHub`) or a single screen wrapped in `MaterialApp`.
- One file per feature in `test/` (`*_test.dart`). Shared helpers live in `test/test_helpers.dart` (`pumpSocialHub`, `tapTab`, `openPostMenu`, `visibleVerticalScrollable`, ...).
- Test user-visible behavior (text, semantics, tapping), not private members. Tests contain Vietnamese UI strings and depend on seed data (`mockPosts` order, like counts) - changing either requires updating tests.
- Add or update tests when changing behavior, and keep `flutter analyze` + `flutter test` green.
- Test-writing gotchas: the default test screen is 800x600 (use `tester.ensureVisible` / `scrollUntilVisible`, or set `tester.view.physicalSize`); `Icons.person_rounded` is both the Profile tab and the avatar fallback icon, so tap tabs via `tapTab` (scoped to `NavigationBar`); use `isSemantics(...)` (`containsSemantics` is deprecated); a `SnackBar` with an action needs `persist: false` to auto-close.

## 10. Security rules

The app has no network, secrets, or user data handling today. Keep it that way; if that changes, add validation at the boundary and never commit secrets (`android/.gitignore` already ignores `key.properties`, `*.jks`, `*.keystore`). Do not copy Facebook branding, logos, or assets (see `.github/copilot-instructions.md`).

## 11. Git / change rules

- **This directory is not currently a git repository** (no `.git`), so there is no history or diff to fall back on: make small changes and say what changed.
- No commit/branch/PR convention is defined.
- Do not hand-edit `pubspec.lock`, `.dart_tool/`, `build/`, or `.metadata`. `.idea/` and `*.iml` are IDE files.

## 12. Important gotchas

- **`assets/placeholder.png` is a 1x1 pixel.** `canLoadAssetImage()` deliberately skips it, so every mock image/avatar renders as a gradient/icon fallback. `Post.imageId` picks the gradient (`mockImageColors`); posts without one use a legacy hash of the post id.
- **Tabs stay alive** (`IndexedStack`), so a screen's local state survives tab switches. Create Post therefore resets its own form after a successful post (`_resetForm`); keep doing this for any form-like tab, or old input will reappear.
- **Card colors:** UI reads `Theme.of(context).cardColor`, which in this theme equals `colorScheme.surface`. The `cardTheme` in `main.dart` (`#FFFFFF` / `#1B1F29`) is **not applied** (no `Card` widget is used). Do not "fix" it casually - it changes the look of every screen. In dark mode, cards are nearly the same color as the background.
- **Ids** for new posts/stories/messages come from `DateTime.now().millisecondsSinceEpoch` (collide if two are created in the same millisecond).
- **Opening the Notifications tab marks all notifications read**; the per-notification tap handler runs later and cannot be observed as "one read".
- **Story viewer** has a 4-second auto-advance timer (present in code, untested); `Story.time` (from the API's `createdAt`) is shown under the name, and own stories have a delete button on a server.
- **UI language:** all app text is Vietnamese (nav labels Trang chủ/Khám phá/Bạn bè/Tạo bài viết/Thông báo/Cá nhân, titles Bạn bè and Tin nhắn, "Chỉnh sửa hồ sơ"); tests assert them. The nav labels are real `Text` widgets even though they are hidden, so a test that looks for plain `Bạn bè` or `Thông báo` text finds the nav label too: scope the finder (`widgetWithText(AppBar, ...)`, `ListTile`, `OutlinedButton`). There is no l10n setup or locale on `MaterialApp`, so system-provided text (e.g. back-button tooltip) uses default English.
- **Seed data:** `mockUsers/Posts/...` are mutable global lists; `MainScreen` copies them once. `MainScreen._users` keeps the original current user (its name is not updated after Edit Profile); Friends excludes the current user by id.
- **Stale spec:** `.github/copilot-instructions.md` mentions `widgets/post_card.dart` (does not exist), five destinations (there are six), and Profile tabs/cover image (not implemented). Its philosophy is still valid; where it disagrees with the code, the code wins.
- **Release readiness:** the application/bundle id is `io.github.binn2000.socialhub` (display name SocialHub), but the release build type still uses the debug signing key (`android/app/build.gradle.kts`). The local `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` were made for the old `com.example.*` id: register the new id in Firebase and replace both files, or push and the Android build will fail. Draft terms and privacy policy are in `docs/legal/` (placeholders marked `[ĐIỀN SAU]`, fill them before any store release); a shorter in-app copy is in `lib/data/legal_texts.dart` (keep both in step), shown by `LegalScreen`: sign-up on `AuthScreen` needs the terms checkbox, and Edit Profile (server only, `editAbout`) links both documents. Not release-ready.

## 13. Do not

- Do not introduce a state-management package, routing package, or any dependency other than the approved `dio`, `flutter_secure_storage`, `image_picker`, `firebase_core`, `firebase_messaging`, `just_audio`, `video_player`, `video_compress`, `youtube_player_iframe` (and only when the task needs them). The only approved backend is the Laravel one described in `docs/api/openapi.yaml`; Firebase is used for push delivery only, never as a backend.
- Do not implement a Laravel endpoint or Flutter API call that is not in the contract, and do not change the contract silently: update `docs/api/openapi.yaml` in the same change.
- Do not read `mock*` data from screens/widgets at runtime; do not mutate `_posts`, `mock*` lists, or model objects in place.
- Do not store search/filter results or hidden/saved flags on `Post`.
- Do not implement product features while asked to audit/fix; do not rewrite unrelated code or "clean up" outside the task.
- Do not remove a model field just because it is unused (`username`, `coverUrl`, `accentColor`, `Story.isViewed` are deliberate seed-only fields) without discussing it.
- Do not change tab order or make Messages a tab; keep `AppTab`, the icon/label lists and the `screens` list in `MainScreen.build` in sync.
- Do not change visible UI strings or seed data without updating the tests that assert them.
- Do not hard-code light-only colors (`Colors.white` text on themed backgrounds, etc.).

## 14. Change workflow

1. Read the relevant screens/models and `MainScreen` state before editing; find the existing pattern and reuse shared helpers.
2. Identify impact (which screens receive this data; do Home/Explore/Profile all need it?).
3. Make the smallest change that fits the current architecture.
4. Update or add focused tests; run the affected test file, then the full suite.
5. Run `dart format .`, `flutter analyze`, `flutter test`; all must be clean.
6. For UI changes, check light **and** dark mode (a widget test that renders both, or run the app).
7. Report what changed, what was verified, and any remaining risk. Never claim something works without running it.

## Proposed (not current convention)

- Extract a shared `PostCard` (Home card, Profile card, Explore tile/details duplicate post UI, including the "đang <feeling> · <privacy>" line built in three places).
- Central color/spacing constants and a decision on `cardTheme` vs `cardColor`.
- Extract post-list state logic from `MainScreen` (about 420 lines) into a small controller only if it keeps growing.
- Move UI strings to Flutter localization and set a locale.

## iOS plugins use CocoaPods

`pubspec.yaml` sets `flutter: config: enable-swift-package-manager: false`. With Swift Package Manager on (the default) `flutter build ios` failed with "Module 'flutter_secure_storage_darwin' not found" and a Podfile that kept coming back. Do not remove that setting or run `pod deintegrate` without re-testing `flutter build ios --simulator`.

## Backend gotcha: `artisan serve` ignores env overrides

`php artisan serve` removes any environment variable that also appears in `backend/api/.env` before starting its child server, so `DB_DATABASE=other php artisan serve` still uses the `.env` database. To smoke-test against a throwaway database, change `.env` (or copy it) instead. This once put smoke-test rows into the real `socialhub` database; they were deleted afterwards.

## Android builds need JDK 17-21

Android Studio's bundled JDK is 25 here, which Gradle 8.14 rejects. Flutter is set to JDK 21 with `flutter config --jdk-dir=~/Library/Java/JavaVirtualMachines/jbr-21.0.11/Contents/Home`. `flutter build apk --debug` works (SDK at `/Volumes/Du_Lieu/android_sdk`); a debug APK was built both without and with a placeholder `google-services.json`.

## 15. Web (Next.js 14 + TypeScript)

The `web/` directory contains the Next.js 14 + TypeScript web version of SocialHub, mirroring the mobile app features and Vietnamese UI text.

- **Architecture:** Next.js App Router serves as a secure proxy (`/api/proxy/[...path]`) to the Laravel backend (`http://localhost:8000/api/v1`).
- **Authentication:** Sanctum token is kept strictly in an `httpOnly`, `sameSite=lax` cookie (`socialhub_token`), never exposed to client-side JavaScript.
- **Routing & Guards:** Handled via `middleware.ts`. Unauthenticated users are redirected to `/login`, while authenticated users are redirected away from auth pages (`/login`, `/register`).
- **Giai đoạn 1 (Nền tảng):** AppShell, Sidebar, Header, BottomNav, AuthProvider, UserAvatar, Vitest suite, OpenAPI TypeScript types (`npm run typegen`).
- **Giai đoạn 2 (Tài khoản):**
  - Đăng ký (`/register`): xác thực tên, username, email, mật khẩu, checkbox điều khoản.
  - Quên mật khẩu (`/forgot-password`): 2 bước - gửi mã xác nhận 6 số đến email, sau đó nhập mã và mật khẩu mới (`/api/auth/password/*`).
  - Xác thực email (`/verify-email`): gửi lại mã (`POST /auth/email/verification`), xác thực mã 6 số (`POST /auth/email/verify`).
  - Banner nhắc xác thực email (`EmailVerificationBanner`): hiển thị trên `AppShell` khi `user.emailVerified === false`.
  - Chỉnh sửa hồ sơ (`/settings/profile`): đổi ảnh đại diện (`POST /me/avatar`), ảnh bìa (`POST /me/cover`), cập nhật thông tin giới thiệu (nơi sống, quê quán, nơi làm việc, học vấn, website, sinh nhật), bật/tắt trạng thái online (`showOnlineStatus`), xóa tài khoản (`DeleteAccountModal` với mật khẩu -> `DELETE /me`).
  - Người đã chặn (`/settings/blocked`): tải danh sách chặn (`GET /me/blocks`) và bỏ chặn (`DELETE /users/{id}/block`).
  - Điều khoản và quyền riêng tư (`/terms`, `/privacy`): nội dung đồng bộ với `lib/data/legal_texts.dart`.
  - Nhịp hiện diện trực tuyến (`presence` heartbeat): `AuthContext` tự động gửi `POST /me/presence` mỗi 60 giây khi `showOnlineStatus !== false`.
- **Giai đoạn 3 (Bảng tin / Feed & Posts):**
  - Bảng tin chính (`/` qua `FeedView`): các tab lọc bảng tin ("Dành cho bạn", "Đang theo dõi", "Đa phương tiện" - `GET /feed?filter=...`).
  - Hàng khay tin (`StoryTray`): hiển thị danh sách story và nút "Tạo tin".
  - Hộp tạo bài viết (`CreatePostCard`): hỗ trợ soạn thảo văn bản, đính kèm nhiều ảnh (tối đa 10 ảnh preview/xóa từng ảnh), đính kèm video (mp4/mov/webm <= 50MB), chọn quyền riêng tư (Công khai, Bạn bè, Chỉ mình tôi), chọn cảm xúc (Cảm thấy vui, Hứng thú, Hạnh phúc), gắn header `Idempotency-Key` (UUID).
  - Thẻ bài viết (`PostCard`):
    - Header: Avatar, tên tác giả, nhãn thời gian tương đối tiếng Việt (`timeAgo`), cảm xúc, biểu tượng quyền riêng tư.
    - Menu bài viết: đổi quyền riêng tư (`ChangePrivacyModal`), lưu / bỏ lưu (`PUT/DELETE /posts/{id}/save`), ẩn bài viết (`PUT /posts/{id}/hide` kèm thông báo hoàn tác), xóa bài viết (`DELETE /posts/{id}`), báo cáo (`ReportModal`), chặn tác giả (`PUT /users/{id}/block`).
    - Nội dung: tự động rút gọn khi quá dài ("Xem thêm"), bố cục lưới ảnh (1, 2, 3, 4+ ảnh với lớp phủ `+N`), trình phát video HTML5 (hỗ trợ trạng thái xử lý/thất bại).
    - Tương tác: Thích (animation pop, cập nhật số lượng lạc quan), Bình luận (mở `CommentsModal`), Chia sẻ (sao chép liên kết clipboard kèm thông báo, `POST /posts/{id}/shares`), Lưu bài viết.
  - Hộp thoại bình luận (`CommentsModal`): tải bình luận (`GET /posts/{id}/comments`), gửi bình luận mới (`POST /posts/{id}/comments` kèm `Idempotency-Key`), xóa bình luận (`DELETE /comments/{id}`), báo cáo bình luận.
  - Xem ảnh phóng to (`ImageViewerModal`): lightbox toàn màn hình, chuyển ảnh trước/sau bằng chuột hoặc phím mũi tên/Esc, thu nhỏ danh sách thumbnail.
  - Trang chi tiết bài viết (`/posts/[id]`): xem bài viết đơn lẻ từ liên kết chia sẻ hoặc thông báo.
- **Giai đoạn 4 (Hồ sơ / Bạn bè / Profile & Friends):**
  - Trang cá nhân (`/profile` cho tôi, `/profile/[id]` cho người khác qua `ProfileView`):
    - Header chuẩn Modern Facebook: ảnh bìa tỉ lệ banner (`h-48 sm:h-64 md:h-72`) kèm lớp phủ gradient chân thực, nút "Đổi ảnh bìa" tinh tế ở góc dưới phải.
    - Avatar cao cấp kích thước lớn (`2xl`: `w-32 h-32 sm:w-36 sm:h-36`) nổi 50% bằng negative margin (`-mt-16 sm:-mt-20`) kèm viền `ring-4` và bong bóng ghi chú (`Note bubble`) hướng chuẩn xác.
    - Bố cục chống va chạm (Anti-collision): trên desktop, họ tên (`h1`), `@username`, badge "Theo dõi bạn" và các chỉ số (bạn bè, người theo dõi, đang theo dõi) nằm hoàn toàn sang bên phải của Avatar, loại bỏ 100% hiện tượng avatar che mất tên. Trên mobile, avatar và tên căn giữa thẳng hàng với khoảng đệm an toàn.
    - Nút hành động theo quan hệ: nếu là mình ("Chỉnh sửa hồ sơ", "Bài đã lưu"); nếu là người khác ("Thêm bạn" / "Hủy lời mời" / "Chấp nhận" + "Từ chối" / "Nhắn tin" + "Bạn bè" -> "Hủy kết bạn", "Theo dõi" / "Đang theo dõi", menu "Báo cáo", "Chặn / Bỏ chặn").
    - Bố cục 2 cột kiểu Facebook cho Tab "Bài viết" trên Desktop:
      - Cột trái (Sidebar widget): Widget "Giới thiệu" (nơi sống, quê quán, việc làm, học vấn, website, tham gia từ), Widget "Ảnh" (lưới 6 ảnh thu nhỏ kèm nút xem tất cả mở lightbox), Widget "Bạn bè" (lưới 6 bạn bè tiêu biểu kèm avatar và liên kết).
      - Cột phải: Hộp tạo bài viết nhanh (`CreatePostCard` khi là chủ tài khoản) và Danh sách bài viết (`PostCard`).
    - Các tab chuyên sâu: "Bài viết", "Giới thiệu", "Ảnh" (`GET /users/{id}/photos` có badge đếm số lượng), "Bạn bè" (`GET /users/{id}/friends` có badge đếm số lượng).
  - Trang bạn bè (`/friends`):
    - Bộ lọc danh mục ("Tất cả mọi người", "Danh sách bạn bè", "Người bạn có thể biết").
    - Ô tìm kiếm bạn bè / người dùng thời gian thực (debounced `GET /users?q=...`).
    - Lời mời kết bạn (`GET /friend-requests`): chấp nhận (`POST /friend-requests/{id}/accept`), từ chối (`DELETE /friend-requests/{id}`).
    - Người bạn có thể biết (`GET /users/suggestions`): hiển thị số lượng bạn chung, nút gửi lời mời kết bạn.
    - Danh sách bạn bè: nhắn tin, hủy kết bạn (`DELETE /friends/{id}`).
- **Giai đoạn 5 (Thông báo / Chat / Notifications & Messenger):**
  - Quản lý Badge toàn cục (`BadgeContext` & `BadgeProvider`):
    - Tự động lấy số thông báo chưa đọc (`GET /notifications/unread-count`) và tổng tin nhắn chưa đọc từ các hội thoại (`GET /conversations`).
    - Hiển thị badge số lượng màu đỏ trên biểu tượng Thông báo, Tin nhắn ở `Header`, `Sidebar`, và `BottomNav`.
    - Chu kỳ polling mỗi 30 giây và cập nhật lạc quan tức thì khi đọc tin nhắn/thông báo.
  - Trang thông báo (`/notifications`):
    - Bộ lọc tab: "Tất cả", "Tương tác", "Lời mời kết bạn".
    - Nút "Đánh dấu tất cả đã đọc" (`POST /notifications/read`).
    - Click vào từng thông báo: đánh dấu đã đọc (`POST /notifications/{id}/read`), điều hướng đến bài viết liên quan (`/posts/[id]`) hoặc hồ sơ người tương tác (`/profile/[id]`).
    - Phân trang dạng cuộn / tải thêm với con trỏ cursor (`nextCursor`).
    - Tự động định dạng icon, nhãn tiếng Việt theo loại sự kiện (`like`, `comment`, `share`, `friend_request`, `friend_accepted`, `follow`).
  - Trang nhắn tin / Messenger (`/messages` & `/messages/[id]`):
    - Bố cục thích ứng (responsive layout):
      - Trên desktop: giao diện 2 cột split-view hiện đại (danh sách hội thoại bên trái, khung trò chuyện bên phải; hiển thị màn hình chờ thân thiện khi chưa chọn hội thoại).
      - Trên mobile: danh sách hội thoại toàn màn hình; khi bấm chọn một cuộc trò chuyện sẽ chuyển mượt sang khung chat kèm nút quay lại.
    - Hỗ trợ tham số truy vấn `?user={id}` (từ trang cá nhân hoặc danh sách bạn bè): tự động mở hoặc tạo mới cuộc hội thoại với người dùng đó (`POST /conversations`).
    - Danh sách hội thoại (`ConversationList`): tìm kiếm thời gian thực (debounced `GET /conversations?q=...`), hiển thị tin nhắn cuối cùng, thời gian gửi, số tin nhắn chưa đọc, chỉ báo người trò chuyện đang online.
    - Tạo cuộc trò chuyện mới (`NewConversationModal`): chọn nhanh từ danh sách bạn bè với ô tìm kiếm.
    - Khung trò chuyện (`ChatPane`):
      - Header: hiển thị ảnh đại diện, tên người trò chuyện, trạng thái online ("Đang hoạt động" / "Hoạt động X phút trước"), liên kết xem trang cá nhân.
      - Tin nhắn: phân biệt rõ ràng tin nhắn của tôi vs đối phương, hiển thị thời gian gửi, nhãn trạng thái đã gửi / đã nhận.
      - Đính kèm đa phương tiện: gửi nhiều ảnh (kèm lightbox xem phóng to), gửi file đính kèm tài liệu với kích thước và nút tải xuống.
      - Thanh biểu cảm nhanh (quick emojis: 😊, ❤️, 👍, 🎉, 🔥, 😂, 👏, ✨).
      - Trạng thái đang gõ (typing indicator): gửi tín hiệu gõ phím khi nhập văn bản (`PUT /conversations/{id}/typing`, tự động hủy sau 3 giây hoặc khi gửi xong `DELETE /conversations/{id}/typing`), hiển thị hiệu ứng bong bóng 3 chấm "Đang gõ..." khi đối phương soạn tin.
      - Chu kỳ polling 4 giây cập nhật tin nhắn mới (`GET /conversations/{id}/messages?after={lastId}`) và tự động đánh dấu đã đọc (`POST /conversations/{id}/read`).
      - Hỗ trợ header `Idempotency-Key` (UUID) chống trùng lặp tin nhắn khi mạng chập chờn.
- **Giai đoạn 6 (Story / Nhạc / Stories & Music / Media):**
  - Hằng số & Màu nền (`STORY_BACKGROUNDS`, `STORY_PRIVACY_OPTIONS`, `getStoryGradient`): 4 bộ dải màu gradient chuẩn (`indigo`, `sunset`, `mint`, `berry`) và 3 mức riêng tư (`friends`, `public`, `only_me`).
  - Hộp thoại chọn nhạc nền (`TrackPickerModal`):
    - Tìm kiếm thời gian thực bài hát theo tên hoặc nghệ sĩ trên danh mục Apple Music Việt Nam (`GET /music/search?q=...` với debounce).
    - Nghe thử trực tiếp bản xem trước 30 giây (`previewUrl`) với nút Play/Pause.
    - Hiển thị ảnh bìa album, tên bài hát, nghệ sĩ, và link liên kết mở ứng dụng Apple Music.
  - Tạo Story (`/stories/create`):
    - Khung xem trước dạng điện thoại tỷ lệ chuẩn 9:16.
    - Hỗ trợ 2 chế độ: Story chữ trên nền dải màu gradient (4 tùy chọn màu) hoặc Story ảnh (tải ảnh lên tối đa 10MB, hỗ trợ xóa ảnh).
    - Soạn thảo văn bản căn giữa độ tương phản cao, tối đa 500 ký tự.
    - Đính kèm bài hát từ Apple Music (kèm nút nghe thử hoặc gỡ nhạc).
    - Lựa chọn quyền riêng tư (Bạn bè, Công khai, Chỉ mình tôi).
    - Đăng tin (`POST /stories` multipart hoặc json) kèm header `Idempotency-Key` (UUID).
  - Trình xem Story tương tác (`/stories`):
    - Tự động hiển thị toàn màn hình (fullscreen immersive view) tách biệt khỏi layout trang web thông thường.
    - Hỗ trợ nạp toàn bộ tin đang hoạt động (`GET /stories`) hoặc tin theo người dùng (`GET /users/{id}/stories`), bắt đầu từ `?id={storyId}`.
    - Thanh tiến trình phân đoạn (segmented progress bar): mỗi đoạn tương ứng với một story (thời lượng 5 giây).
    - Tự động chuyển story tiếp theo khi hết giờ hoặc đóng khi xem hết.
    - Điều khiển tiến trình: Bấm giữ chuột / chạm màn hình / giữ phím Space để tạm dừng (pause); thả tay để tiếp tục (resume).
    - Chuyển story mượt mà: bấm vào nửa trái màn hình (hoặc mũi tên trái) để xem story trước; bấm nửa phải (hoặc mũi tên phải) để sang story sau; phím Esc để đóng.
    - Phát nhạc nền preview 30s lặp lại khi story có đính kèm nhạc, kèm nút bật/tắt âm thanh (Mute/Unmute).
    - Tự động đánh dấu đã xem (`POST /stories/{id}/view`).
    - Tính năng cho người xem: Thả biểu cảm nhanh (❤️, 😂, 😮, 😢, 👏, 🔥) kèm animation hiệu ứng bay lên; nhập tin nhắn phản hồi story trực tiếp qua hội thoại Messenger (`POST /conversations/{id}/messages`).
    - Tính năng cho chủ sở hữu tin: Đổi nhanh quyền riêng tư (`PATCH /stories/{id}`), xóa tin (`DELETE /stories/{id}`) có hộp thoại xác nhận.
- **Giai đoạn 7 (Hoàn thiện / Polishing, Responsive, Explore/Saved, và Kiểm tra tổng thể):**
  - Cấu hình kết nối Backend qua ngrok (`.env.local`):
    - `BACKEND_API_URL=https://imminent-ninetieth-stark.ngrok-free.dev/api/v1`
    - Bổ sung header `ngrok-skip-browser-warning: "true"` xuyên suốt proxy server Next.js và các endpoint auth để bypass cảnh báo ngrok miễn phí một cách liền mạch.
  - Trang Khám phá (`/explore`):
    - Tìm kiếm đa năng: tìm kiếm bài viết và người dùng theo từ khóa thời gian thực (debounced).
    - Bộ lọc danh mục khám phá chuẩn: "Dành cho bạn" (`for_you`), "Đang thịnh hành" (`trending` theo lượt thích), "Video ngắn" (`short_video` chỉ lấy video đã xử lý ready).
    - Tab chuyển đổi kết quả tìm kiếm: "Bài viết" vs "Mọi người" (thẻ người dùng hiển thị avatar, họ tên, username, nút Xem hồ sơ).
    - Phân trang cursor mượt mà với nút "Tải thêm bài viết".
  - Trang Bài đã lưu (`/saved`):
    - Danh sách các bài viết đã lưu (`GET /me/saved-posts`).
    - Bỏ lưu (`onPostSaved` -> `DELETE /posts/{id}/save`): tự động cập nhật xóa bài viết khỏi danh sách đã lưu ngay lập tức mà không cần reload trang.
    - Màn hình rỗng (Empty state) hiện đại kèm nút dẫn sang trang Khám phá.
  - Trang Tạo bài viết di động (`/create-post`):
    - Phục vụ nút `+` chính giữa thanh điều hướng `BottomNav` trên thiết bị di động, tự động chuyển về trang chủ sau khi đăng bài.
  - Micro-interactions & Kiểm tra toàn diện Responsive:
    - Bố cục responsive hoàn hảo: Desktop (Sidebar cố định 288px, Header dính với ô tìm kiếm & badge, max-w-7xl), Mobile (BottomNav 5 nút thao tác nhanh, nút tạo bài nhô cao, Header nhỏ gọn).
    - Hiệu ứng tương tác cao cấp: hover trên nút bấm/thẻ bài viết, animation pop khi thả tim, animation floating khi thả emoji story, hiệu ứng skeleton/loader khi tải trang.
    - Tự động đồng bộ chế độ sáng/tối (Dark/Light Mode).
  - Tính năng Ghi chú (Notes phong cách Facebook / Instagram Messenger):
    - Hàng khay ghi chú (`NotesTray`): hiển thị ở đầu danh sách hội thoại Messenger (`/messages`).
    - Ghi chú của tôi: bấm để tạo mới (`CreateNoteModal`), xem, chỉnh sửa hoặc gỡ ghi chú (`PUT/DELETE /me/note`).
    - Bong bóng suy nghĩ (thought bubble): lơ lửng trên avatar người dùng, hiển thị nội dung ngắn tối đa 60 ký tự, tự động hết hạn sau 24 giờ.
    - Đính kèm bài hát Apple Music: tìm kiếm bài hát (`GET /music/search`), nghe thử đoạn 30 giây trực tiếp trong popup ghi chú (`ViewNoteModal`).
    - Phản hồi ghi chú bạn bè: nhập tin nhắn phản hồi trực tiếp từ popup, tự động gửi tin nhắn đến bạn bè qua hội thoại Messenger (`POST /conversations/{id}/messages`).
    - Hiển thị trên Trang cá nhân (`ProfileView`): bong bóng ghi chú lơ lửng trên avatar lớn của hồ sơ cá nhân khi người đó có ghi chú hoạt động.
- **Nâng cấp giao diện Modern Social Network (UI Polish & 3-Column Layout):**
  - **Bố cục 3 cột chuẩn Desktop:** Tích hợp `RightSidebar` cố định trên màn hình rộng `xl+` tại Trang chủ (`/`) và Khám phá (`/explore`). Hiển thị danh sách bạn bè đang online kèm avatar & chỉ báo thời gian thực, widget "Gợi ý kết bạn" 1-click, và footer điều khoản/bản quyền.
  - **Menu người dùng Header (Desktop User Dropdown Menu):** Bấm avatar trên Header mở menu popup cao cấp với thẻ định danh cá nhân, liên kết Hồ sơ, Bài đã lưu, Cài đặt, nút gạt Dark/Light Mode tức thì, và Đăng xuất an toàn.
  - **Chuẩn hóa Token Hệ thống Màu 100%:** Cấu hình bảng màu ngữ nghĩa (`brand`, `brand.light`, `surface`, `appBorder`, `appText`, `like`) trong `tailwind.config.ts`. Thay thế toàn diện 1.247 class `slate-*` và `indigo-*` bằng token semantic chuẩn giúp theme Dark/Light đồng nhất và mượt mà.
  - **Micro-interactions & Đổ bóng:** Thêm `shadow-card`, `hover:shadow-card-hover`, hoạt ảnh `animate-like-pop` và màu tim đỏ rực `text-like`, chống nháy giao diện khi tải trang (`THEME_INIT_SCRIPT`).
  - **Hệ thống In-App Toast Notification toàn cục (`ToastContext` & `ToastContainer`):**
    - Cung cấp hook `useToast()` với các phương thức `toast.success()`, `toast.error()`, `toast.info()`, `toast.warning()`, và `showToast(msg, undoFn)`.
    - Giao diện nổi kính mờ cao cấp (`backdrop-blur-md`), đổ bóng sâu, hoạt ảnh trượt vào mượt mà (`animate-toast-in`), tự động biến mất sau 3 giây, hỗ trợ tối đa 4 thông báo đồng thời.
    - Hỗ trợ nút hành động đảo ngược (Undo Action, e.g. hoàn tác ẩn bài viết) và nút đóng nhanh.
    - Định vị thông minh: góc dưới phải trên desktop (`md:bottom-6 md:right-6`) và góc dưới màn hình trên mobile (`bottom-20`), không che thanh điều hướng `BottomNav`.
    - Thay thế toàn diện các popup `alert()` trình duyệt và các thanh thông báo cục bộ cũ tại PostCard, ProfileView, FeedView, Friends, Notifications, Chat, Stories, Comments.
- **Development commands:**
  - `cd web && npm run typegen`: Cập nhật kiểu từ `docs/api/openapi.yaml`.
  - `cd web && npm test`: Chạy toàn bộ unit test với Vitest.
  - `cd web && npm run build`: Kiểm tra type check và build ứng dụng Next.js.

