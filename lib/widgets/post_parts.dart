import 'package:flutter/material.dart';
import 'package:flutter_learning/data/post_reactions.dart';
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
    final feelingAndPrivacy = [
      if (showFeeling && post.feeling?.isNotEmpty == true)
        'đang ${post.feeling!.toLowerCase()}',
      if (post.privacy?.isNotEmpty == true) post.privacy!,
    ].join(' · ');
    final timeLine = showFeeling
        ? post.createdAt
        : [
            post.createdAt,
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
                        timeLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: secondary),
                      ),
                      if (showFeeling && feelingAndPrivacy.isNotEmpty)
                        Text(
                          feelingAndPrivacy,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
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
  final IconData? icon;
  final Widget? customWidget;
  final int? count;
  final String tooltip;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Color? color;

  /// Plays a small "pop" when this flips from false to true (used by like).
  final bool active;

  const PostAction({
    super.key,
    this.icon,
    this.customWidget,
    required this.tooltip,
    required this.semanticsLabel,
    this.count,
    this.onPressed,
    this.onLongPress,
    this.color,
    this.active = false,
  }) : assert(
         icon != null || customWidget != null,
         'Either icon or customWidget must be provided',
       );

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
          onLongPress: onLongPress,
          style: TextButton.styleFrom(
            foregroundColor: iconColor,
            minimumSize: const Size(36, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customWidget != null)
                _PopWidget(active: active, child: customWidget!)
              else
                _PopIcon(icon: icon!, color: iconColor, active: active),
              if (count != null) ...[
                const SizedBox(width: 4),
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
          size: 19,
          color: widget.color,
        ),
      ),
    );
  }
}

/// Scales a custom widget 1 → 1.25 → 1 whenever [active] turns on.
class _PopWidget extends StatefulWidget {
  final Widget child;
  final bool active;

  const _PopWidget({required this.child, required this.active});

  @override
  State<_PopWidget> createState() => _PopWidgetState();
}

class _PopWidgetState extends State<_PopWidget>
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
  void didUpdateWidget(covariant _PopWidget oldWidget) {
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
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// Floating reactions bar capsule (Like, Love, Haha, Wow, Sad, Angry)
class _ReactionsBarCapsule extends StatefulWidget {
  final ValueChanged<PostReaction> onSelect;
  const _ReactionsBarCapsule({required this.onSelect});

  @override
  State<_ReactionsBarCapsule> createState() => _ReactionsBarCapsuleState();
}

class _ReactionsBarCapsuleState extends State<_ReactionsBarCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();

  int? _hoveredIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      alignment: Alignment.bottomLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242526) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(kPostReactions.length, (index) {
            final rx = kPostReactions[index];
            final isHovered = _hoveredIndex == index;
            return Tooltip(
              message: rx.label,
              child: GestureDetector(
                onTap: () => widget.onSelect(rx),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hoveredIndex = index),
                  onExit: (_) => setState(() => _hoveredIndex = null),
                  child: AnimatedScale(
                    scale: isHovered ? 1.35 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                      child: Text(
                        rx.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Like · comment · share on the left, an optional save button on the right.
/// Supports Facebook-style multi-reactions via long-press.
class PostActionBar extends StatefulWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  /// When null the save button is not shown.
  final VoidCallback? onToggleSave;
  final bool isSaved;
  final ValueChanged<PostReaction>? onReactionSelected;

  const PostActionBar({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onToggleSave,
    this.isSaved = false,
    this.onReactionSelected,
  });

  @override
  State<PostActionBar> createState() => _PostActionBarState();
}

class _PostActionBarState extends State<PostActionBar> {
  PostReaction? _currentReaction;

  @override
  void didUpdateWidget(covariant PostActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.post.isLiked) {
      _currentReaction = null;
    }
  }

  void _showReactionMenu(BuildContext anchorContext) {
    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay = Overlay.of(context);
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => entry.remove(),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: (position.dx - 10).clamp(12.0, screenWidth - 280),
            top: position.dy - 54 > 30
                ? position.dy - 54
                : position.dy + size.height + 6,
            child: Material(
              color: Colors.transparent,
              child: _ReactionsBarCapsule(
                onSelect: (reaction) {
                  entry.remove();
                  setState(() => _currentReaction = reaction);
                  if (!widget.post.isLiked) {
                    widget.onLike?.call();
                  }
                  widget.onReactionSelected?.call(reaction);
                },
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(entry);
  }

  void _handleLikeTap() {
    if (widget.post.isLiked) {
      setState(() => _currentReaction = null);
      widget.onLike?.call();
    } else {
      setState(() => _currentReaction = null);
      widget.onLike?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isLiked = widget.post.isLiked;
    final hasCustomReaction = isLiked && _currentReaction != null;

    final Color likeColor = hasCustomReaction
        ? _currentReaction!.color
        : palette.like;

    return Builder(
      builder: (btnContext) {
        return Row(
          mainAxisSize: widget.onToggleSave != null
              ? MainAxisSize.max
              : MainAxisSize.min,
          children: [
            PostAction(
              icon: hasCustomReaction
                  ? null
                  : (isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded),
              customWidget: hasCustomReaction
                  ? Text(
                      _currentReaction!.emoji,
                      style: const TextStyle(fontSize: 18),
                    )
                  : null,
              count: widget.post.likes,
              color: isLiked ? likeColor : null,
              active: isLiked,
              tooltip: isLiked ? 'Bỏ thích' : 'Thích bài viết',
              semanticsLabel: isLiked
                  ? 'Bỏ thích bài viết, ${widget.post.likes} lượt thích'
                  : 'Thích bài viết, ${widget.post.likes} lượt thích',
              onPressed: _handleLikeTap,
              onLongPress: () => _showReactionMenu(btnContext),
            ),
            PostAction(
              icon: Icons.chat_bubble_outline_rounded,
              count: widget.post.comments,
              tooltip: 'Bình luận',
              semanticsLabel: 'Bình luận, ${widget.post.comments} bình luận',
              onPressed: widget.onComment,
            ),
            if (widget.onShare != null)
              PostAction(
                icon: Icons.share_outlined,
                count: widget.post.shares,
                tooltip: 'Chia sẻ',
                semanticsLabel: 'Chia sẻ, ${widget.post.shares} lượt chia sẻ',
                onPressed: widget.onShare,
              ),
            if (widget.onToggleSave != null) ...[
              const Spacer(),
              PostAction(
                icon: widget.isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: widget.isSaved ? palette.brand : null,
                active: widget.isSaved,
                tooltip: widget.isSaved ? 'Bỏ lưu bài viết' : 'Lưu bài viết',
                semanticsLabel: widget.isSaved
                    ? 'Bỏ lưu bài viết'
                    : 'Lưu bài viết',
                onPressed: widget.onToggleSave,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Wrapper for feed items; kept lightweight so scrolling large lists does not
/// schedule per-card animations on every frame.
class FadeInUp extends StatelessWidget {
  final Widget child;

  const FadeInUp({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
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
