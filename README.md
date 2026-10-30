# SocialHub

SocialHub is a Flutter social-network UI MVP. It runs entirely on the device
with mock data: there is no backend, no login and no saved storage. The UI is
in Vietnamese.

## Features

- **Home feed**: posts with author, time, feeling and privacy, image, and like,
  comment and share counts.
- **Stories**: a story row on Home, a full-screen story viewer with swiping,
  and a story creator (text on a coloured background).
- **Create Post**: text, a mock image picker, feeling and privacy, with a live
  preview. Empty posts are rejected.
- **Explore**: a grid of the current posts with search and filters
  (*Dành cho bạn*, *Đang thịnh hành*, *Video ngắn*). Tapping a post shows its
  details.
- **Friends**: user list with search and *Thêm bạn → Đang chờ → Bạn bè*.
- **Notifications**: seeded notifications, an unread badge on the tab, and
  navigation when a notification is tapped.
- **Profile**: the current user's info and posts, plus Edit Profile (name and
  bio).
- **Messages and Chat**: conversation list with unread counts; sending a
  message updates the preview and time.
- **Search on Home**: filters the feed by post text or author name, ignoring
  case.
- **Like**: switches the like state and count everywhere the post appears.
- **Comment and share**: open sheets and show a confirmation. These are mock
  actions and don't change the counts.
- **Save**: the post menu saves or unsaves a post, shown by a bookmark icon.
- **Hide and Undo**: the post menu hides a post from Home, with Undo in the
  confirmation.
- **Dark mode**: a toggle in the Home app bar. Screens use Material 3 theme
  colours.
- **Accessibility**: icon-only buttons have tooltips; custom tap targets
  (story tiles, Explore post cards, filters, menu actions, notification and message
  rows) have screen-reader labels and selected or toggled states.

## Architecture

- **`MainScreen` owns all changing app state** in a `StatefulWidget` using
  `setState`: current user, users, posts, stories, conversations,
  notifications, saved post IDs, hidden post IDs and the selected tab. There is
  no state-management package.
- **Mock data is only the starting point.** `lib/data/mock_data.dart` is copied
  into `MainScreen` once at startup. After that, screens only show what
  `MainScreen` passes them and report changes back through callbacks (for
  example `onToggleLike` or `onPostCreated`).
- **Screens keep only UI state**, such as search text, the selected filter or
  a friend request in progress. Search and filter results are worked out from
  the posts passed in on every build; they are never stored as a second list.
- **Hidden and saved posts are stored as sets of post IDs.** Posts are never
  removed or changed to hide or save them. Home gets `_posts` without the
  hidden IDs, while Explore and Profile get every post.
- **Navigation**: the bottom navigation tabs are listed in the `AppTab` enum
  (Home, Explore, Friends, Create Post, Notifications, Profile). Tab screens
  sit in an `IndexedStack`, so they keep their state when you switch tabs.
  Messages, Chat, Edit Profile and the story screens are pushed as routes.

## Project structure

```
lib/
├── main.dart                 App, themes and MainScreen (app state)
├── data/mock_data.dart       Starting data: users, posts, stories, chats, notifications
├── models/                   Plain immutable data classes
│   ├── post.dart             Post (with copyWith)
│   ├── user.dart             UserModel (with copyWith)
│   ├── story.dart
│   ├── message.dart          ChatMessage, Conversation
│   └── notification.dart     SocialNotification
├── screens/                  One file per screen
│   ├── home_screen.dart      Feed, stories row, search, post menu (save / hide)
│   ├── explore_screen.dart   Grid, search, filters, post details sheet
│   ├── friends_screen.dart
│   ├── create_post_screen.dart
│   ├── notifications_screen.dart
│   ├── profile_screen.dart / edit_profile_screen.dart
│   ├── messages_screen.dart / chat_screen.dart
│   └── story_viewer_screen.dart / story_creator_screen.dart
├── utils/post_search.dart    Search matching shared by Home and Explore
└── widgets/
    ├── bottom_nav.dart       SocialBottomNav and the AppTab enum
    ├── mock_image.dart       Mock image choices, PostMedia, gradient fallbacks
    ├── story_item.dart       Story tile and "Thêm tin" tile
    └── user_avatar.dart
test/                         Widget and unit tests, one file per feature
```

## Running

```sh
flutter pub get
flutter run
```

This runs on the built-in mock data (no sign-in, no server). To use the Laravel
backend in `backend/api` instead, start it (`php artisan serve`, PHP 8.5) and pass
its address:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

On the Android emulator use `http://10.0.2.2:8000/api/v1`. The first screen is
then sign-in / sign-up.

## Testing

```sh
flutter analyze
flutter test
```

`test/test_helpers.dart` has shared helpers for starting the app, switching
tabs and using the post menu.

## Intentional limitations

- **No backend and no login.** Everything runs locally from mock data.
- **Nothing is saved.** Posts, likes, profile edits, friend requests, chats,
  and saved and hidden posts all reset when the app restarts.
- **Mock images.** Choosing an image picks one of three preset gradients; there
  is no camera or gallery. Seed images use a 1×1 placeholder, so gradients are
  shown instead.
- **Comments and shares are mock actions.** They show a confirmation but don't
  change the counts or keep comments.
- **The *Video ngắn* filter is always empty**, because posts have no video
  support.
- ***Đang thịnh hành* means "most liked"**, with no time weighting.
- **There is no Saved Posts screen**, and a post can only be un-hidden with
  Undo right after hiding it.
- **Chat is local.** Nobody replies, and messages exist only in this session.
- **Notifications are seeded.** No new notifications arrive, and opening the
  Notifications tab marks them all as read.
- **Stories don't track "viewed"**, and the heart button in the story viewer
  does nothing.
