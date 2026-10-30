SocialHub — GitHub Copilot Instructions
1. Project Overview

SocialHub is a learning-focused Flutter mobile application that provides a modern social-network experience inspired by common social media applications.

The project is frontend-only for now and uses mock/local data.

The application must have its own visual identity and must not copy Facebook's branding, logo, proprietary assets, or exact visual identity.

Current goals

Learn Flutter and Dart through a realistic application.

Keep the code easy to read and understand.

Build reusable Flutter widgets.

Maintain a simple and predictable architecture.

Avoid unnecessary complexity.

Keep the application runnable after every significant change.

2. Target Platform

Flutter

Dart

iOS

Target device: iPhone 17 Pro

Target OS: iOS 26

Material 3

Mobile-first design

Responsive layout where practical

Do not introduce platform-specific code unless it is actually required.

3. Development Philosophy

Prioritize:

Readability

Maintainability

Simplicity

Reusability

Consistent UI

Correct Flutter/Dart conventions

Do not optimize prematurely.

Do not introduce complex architecture just because it is considered a best practice for large production applications.

This is currently a learning project.

When there are multiple valid solutions, prefer the simplest solution that fits the existing architecture.

4. Existing Architecture

Keep the existing project structure unless there is a strong reason to change it.

Expected structure:

lib/
├── main.dart
│
├── models/
│   ├── user.dart
│   ├── post.dart
│   ├── story.dart
│   └── message.dart
│
├── screens/
│   ├── home_screen.dart
│   ├── friends_screen.dart
│   ├── create_post_screen.dart
│   ├── notifications_screen.dart
│   ├── profile_screen.dart
│   ├── messages_screen.dart
│   └── chat_screen.dart
│
├── widgets/
│   ├── post_card.dart
│   ├── story_item.dart
│   ├── user_avatar.dart
│   └── bottom_nav.dart
│
└── data/
    └── mock_data.dart


If the actual project structure differs, inspect the existing project before making changes.

Do not blindly recreate the structure above.

5. State Management

The current version intentionally uses:

StatefulWidget

setState()

Do NOT introduce:

Bloc

Cubit

Riverpod

Provider

GetX

Redux

MobX

another state-management framework

unless the user explicitly asks for it.

When state is simple and local, keep it local.

Avoid creating global state unnecessarily.

If the project eventually requires more complex state management, explain why the current approach is becoming insufficient before proposing a migration.

6. Data and Backend

The current application uses mock/local data only.

Do not introduce:

Firebase

Supabase

REST API

GraphQL

authentication backend

database

cloud storage

unless explicitly requested.

Mock data should be centralized where practical, primarily in:

lib/data/mock_data.dart


Models should remain in:

lib/models/


Do not put large amounts of mock data directly inside UI widgets.

7. Navigation

The application currently has five main navigation destinations:

Home

Friends

Create

Notifications

Profile

Use Flutter's existing navigation APIs unless the user explicitly requests another routing solution.

Do not introduce a routing package unnecessarily.

Navigation should remain understandable for someone learning Flutter.

If a screen such as Messages or Chat is opened from another screen, use straightforward Flutter navigation.

8. UI and Design System

Use Material 3.

The SocialHub visual identity should remain distinct from Facebook.

General style

Modern

Clean

Minimal

Mobile-first

Friendly

Consistent

Colors

The application should use its own primary color system.

Do not use Facebook's exact branding colors as the application's identity.

Prefer defining colors centrally rather than scattering raw color values throughout widgets.

Background

The current design uses a light background similar to:

#F5F6F8


Cards should generally use white or appropriate Material surface colors.

Border radius

Prefer consistent rounded corners around:

12–16


Do not randomly use many different corner radii.

Spacing

Use a consistent spacing system.

Prefer reusable constants when the same spacing values are repeatedly used.

Typography

Typography should be clear and readable.

Use Material 3's typography system where appropriate instead of manually defining every text style.

9. Responsive UI

The primary target is mobile.

Design primarily for:

iPhone 17 Pro


However, avoid hardcoding dimensions that unnecessarily break on other mobile screen sizes.

Prefer:

MediaQuery

LayoutBuilder

flexible widgets

Expanded

Flexible

SafeArea

Avoid unnecessary fixed widths/heights.

