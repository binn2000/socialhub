import 'package:flutter/material.dart';
import 'package:flutter_learning/models/post.dart';
import 'package:flutter_learning/models/user.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

/// Shared building blocks for post cards (Home feed, post detail, saved).

/// Shrinks its child slightly while pressed, a quiet "tap" feedback for
/// cards and pills that are not buttons.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.98,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}

/// A number that slides softly when it changes (like/comment counts).
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;

  const AnimatedCount({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: AppMotion.curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text('$value', key: ValueKey(value), style: style),
    );
  }
}

/// Avatar, author name and a quiet meta line (time · feeling · audience).
class PostHeader extends StatelessWidget {
  final Post post;
  final ValueChanged<UserModel>? onOpenProfile;
  final Widget? trailing;
  final bool showFeeling;

  const PostHeader({
    super.key,
    required this.post,
    this.onOpenProfile,
    this.trailing,
    this.showFeeling = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final meta = [
      post.createdAt,
      if (showFeeling && post.feeling?.isNotEmpty == true)
        'đang ${post.feeling!.toLowerCase()}',
      if (post.privacy?.isNotEmpty == true) post.privacy!,
    ].join(' · ');

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onOpenProfile == null
                ? null
                : () => onOpenProfile!(post.author),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Row(
              children: [
                UserAvatar(imageUrl: post.author.avatarUrl, radius: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// One compact action: icon plus count, left aligned (not a full-width
/// button row).
class PostAction extends StatelessWidget {
  final IconData icon;
  final int? count;
  final String tooltip;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final Color? color;

  /// Plays a small "pop" when this flips from false to true (used by like).
  final bool active;

  const PostAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.semanticsLabel,
    this.count,
    this.onPressed,
    this.color,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: iconColor,
            minimumSize: const Size(44, 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PopIcon(icon: icon, color: iconColor, active: active),
              if (count != null) ...[
                const SizedBox(width: 6),
                AnimatedCount(
                  value: count!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Scales the icon 1 → 1.25 → 1 whenever [active] turns on.
class _PopIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool active;

  const _PopIcon({
    required this.icon,
    required this.color,
    required this.active,
  });

  @override
  State<_PopIcon> createState() => _PopIconState();
}

class _PopIconState extends State<_PopIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.25), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1), weight: 60),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant _PopIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        child: Icon(
          widget.icon,
          key: ValueKey(widget.icon),
          size: 21,
          color: widget.color,
        ),
      ),
    );
  }
}

/// Like · comment · share on the left, an optional save button on the right.
class PostActionBar extends StatelessWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  /// When null the save button is not shown.
  final VoidCallback? onToggleSave;
  final bool isSaved;

  const PostActionBar({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onToggleSave,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        PostAction(
          icon: post.isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          count: post.likes,
          color: post.isLiked ? palette.like : null,
          active: post.isLiked,
          tooltip: post.isLiked ? 'Bỏ thích' : 'Thích bài viết',
          semanticsLabel: post.isLiked
              ? 'Bỏ thích bài viết, ${post.likes} lượt thích'
              : 'Thích bài viết, ${post.likes} lượt thích',
          onPressed: onLike,
        ),
        PostAction(
          icon: Icons.chat_bubble_outline_rounded,
          count: post.comments,
          tooltip: 'Bình luận',
          semanticsLabel: 'Bình luận, ${post.comments} bình luận',
          onPressed: onComment,
        ),
        if (onShare != null)
          PostAction(
            icon: Icons.share_outlined,
            count: post.shares,
            tooltip: 'Chia sẻ',
            semanticsLabel: 'Chia sẻ, ${post.shares} lượt chia sẻ',
            onPressed: onShare,
          ),
        const Spacer(),
        if (onToggleSave != null)
          PostAction(
            icon: isSaved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: isSaved ? palette.brand : null,
            active: isSaved,
            tooltip: isSaved ? 'Bỏ lưu bài viết' : 'Lưu bài viết',
            semanticsLabel: isSaved ? 'Bỏ lưu bài viết' : 'Lưu bài viết',
            onPressed: onToggleSave,
          ),
      ],
    );
  }
}

/// Fades and lifts a feed item into place the first time it is built.
class FadeInUp extends StatelessWidget {
  final Widget child;

  const FadeInUp({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
    );
  }
}

/// Surface card that highlights its border and lifts slightly on desktop/web
/// pointer hover.
class HoverableCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final Color? borderColor;

  const HoverableCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.md,
    this.color,
    this.borderColor,
  });

  @override
  State<HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<HoverableCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        margin: widget.margin,
        padding: widget.padding,
        decoration: AppDecorations.card(
          context,
          radius: widget.radius,
          color: widget.color,
          borderColor: widget.borderColor,
          hovered: _hovered,
        ),
        child: widget.child,
      ),
    );
  }
}
