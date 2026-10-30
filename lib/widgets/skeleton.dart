import 'package:flutter/material.dart';
import 'package:flutter_learning/theme/app_tokens.dart';

/// Soft skeleton placeholder blocks used while a screen's data is loading.
/// Uses a finite entrance fade so `pumpAndSettle` in widget tests completes
/// immediately while still giving a calm loading appearance.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.45, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton shaped like a post card (header + text lines + media block).
class PostCardSkeleton extends StatelessWidget {
  final bool showMedia;

  const PostCardSkeleton({super.key, this.showMedia = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              SkeletonBox(width: 40, height: 40, radius: AppRadius.full),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 14),
                    SizedBox(height: 6),
                    SkeletonBox(width: 80, height: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBox(width: double.infinity, height: 14),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(width: 220, height: 14),
          if (showMedia) ...[
            const SizedBox(height: AppSpacing.md),
            const SkeletonBox(
              width: double.infinity,
              height: 180,
              radius: AppRadius.md,
            ),
          ],
        ],
      ),
    );
  }
}