Do not create desktop layouts unless explicitly requested.

10. Home Feed

The Home screen should behave like a modern social feed.

Expected sections:

App header

Stories

Create-post prompt

Feed posts

Posts should support:

Avatar

User name

Timestamp

Text content

Optional image

Like count

Comment count

Share count

Like button

Comment button

Share button

Use reusable widgets such as:

PostCard
StoryItem
UserAvatar


Avoid duplicating post UI code in multiple screens.

11. Stories

Stories should be displayed horizontally.

The first story represents the current user and should provide an "Add Story" interaction.

Other stories should display:

Avatar

User name

Story border

When a story is selected, open a simple Story Viewer.

The Story Viewer can remain a frontend/mock implementation.

Do not introduce video infrastructure unless explicitly requested.

12. Create Post

The Create Post screen should support:

User avatar

Text input

Mock image selection

Feeling/activity selection UI

Privacy selector

Post button

When a post is created, it should appear in the feed using the existing state-management approach.

Do not introduce a backend.

Keep the implementation simple enough for a beginner to understand.

13. Profile

The Profile screen should contain:

Cover image

Large avatar

User name

Bio

Friend count

Edit Profile button

Tabs

Expected tabs:

Posts

About

Photos

Friends

Use reusable widgets when UI is shared with other screens.

14. Friends

The Friends screen should support:

Search

Friend list

Avatar

User name

Mutual friends

Friend status/button

Use ListView.builder for dynamic lists.

Do not hardcode repeated widget trees for every friend.

15. Notifications

Notifications should use mock data and ListView.builder.

Possible notification types:

Like

Comment

Friend request

Other social activity

Keep notification rendering reusable where possible.

16. Messages and Chat

Messages should contain:

Conversation list

Avatar

User name

Last message

Timestamp

Unread indicator

Chat screen should contain:

AppBar

Message bubbles

Text input

Send button

For the current version, messages are local/mock only.

No real-time messaging backend should be introduced unless explicitly requested.

17. Dart Style

Follow standard Dart formatting and conventions.

Use:

null safety

meaningful variable names

meaningful class names

small methods

small widgets

immutable data where practical

const where appropriate

Prefer:

const


when widgets and values can safely be compile-time constants.

Avoid unnecessary mutable state.

Avoid abbreviations that make code harder to understand.

18. Flutter Widget Practices

Prefer composition over very large widgets.

If a widget becomes difficult to understand, consider extracting a reusable widget.

For example:

PostCard
StoryItem
UserAvatar
NotificationItem
FriendItem
MessageBubble


Do not create a separate widget for every tiny piece of UI unless it improves readability or reuse.

Avoid deeply nested widget trees when reasonable.

Use ListView.builder for potentially dynamic lists.

Use const constructors where possible.

Use SafeArea where content can conflict with system UI.

19. Dependency Management

Do not add a package unless it provides meaningful value.

Before adding a dependency:

Check whether Flutter/Dart already provides the required functionality.

Check whether the existing project already has a suitable solution.

Consider whether the dependency increases unnecessary complexity.

Explain the reason for the dependency to the user.

Do not add:

state-management packages

networking packages

backend packages

UI frameworks

without explicit approval.

20. Code Changes

Before modifying code:

Inspect the relevant existing files.

Understand the current architecture.

Reuse existing models/widgets/components.

Avoid changing unrelated files.

Preserve existing behavior unless the task requires changing it.

Do not rewrite the entire project for a small feature.

Do not replace working code with a completely different architecture without explaining why.

When modifying an existing feature, make the smallest reasonable change.

21. Error Prevention

After significant code changes, check for:

Missing imports

Undefined widgets

Undefined variables

Incorrect types

Null-safety issues

Incorrect widget lifecycle usage

Incorrect BuildContext usage

Navigation errors

Overflow issues

Missing keys where appropriate

Incorrect setState() usage

Do not claim that code works without checking it when tools are available.

22. Formatting and Analysis

Use Dart formatting.

Preferred command:

dart format .


or, when appropriate:

dart format lib


Run static analysis after significant changes:

flutter analyze


Fix analyzer errors introduced by your changes.

Do not hide analyzer warnings simply to make the output clean.

Do not disable lints unless there is a clear reason.

