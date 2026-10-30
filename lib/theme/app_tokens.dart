import 'package:flutter/material.dart';

/// Design tokens for SocialHub ("Modern Premium" direction).
///
/// One brand color, calm neutrals, a small spacing/radius scale, soft
/// shadows and short motion. Screens should read these values (or the
/// matching `Theme.of(context)` fields) instead of hard-coding new ones.

/// The palette for one brightness. Use [AppPalette.of] in widgets.
class AppPalette {
  final Color brand;
  final Color brandSoft;
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color like;
  final Color success;
  final Color danger;

  const AppPalette({
    required this.brand,
    required this.brandSoft,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.like,
    required this.success,
    required this.danger,
  });

  /// Deep Ink Indigo on warm-cool neutrals.
  static const light = AppPalette(
    brand: Color(0xFF3D4DD8),
    brandSoft: Color(0xFFEEF0FC),
    background: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F2F5),
    border: Color(0xFFE6E8EC),
    textPrimary: Color(0xFF14161B),
    textSecondary: Color(0xFF6B7180),
    like: Color(0xFFE5484D),
    success: Color(0xFF2F9E6E),
    danger: Color(0xFFE5484D),
  );

  static const dark = AppPalette(
    brand: Color(0xFF8590F2),
    brandSoft: Color(0xFF232847),
    background: Color(0xFF0E0F13),
    surface: Color(0xFF17191F),
    surfaceMuted: Color(0xFF1F222A),
    border: Color(0xFF2A2D36),
    textPrimary: Color(0xFFF2F3F5),
    textSecondary: Color(0xFF9BA1AD),
    like: Color(0xFFFF6369),
    success: Color(0xFF4CC38A),
    danger: Color(0xFFFF6369),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Spacing scale (multiples of 4).
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Only three corner sizes, plus "fully round".
class AppRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double full = 999;
}

/// Short, calm motion.
class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;
}

/// Soft two-layer shadow in light mode; a 1px border replaces it in dark
/// mode, where shadows are invisible.
class AppDecorations {
  static List<BoxShadow> softShadow(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) return const [];
    return const [
      BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0D101828), blurRadius: 16, offset: Offset(0, 4)),
    ];
  }

  /// The standard card: surface color, rounded corners, subtle border, soft shadow.
  static BoxDecoration card(
    BuildContext context, {
    double radius = AppRadius.md,
    Color? color,
    Color? borderColor,
    bool hovered = false,
  }) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final side =
        borderColor ??
        (hovered
            ? palette.brand.withValues(alpha: 0.35)
            : isDark
            ? palette.border
            : palette.border.withValues(alpha: 0.7));
    return BoxDecoration(
      color: color ?? palette.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: side),
      boxShadow: softShadow(context),
    );
  }
}

/// Calm, flat tones for placeholder media (no saturated gradients).
/// Each pair is [background, icon/foreground].
const List<List<Color>> mutedMediaTones = [
  [Color(0xFFE3E6F8), Color(0xFF5B66C9)], // indigo mist
  [Color(0xFFF3E7DC), Color(0xFFB0774B)], // sand
  [Color(0xFFDDEDE7), Color(0xFF3F8A70)], // sage
  [Color(0xFFEDE3EE), Color(0xFF8E5C93)], // mauve
];
