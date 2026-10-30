import 'package:flutter/material.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/mock_image.dart';
import 'package:flutter_learning/widgets/post_parts.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

/// Sections on the profile screen (4.4: Posts, About, Photos, Friends).
enum ProfileSection {
  posts('Bài viết'),
  about('Giới thiệu'),
  photos('Ảnh'),
  friends('Bạn bè');

  final String label;
  const ProfileSection(this.label);
}

class ProfileScreen extends StatefulWidget {
  final List<Post> posts;
  final UserModel user;

  /// Friends to list under the "Bạn bè" tab.
  final List<UserModel> friends;

  /// Opens a friend's profile when tapped in the "Bạn bè" tab.
  final ValueChanged<UserModel>? onOpenProfile;

  /// The "Edit Profile" button. Null when this is someone else's profile.
  final VoidCallback? onEditProfile;

  /// Shown where the edit button is, for someone else's profile (the friend
  /// buttons).
  final Widget? action;

  /// Shown only when the app is signed in to a server.
  final VoidCallback? onLogout;

  /// Opens the list of saved posts. Shown with the edit button on your own
  /// profile.
  final VoidCallback? onOpenSaved;

  /// Opens the email confirmation screen. Set only for your own profile
  /// when the server says the email is not confirmed yet.
  final VoidCallback? onVerifyEmail;

  const ProfileScreen({
    super.key,
    required this.posts,
    required this.user,
    this.friends = const [],
    this.onOpenProfile,
    this.onEditProfile,
    this.action,
    this.onLogout,
    this.onOpenSaved,
    this.onVerifyEmail,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileSection _section = ProfileSection.posts;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final user = widget.user;
    final userPosts = widget.posts
        .where((post) => post.author.id == user.id)
        .toList();
    final photoPosts = userPosts
        .where((post) => post.imageUrl != null)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: AppDecorations.card(
                        context,
                        radius: AppRadius.lg,
                      ),
                      child: Column(
                        children: [
                          _ProfileCoverBanner(coverUrl: user.coverUrl),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              0,
                              AppSpacing.xl,
                              AppSpacing.xl,
                            ),
                            child: Column(
                              children: [
                                Transform.translate(
                                  offset: const Offset(0, -38),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: palette.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: UserAvatar(
                                      imageUrl: user.avatarUrl,
                                      radius: 42,
                                      showBorder: true,
                                    ),
                                  ),
                                ),
                                Transform.translate(
                                  offset: const Offset(0, -24),
                                  child: Column(
                                    children: [
                                      Text(
                                        user.name,
                                        textAlign: TextAlign.center,
                                        style: textTheme.headlineSmall,
                                      ),
                                      if (user.username.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          user.username,
                                          style: textTheme.bodySmall,
                                        ),
                                      ],
                                      if (user.bio.isNotEmpty) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          user.bio,
                                          textAlign: TextAlign.center,
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: AppSpacing.md),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.lg,
                                          vertical: AppSpacing.sm + 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: palette.surfaceMuted,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.full,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.article_outlined,
                                              size: 16,
                                              color: colorScheme.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${userPosts.length} bài viết',
                                              style: textTheme.titleSmall,
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.md,
                                                  ),
                                              child: Text(
                                                '·',
                                                style: TextStyle(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.people_alt_outlined,
                                              size: 16,
                                              color: colorScheme.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${user.mutualFriends} bạn bè',
                                              style: textTheme.titleSmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.onEditProfile != null)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: widget.onEditProfile,
                                          child: const Text('Edit Profile'),
                                        ),
                                      ),
                                      if (widget.onOpenSaved != null) ...[
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: widget.onOpenSaved,
                                            icon: const Icon(
                                              Icons.bookmark_border_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('Bài đã lưu'),
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                else
                                  ?widget.action,
                                if (widget.onVerifyEmail != null) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.mark_email_unread_outlined,
                                      color: colorScheme.error,
                                    ),
                                    title: const Text(
                                      'Email chưa được xác thực',
                                    ),
                                    trailing: TextButton(
                                      onPressed: widget.onVerifyEmail,
                                      child: const Text('Xác thực'),
                                    ),
                                  ),
                                ],
                                if (widget.onLogout != null) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  TextButton.icon(
                                    onPressed: widget.onLogout,
                                    icon: const Icon(
                                      Icons.logout_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Đăng xuất'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tab in ProfileSection.values)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: ChoiceChip(
                                label: Text(tab.label),
                                selected: _section == tab,
                                showCheckmark: false,
                                selectedColor: palette.brand,
                                backgroundColor: palette.surface,
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _section == tab
                                      ? Colors.white
                                      : palette.textSecondary,
                                ),
                                side: BorderSide(
                                  color: _section == tab
                                      ? palette.brand
                                      : palette.border,
                                ),
                                onSelected: (_) =>
                                    setState(() => _section = tab),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
            ..._buildSectionSlivers(
              context,
              userPosts: userPosts,
              photoPosts: photoPosts,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSectionSlivers(
    BuildContext context, {
    required List<Post> userPosts,
    required List<Post> photoPosts,
  }) {
    final palette = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;

    switch (_section) {
      case ProfileSection.posts:
        return [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final post = userPosts[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: HoverableCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.content, style: textTheme.bodyLarge),
                        if (post.imageUrl != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          PostMedia(post: post),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 16,
                              color: palette.like,
                            ),
                            const SizedBox(width: 6),
                            Text('${post.likes}', style: textTheme.titleSmall),
                            const Spacer(),
                            Text(
                              '${post.comments} bình luận',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: userPosts.length),
            ),
          ),
        ];

      case ProfileSection.about:
        final user = widget.user;
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: HoverableCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thông tin cá nhân', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    _AboutRow(
                      icon: Icons.badge_outlined,
                      label: 'Họ và tên',
                      value: user.name,
                    ),
                    _AboutRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Tên người dùng',
                      value: user.username.isEmpty ? '—' : user.username,
                    ),
                    _AboutRow(
                      icon: Icons.notes_rounded,
                      label: 'Tiểu sử',
                      value: user.bio.isEmpty ? 'Chưa cập nhật' : user.bio,
                    ),
                    _AboutRow(
                      icon: Icons.people_outline_rounded,
                      label: 'Kết nối',
                      value: '${user.mutualFriends} bạn bè',
                    ),
                    _AboutRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Trạng thái email',
                      value: user.emailVerified
                          ? 'Đã xác thực'
                          : 'Chưa xác thực',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];

      case ProfileSection.photos:
        if (photoPosts.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Center(
                  child: Text(
                    'Chưa có hình ảnh nào',
                    style: textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => PostMedia(post: photoPosts[index]),
                childCount: photoPosts.length,
              ),
            ),
          ),
        ];