23. Testing

For the current learning phase, keep testing straightforward.

When modifying non-trivial logic, consider adding tests.

Use Flutter's built-in testing tools before adding external testing frameworks.

Do not introduce complicated testing architecture unnecessarily.

At minimum, ensure the application remains analyzable and buildable after significant changes.

24. Images and Assets

Do not use Facebook logos, Facebook profile images, proprietary Facebook assets, or copied branding.

Use:

generated/mock assets

local placeholder images

neutral image URLs when appropriate

project-owned assets

If an external image service is used temporarily for mock data, make it easy to replace later.

Avoid depending on external image URLs for core application functionality.

25. Accessibility

Where practical:

Use meaningful semantic labels.

Ensure interactive elements are understandable.

Maintain readable text contrast.

Do not communicate important information through color alone.

Make touch targets reasonably large.

Do not sacrifice basic accessibility for visual similarity to a social media design.

26. User Experience

Interactions should feel realistic even though the app is frontend-only.

Examples:

Like button should update like state.

Creating a post should update the feed.

Navigation should work.

Opening a story should show a Story Viewer.

Opening a conversation should show ChatScreen.

Sending a mock message should update the chat UI.

Use local state and mock data for these interactions.

Do not fake functionality by showing static UI when a simple local implementation is possible.

27. Learning-Friendly Code

This is an educational project.

When implementing something non-obvious, prefer clear code over clever code.

Avoid:

unnecessary abstractions

overly generic helper frameworks

metaprogramming

advanced patterns without need

excessive inheritance

unnecessary dependency injection

If a more advanced approach would provide a meaningful benefit, explain it before introducing it.

When appropriate, add short comments explaining WHY something is done.

Do not add comments that simply restate obvious code.

28. Copilot Agent Workflow

When asked to implement a feature:

Step 1 — Inspect

Inspect the relevant project files before writing code.

Step 2 — Understand

Identify:

existing models

existing widgets

current navigation

current state management

existing theme

existing mock data

Step 3 — Plan

Briefly describe the files that need to change.

Step 4 — Implement

Make focused changes using the existing architecture.

Step 5 — Validate

Run or recommend:

flutter analyze


and, when appropriate:

flutter test

Step 6 — Summarize

After implementation, explain:

what changed

which files changed

how the feature works

any limitations

any next steps

Do not provide a long explanation when a short summary is sufficient.

29. Do Not Make Unrequested Architectural Changes

Do not automatically:

migrate state management

introduce Clean Architecture

introduce MVVM

introduce Repository pattern

introduce dependency injection

add Firebase

add a backend

add authentication

add networking

add database storage

unless the user explicitly requests it or the current task genuinely requires it.

If such a change appears necessary, explain the reason first.

30. Working With Existing Code

The existing code is the source of truth.

Do not assume that the initial project specification is more important than the current implementation.

If the project has evolved:

inspect the current implementation

preserve working behavior

adapt to the current architecture

avoid reverting intentional changes

If the specification and implementation conflict, point out the conflict before making a large change.

31. Feature Requests

For a request such as:

Add comments to posts

Do not immediately redesign the application.

Instead:

Inspect Post, PostCard, mock data, and relevant screens.

Determine the smallest architecture-compatible implementation.

Reuse existing models/widgets.

Add only the required state/data.

Validate the affected screens.

Report what changed.

32. Visual Changes

When asked to modify UI:

Preserve existing behavior.

Modify only the necessary components.

Reuse existing colors and spacing.

Maintain Material 3.

Keep the SocialHub visual identity consistent.

Avoid introducing unrelated redesigns.

When a screenshot or visual reference is provided, use it as a layout/UX reference, not as a reason to copy another application's branding or proprietary assets.

33. Important Rules

Always remember:

This is SocialHub, not Facebook.

Keep the project beginner-friendly.

Keep Flutter/Dart architecture simple.

Use StatefulWidget and setState() for the current version.

Do not introduce state-management packages without permission.

Do not introduce a backend without permission.

Reuse existing code.

Do not rewrite unrelated parts of the application.

Prefer simple, readable Flutter code.

Run formatting and analysis after meaningful changes.

Keep the application runnable.

Preserve the existing visual identity.

Do not copy Facebook branding or proprietary assets.