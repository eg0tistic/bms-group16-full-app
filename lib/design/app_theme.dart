import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static TextStyle _cairo({double? size, FontWeight? weight, Color? color}) {
    return TextStyle(
      fontFamily: 'Cairo',
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0,
    );
  }

  static ThemeData light() {
    final textTheme = ThemeData.light().textTheme
        .apply(fontFamily: 'Cairo')
        .copyWith(
          bodyLarge: _cairo(
            size: 14,
            color: AppTokens.ink,
          ).copyWith(height: 1.55),
          bodyMedium: _cairo(
            size: 13,
            color: AppTokens.ink,
          ).copyWith(height: 1.5),
          bodySmall: _cairo(
            size: 12,
            color: AppTokens.muted,
          ).copyWith(height: 1.45),
          titleLarge: _cairo(
            size: 20,
            weight: FontWeight.w800,
            color: AppTokens.ink,
          ).copyWith(height: 1.3),
          titleMedium: _cairo(
            size: 16,
            weight: FontWeight.w700,
            color: AppTokens.ink,
          ).copyWith(height: 1.35),
          titleSmall: _cairo(
            size: 14,
            weight: FontWeight.w700,
            color: AppTokens.ink,
          ).copyWith(height: 1.35),
          labelLarge: _cairo(
            size: 14,
            weight: FontWeight.w700,
            color: AppTokens.ink,
          ),
          labelMedium: _cairo(
            size: 12,
            weight: FontWeight.w600,
            color: AppTokens.muted,
          ),
          labelSmall: _cairo(
            size: 11,
            weight: FontWeight.w600,
            color: AppTokens.muted,
          ),
          headlineMedium: _cairo(
            size: 26,
            weight: FontWeight.w800,
            color: AppTokens.ink,
          ).copyWith(height: 1.2),
          headlineSmall: _cairo(
            size: 22,
            weight: FontWeight.w800,
            color: AppTokens.ink,
          ).copyWith(height: 1.25),
        );

    const scheme = ColorScheme.light(
      primary: AppTokens.ink,
      onPrimary: AppTokens.surface,
      primaryContainer: Color(0xFFE4ECE8),
      onPrimaryContainer: AppTokens.ink,
      secondary: AppTokens.teal,
      onSecondary: AppTokens.surface,
      secondaryContainer: AppTokens.tealTint,
      onSecondaryContainer: AppTokens.tealDark,
      tertiary: AppTokens.clay,
      onTertiary: AppTokens.surface,
      tertiaryContainer: AppTokens.clayTint,
      onTertiaryContainer: AppTokens.clayDark,
      surface: AppTokens.surface,
      onSurface: AppTokens.ink,
      surfaceContainer: AppTokens.bg,
      surfaceContainerHighest: Color(0xFFE9EFEC),
      outline: AppTokens.borderStrong,
      outlineVariant: AppTokens.border,
      onSurfaceVariant: AppTokens.muted,
      error: AppTokens.danger,
      onError: AppTokens.surface,
      errorContainer: AppTokens.dangerTint,
      onErrorContainer: Color(0xFF991B1B),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: AppTokens.bg,
      colorScheme: scheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppTokens.surface,
        foregroundColor: AppTokens.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: _cairo(
          size: 17,
          weight: FontWeight.w800,
          color: AppTokens.ink,
        ),
        iconTheme: const IconThemeData(color: AppTokens.ink, size: 22),
        shape: const Border(bottom: BorderSide(color: AppTokens.border)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        color: AppTokens.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          side: const BorderSide(color: AppTokens.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.teal, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: const BorderSide(color: AppTokens.danger, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: _cairo(size: 13, color: AppTokens.muted),
        floatingLabelStyle: _cairo(
          size: 13,
          weight: FontWeight.w600,
          color: AppTokens.teal,
        ),
        hintStyle: _cairo(size: 13, color: AppTokens.muted),
        prefixIconColor: AppTokens.muted,
        suffixIconColor: AppTokens.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.ink,
          foregroundColor: AppTokens.surface,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rSm),
          ),
          textStyle: _cairo(size: 14, weight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTokens.ink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppTokens.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rSm),
          ),
          textStyle: _cairo(size: 14, weight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppTokens.tealDark,
          textStyle: _cairo(size: 13, weight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rSm),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppTokens.clay,
        foregroundColor: AppTokens.surface,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 5,
        shape: StadiumBorder(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppTokens.teal,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppTokens.surface,
        selectedColor: AppTokens.ink,
        checkmarkColor: AppTokens.surface,
        labelStyle: _cairo(size: 12, weight: FontWeight.w600),
        side: const BorderSide(color: AppTokens.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTokens.surface
              : AppTokens.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTokens.teal
              : AppTokens.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.rXl),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.border,
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppTokens.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rSm),
          side: const BorderSide(color: AppTokens.border),
        ),
        textStyle: _cairo(size: 13, color: AppTokens.ink),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.surface,
        elevation: 8,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
        ),
        titleTextStyle: _cairo(
          size: 17,
          weight: FontWeight.w800,
          color: AppTokens.ink,
        ),
        contentTextStyle: _cairo(
          size: 13.5,
          color: AppTokens.inkSoft,
        ).copyWith(height: 1.55),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTokens.ink,
        contentTextStyle: _cairo(size: 13, color: AppTokens.surface),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rSm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: _cairo(
          size: 14,
          weight: FontWeight.w600,
          color: AppTokens.ink,
        ),
        subtitleTextStyle: _cairo(size: 12, color: AppTokens.muted),
        iconColor: AppTokens.muted,
      ),
    );
  }
}
