import 'package:flutter/material.dart';
import 'package:flutter_learning/theme/app_tokens.dart';

/// Font bundled in assets/fonts (see pubspec.yaml). Designed for Vietnamese.
const String appFontFamily = 'BeVietnamPro';

/// Builds the full SocialHub theme for one brightness.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final p = isDark ? AppPalette.dark : AppPalette.light;

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: p.brand,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      ).copyWith(
        primary: p.brand,
        onPrimary: Colors.white,
        primaryContainer: p.brandSoft,
        onPrimaryContainer: p.brand,
        secondaryContainer: p.brandSoft,
        onSecondaryContainer: p.brand,
        surface: p.surface,
        onSurface: p.textPrimary,
        onSurfaceVariant: p.textSecondary,
        surfaceContainerLowest: p.surface,
        surfaceContainerLow: p.surface,
        surfaceContainer: p.surface,
        surfaceContainerHigh: p.surfaceMuted,
        surfaceContainerHighest: p.surfaceMuted,
        outline: p.textSecondary.withValues(alpha: 0.5),
        outlineVariant: p.border,
        error: p.danger,
        surfaceTint: Colors.transparent,
      );

  // Type scale: few sizes, medium weights, slightly tight headings.
  final textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: p.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: p.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: p.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: p.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: p.textPrimary,
    ),
    bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: p.textPrimary),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: p.textPrimary),
    bodySmall: TextStyle(fontSize: 12, color: p.textSecondary),
    labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
  );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm + 2),
  );
  const buttonText = TextStyle(
    fontFamily: appFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: appFontFamily,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    cardColor: p.surface,
    dividerColor: p.border,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: p.textPrimary,
      ),
      iconTheme: IconThemeData(color: p.textPrimary, size: 24),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: isDark ? BorderSide(color: p.border) : BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: buttonShape,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: buttonShape,
        textStyle: buttonText,
        elevation: 0,
        backgroundColor: p.brand,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: buttonShape,
        textStyle: buttonText,
        foregroundColor: p.textPrimary,
        side: BorderSide(color: p.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: buttonShape, textStyle: buttonText),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceMuted,
      hintStyle: TextStyle(color: p.textSecondary),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm + 4),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm + 4),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm + 4),
        borderSide: BorderSide(color: p.brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm + 4),
        borderSide: BorderSide(color: p.danger),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceMuted,
      selectedColor: p.brandSoft,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: p.textPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      modalBackgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.border,
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? p.surfaceMuted : p.textPrimary,
      contentTextStyle: TextStyle(
        fontFamily: appFontFamily,
        fontSize: 14,
        color: isDark ? p.textPrimary : Colors.white,
      ),
      actionTextColor: isDark ? p.brand : const Color(0xFFAEB5FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
      ),
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.brandSoft,
      elevation: 0,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? p.brand
              : p.textSecondary,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.textPrimary,
      unselectedLabelColor: p.textSecondary,
      indicatorColor: p.brand,
      dividerColor: p.border,
      labelStyle: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textSecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    badgeTheme: BadgeThemeData(backgroundColor: p.danger),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.brand),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  );
}
