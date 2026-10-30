import 'package:flutter/material.dart';
import 'package:flutter_learning/models/story.dart';
import 'package:flutter_learning/theme/app_tokens.dart';
import 'package:flutter_learning/widgets/post_parts.dart';
import 'package:flutter_learning/widgets/user_avatar.dart';

class StoryItem extends StatelessWidget {
  final Story? story;
  final VoidCallback? onTap;
  final bool isAddButton;

  const StoryItem({
    super.key,
    this.story,
    this.onTap,
    this.isAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (isAddButton) {
      return _tappable(
        label: 'Thêm tin mới',
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: palette.brandSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.brand.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(Icons.add_rounded, size: 28, color: palette.brand),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Thêm tin',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentStory = story!;
    return _tappable(
      label: 'Xem tin của ${currentStory.user.name}',
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            UserAvatar(
              imageUrl: currentStory.user.avatarUrl,
              radius: 29.5,
              showBorder: true,
              // Unseen stories use the single brand color ring; seen stories
              // use a subtle border ring.
              borderColors: currentStory.isViewed
                  ? [palette.border]
                  : [palette.brand],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              currentStory.user.name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: currentStory.isViewed
                    ? FontWeight.w500
                    : FontWeight.w600,
                color: currentStory.isViewed
                    ? palette.textSecondary
                    : palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wraps a tile so screen readers announce it as a labelled button.
  Widget _tappable({required String label, required Widget child}) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressableScale(onTap: onTap, child: child),
    );
  }
}