      case ProfileSection.friends:
        if (widget.friends.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Center(
                  child: Text(
                    '${widget.user.mutualFriends} bạn bè kết nối',
                    style: textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final friend = widget.friends[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: HoverableCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: InkWell(
                      onTap: widget.onOpenProfile == null
                          ? null
                          : () => widget.onOpenProfile!(friend),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Row(
                        children: [
                          UserAvatar(imageUrl: friend.avatarUrl, radius: 22),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(friend.name, style: textTheme.titleMedium),
                                Text(
                                  '${friend.mutualFriends} bạn chung',
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: palette.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }, childCount: widget.friends.length),
            ),
          ),
        ];
    }
  }
}

/// Calm cover banner at the top of the profile card.
class _ProfileCoverBanner extends StatelessWidget {
  final String coverUrl;

  const _ProfileCoverBanner({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final canLoad = canLoadAssetImage(coverUrl);
    return Container(
      height: 104,
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.brandSoft,
        border: Border(bottom: BorderSide(color: palette.border, width: 0.5)),
      ),
      child: isNetworkImage(coverUrl)
          ? Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : canLoad
          ? Image.asset(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : Stack(
              children: [
                Positioned(
                  right: -24,
                  top: -28,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: palette.brand.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: -16,
                  bottom: -36,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: palette.brand.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AboutRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: palette.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(value, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
