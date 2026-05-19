import 'package:flutter/material.dart';

/// Provides Material 3 [ThemeData] for light and dark modes.
class AppTheme {
  AppTheme._();

  // Minimal accent color.
  static const Color _primary = Color(0xFF0D5FDB); // deep blue

  // Surface palette (light).
  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _lightSurface = Colors.white;
  static const Color _lightText = Color(0xFF111827);
  static const Color _lightSubtleText = Color(0xFF6B7280);
  static const Color _lightBorder = Color(0xFFE5E7EB);

  // Surface palette (dark).
  static const Color _darkBg = Color(0xFF0F1115);
  static const Color _darkSurface = Color(0xFF161A22);
  static const Color _darkText = Color(0xFFF3F4F6);
  static const Color _darkSubtleText = Color(0xFF9CA3AF);
  static const Color _darkBorder = Color(0xFF2B3240);

  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCEBFF),
      onPrimaryContainer: Color(0xFF002A66),
      secondary: Color(0xFF4B5563),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEFF2F6),
      onSecondaryContainer: Color(0xFF1F2937),
      tertiary: Color(0xFF0EA5A6),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFDDFBFA),
      onTertiaryContainer: Color(0xFF004F50),
      error: Color(0xFFB42318),
      onError: Colors.white,
      errorContainer: Color(0xFFFFE4E1),
      onErrorContainer: Color(0xFF5F1714),
      surface: _lightSurface,
      onSurface: _lightText,
      onSurfaceVariant: _lightSubtleText,
      outline: _lightBorder,
      outlineVariant: Color(0xFFF0F2F5),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF111827),
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFB6D1FF),
      surfaceContainerHighest: Color(0xFFF2F4F7),
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: _lightBg,
      divider: _lightBorder,
    );
  }

  static ThemeData get darkTheme {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF9FC2FF),
      onPrimary: Color(0xFF062A63),
      primaryContainer: Color(0xFF113A80),
      onPrimaryContainer: Color(0xFFDCEBFF),
      secondary: Color(0xFFB7C0CE),
      onSecondary: Color(0xFF222B38),
      secondaryContainer: Color(0xFF2A3342),
      onSecondaryContainer: Color(0xFFE6EBF2),
      tertiary: Color(0xFF7DE0DF),
      onTertiary: Color(0xFF004F50),
      tertiaryContainer: Color(0xFF075C5D),
      onTertiaryContainer: Color(0xFFCFFBFA),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: _darkSurface,
      onSurface: _darkText,
      onSurfaceVariant: _darkSubtleText,
      outline: _darkBorder,
      outlineVariant: Color(0xFF1C2230),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE5E7EB),
      onInverseSurface: Color(0xFF111827),
      inversePrimary: _primary,
      surfaceContainerHighest: Color(0xFF1B2230),
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: _darkBg,
      divider: _darkBorder,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color divider,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      dividerColor: divider,
    );

    final textTheme = base.textTheme
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
          fontFamily: 'sans-serif',
        )
        .copyWith(
          bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
          bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.4),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
