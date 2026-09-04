import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'app_colors.dart';
import 'design_tokens.dart';
import 'visual_theme.dart';
import 'visual_skin.dart';

class AppTheme {
  AppTheme._();

  // ─── Text Theme (Phoenix Local Fonts) ─────────────────────────────────────────
  static TextTheme _buildTextTheme(TextTheme base, {required bool isDark}) {
    final textColor = isDark ? AppColors.onSurfaceDark : AppColors.onSurface;
    final mutedColor = isDark
        ? const Color(0xFFA1A1A1)
        : const Color(0xFF666666);

    return base.copyWith(
      // Display — Outfit 700 (High contrast, tight tracking)
      displayLarge: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        color: textColor,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: textColor,
        height: 1.15,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: textColor,
        height: 1.2,
      ),

      // Headline — Inter 600/700 (Clean structural headers)
      headlineLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textColor,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: textColor,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: textColor,
        height: 1.35,
      ),

      // Title — Inter 600 (Cards and modules)
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textColor,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textColor,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: textColor,
        height: 1.4,
      ),

      // Body — Inter 400 (Reading text)
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: mutedColor,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: mutedColor,
        height: 1.5,
      ),

      // Label — Inter 500 (UI elements, buttons)
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: textColor,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: mutedColor,
      ),
    );
  }

  // ─── Input Decoration Theme ───────────────────────────────────────────────
  static InputDecorationTheme _inputTheme(ColorScheme colors) {
    final isLight = colors.brightness == Brightness.light;
    return InputDecorationTheme(
      filled: true,
      fillColor: isLight ? AppColors.surface : AppColors.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + 2,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(
          color: isLight ? const Color(0xFFEBEBEB) : const Color(0xFF222222),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(
          color: isLight ? const Color(0xFFEBEBEB) : const Color(0xFF222222),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.onSurface.withValues(alpha: 0.6),
      ),
      hintStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.onSurface.withValues(alpha: 0.4),
      ),
    );
  }

  // ─── Button Themes (No Ripples) ──────────────────────────────────────────
  static FilledButtonThemeData _filledButtonTheme(ColorScheme colors) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory, // Disable ripples
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme colors) {
    final isLight = colors.brightness == Brightness.light;
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        side: BorderSide(
          color: isLight ? const Color(0xFFEBEBEB) : const Color(0xFF222222),
          width: 1,
        ),
        foregroundColor: colors.onSurface,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
        splashFactory: NoSplash.splashFactory,
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(ColorScheme colors) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        foregroundColor: colors.onSurface,
        splashFactory: NoSplash.splashFactory,
      ),
    );
  }

  static ThemeData buildTheme({
    required bool isDark,
    SchedlyVisualTheme visualTheme = SchedlyVisualTheme.defaultTheme,
    bool transparentScaffold = false,
  }) {
    switch (visualTheme) {
      case SchedlyVisualTheme.heritage:
        return _buildHeritageTheme(
          isDark: isDark,
          transparentScaffold: transparentScaffold,
        );
      case SchedlyVisualTheme.future:
        return _buildFutureTheme(
          isDark: isDark,
          transparentScaffold: transparentScaffold,
        );
      case SchedlyVisualTheme.bloom:
        return _buildBloomTheme(
          isDark: isDark,
          transparentScaffold: transparentScaffold,
        );
      case SchedlyVisualTheme.defaultTheme:
        return isDark
            ? _buildDarkTheme(transparentScaffold: transparentScaffold)
            : _buildLightTheme(transparentScaffold: transparentScaffold);
    }
  }

  static Color lectureTypeColor(
    BuildContext context, {
    String? component,
    String? subject,
  }) {
    final ext = Theme.of(context).extension<SchedlyLectureTypeColors>();
    if (ext != null) {
      return ext.resolve(component: component, subject: subject);
    }
    if (subject != null && subject.toLowerCase().contains('lunch')) {
      return Colors.amber;
    }
    return Theme.of(context).colorScheme.primary;
  }

  // ─── Light Theme ─────────────────────────────────────────────────────────
  static ThemeData get lightTheme =>
      _buildLightTheme(transparentScaffold: false);

  static const ScrollbarThemeData _commonScrollbarTheme = ScrollbarThemeData(
    thumbVisibility: WidgetStatePropertyAll(false),
    trackVisibility: WidgetStatePropertyAll(false),
    thickness: WidgetStatePropertyAll(4.0),
    radius: Radius.circular(8.0),
    interactive: true,
  );

  static ThemeData _buildLightTheme({bool transparentScaffold = false}) {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      primaryContainer: Color(0xFFF3F8FF),
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.secondary,
      secondaryContainer: Color(0xFFF9F9F9),
      tertiary: AppColors.accent,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: AppColors.onSurface,
      error: AppColors.red,
      onError: Colors.white,
      outline: Color(0xFFEBEBEB),
      outlineVariant: Color(0xFFFAFAFA),
      surfaceContainerHighest: Color(0xFFFAFAFA),
      scrim: Color(0x1A000000),
    );

    final textTheme = _buildTextTheme(
      ThemeData.light().textTheme,
      isDark: false,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scrollbarTheme: _commonScrollbarTheme,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: 'Inter', // Default fallback
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(
            fillColor: transparentScaffold ? Colors.transparent : null,
          ),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(
            fillColor: transparentScaffold ? Colors.transparent : null,
          ),
        },
      ),
      canvasColor: transparentScaffold ? Colors.transparent : AppColors.surface,
      scaffoldBackgroundColor: transparentScaffold
          ? Colors.transparent
          : AppColors.background,

      typography: Typography.material2021(colorScheme: colorScheme),

      appBarTheme: AppBarTheme(
        backgroundColor: transparentScaffold
            ? Colors.transparent
            : AppColors.background,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, // No shadow on scroll, use borders instead
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurface, size: 20),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: Color(0xFFEBEBEB), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24, // High elevation for depth in Phoenix
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: Color(0xFFEBEBEB), width: 1),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
          letterSpacing: -0.4,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: Color(0xFF666666),
          height: 1.5,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111111),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 6,
        actionTextColor: AppColors.primaryLight,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        indicatorShape: const CircleBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF999999),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: Color(0xFF999999), size: 24);
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFFAFAFA),
        selectedColor: const Color(0xFFEBEBEB),
        disabledColor: const Color(0xFFFAFAFA),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurface,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFEBEBEB),
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        minLeadingWidth: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF999999),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : const Color(0xFFEBEBEB),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      inputDecorationTheme: _inputTheme(colorScheme),
      filledButtonTheme: _filledButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme),
      extensions: const [
        lightSemanticColors,
        defaultLightLectureColors,
        SchedlySkinExtension(skin: DefaultSkin(isDark: false)),
      ],
    );
  }

  // ─── Dark Theme ──────────────────────────────────────────────────────────
  static ThemeData get darkTheme => _buildDarkTheme(transparentScaffold: false);

  static ThemeData _buildDarkTheme({bool transparentScaffold = false}) {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primaryDark,
      primaryContainer: Color(0xFF0D1524),
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondaryDark,
      secondaryContainer: Color(0xFF111111),
      tertiary: AppColors.accentDark,
      surface: AppColors.surfaceDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: AppColors.onSurfaceDark,
      error: AppColors.redLight,
      onError: Colors.white,
      outline: Color(0xFF222222),
      outlineVariant: Color(0xFF111111),
      surfaceContainerHighest: Color(0xFF111111),
      scrim: Color(0x66000000),
    );

    final textTheme = _buildTextTheme(ThemeData.dark().textTheme, isDark: true);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scrollbarTheme: _commonScrollbarTheme,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: 'Inter', // Default fallback
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(
            fillColor: transparentScaffold ? Colors.transparent : null,
          ),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(
            fillColor: transparentScaffold ? Colors.transparent : null,
          ),
        },
      ),
      canvasColor: transparentScaffold
          ? Colors.transparent
          : AppColors.surfaceDark,
      scaffoldBackgroundColor: transparentScaffold
          ? Colors.transparent
          : AppColors.backgroundDark,

      typography: Typography.material2021(colorScheme: colorScheme),

      appBarTheme: AppBarTheme(
        backgroundColor: transparentScaffold
            ? Colors.transparent
            : AppColors.backgroundDark,
        foregroundColor: AppColors.onSurfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceDark,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.onSurfaceDark,
          size: 20,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: Color(0xFF222222), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0A0A0A),
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: Colors.black.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: Color(0xFF222222), width: 1),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceDark,
          letterSpacing: -0.4,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: Color(0xFFA1A1A1),
          height: 1.5,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111111),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: Color(0xFF222222), width: 1),
        ),
        elevation: 6,
        actionTextColor: AppColors.primaryDark,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        indicatorShape: const CircleBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            );
          }
          return const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF737373),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryDark, size: 24);
          }
          return const IconThemeData(color: Color(0xFF737373), size: 24);
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF111111),
        selectedColor: const Color(0xFF222222),
        disabledColor: const Color(0xFF111111),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurfaceDark,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurfaceDark,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF222222),
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        minLeadingWidth: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF737373),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primaryDark
              : const Color(0xFF222222),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      inputDecorationTheme: _inputTheme(colorScheme),
      filledButtonTheme: _filledButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme),
      extensions: const [
        darkSemanticColors,
        defaultDarkLectureColors,
        SchedlySkinExtension(skin: DefaultSkin(isDark: true)),
      ],
    );
  }

  // ─── Heritage Text Theme ──────────────────────────────────────────────────
  static TextTheme _buildHeritageTextTheme(
    TextTheme base, {
    required bool isDark,
  }) {
    final textColor = isDark
        ? const Color(0xFFF0EAE1)
        : const Color(0xFF201B15);
    final mutedColor = isDark
        ? const Color(0xFFA89F91)
        : const Color(0xFF6B6154);

    return base.copyWith(
      displayLarge: TextStyle(
        fontFamily: 'Newsreader',
        fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Newsreader',
        fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.15,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Newsreader',
        fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Newsreader',
        fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Newsreader',
        fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Newsreader',
        fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.35,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Newsreader',
        fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: mutedColor,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: mutedColor,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: mutedColor,
      ),
    );
  }

  // ─── Future Text Theme ────────────────────────────────────────────────────
  static TextTheme _buildFutureTextTheme(
    TextTheme base, {
    required bool isDark,
  }) {
    final textColor = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF0F172A);
    final mutedColor = isDark
        ? const Color(0xFF8899B0)
        : const Color(0xFF53647B);

    return base.copyWith(
      displayLarge: TextStyle(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 46,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: textColor,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: textColor,
        height: 1.15,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textColor,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: textColor,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: textColor,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textColor,
        height: 1.35,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textColor,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textColor,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: textColor,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: mutedColor,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: mutedColor,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: mutedColor,
      ),
    );
  }

  // ─── Bloom Text Theme ─────────────────────────────────────────────────────
  static TextTheme _buildBloomTextTheme(
    TextTheme base, {
    required bool isDark,
  }) {
    final textColor = isDark
        ? const Color(0xFFFDF4F8)
        : const Color(0xFF281423);
    final mutedColor = isDark
        ? const Color(0xFFBCA6BF)
        : const Color(0xFF7A6475);

    return base.copyWith(
      displayLarge: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 46,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: textColor,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: textColor,
        height: 1.15,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: textColor,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: textColor,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textColor,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: textColor,
        height: 1.35,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: mutedColor,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: mutedColor,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: mutedColor,
      ),
    );
  }

  // ─── Heritage Theme Builder ───────────────────────────────────────────────
  static ThemeData _buildHeritageTheme({
    required bool isDark,
    bool transparentScaffold = false,
  }) {
    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFFC86432),
            primaryContainer: Color(0xFF2E1C13),
            onPrimaryContainer: Color(0xFFF0C2A8),
            secondary: Color(0xFFA37B55),
            secondaryContainer: Color(0xFF221F1C),
            tertiary: Color(0xFF5E8B4E),
            surface: Color(0xFF1A1715),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onTertiary: Colors.white,
            onSurface: Color(0xFFF0EAE1),
            error: Color(0xFF9E3B33),
            onError: Colors.white,
            outline: Color(0xFF332D27),
            outlineVariant: Color(0xFF25211E),
            surfaceContainerHighest: Color(0xFF221F1C),
            scrim: Color(0x66000000),
          )
        : const ColorScheme.light(
            primary: Color(0xFFA34820),
            primaryContainer: Color(0xFFFBECE4),
            onPrimaryContainer: Color(0xFFA34820),
            secondary: Color(0xFF7A5C3E),
            secondaryContainer: Color(0xFFF7F3EB),
            tertiary: Color(0xFF406B33),
            surface: Color(0xFFFFFFFF),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onTertiary: Colors.white,
            onSurface: Color(0xFF201B15),
            error: Color(0xFF8E2C24),
            onError: Colors.white,
            outline: Color(0xFFE5DDD0),
            outlineVariant: Color(0xFFF7F3EB),
            surfaceContainerHighest: Color(0xFFF7F3EB),
            scrim: Color(0x1A000000),
          );

    final textTheme = _buildHeritageTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      isDark: isDark,
    );

    final sem = isDark
        ? heritageDarkSemanticColors
        : heritageLightSemanticColors;
    final lecture = isDark
        ? heritageDarkLectureColors
        : heritageLightLectureColors;
    final bgColor = isDark ? const Color(0xFF141210) : const Color(0xFFF7F4EE);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scrollbarTheme: _commonScrollbarTheme,
      colorScheme: colorScheme,
      textTheme: textTheme,
      canvasColor: transparentScaffold
          ? Colors.transparent
          : colorScheme.surface,
      scaffoldBackgroundColor: transparentScaffold
          ? Colors.transparent
          : bgColor,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(
            fillColor: transparentScaffold ? Colors.transparent : null,
          ),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(
            fillColor: transparentScaffold ? Colors.transparent : null,
          ),
        },
      ),
      typography: Typography.material2021(colorScheme: colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: transparentScaffold ? Colors.transparent : bgColor,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Newsreader',
          fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 20),
      ),
      cardTheme: CardThemeData(
        color: sem.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: sem.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sem.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 20,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: sem.borderSubtle, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Newsreader',
          fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: sem.onSurfaceMuted,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF221F1C)
            : const Color(0xFF201B15),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 6,
        actionTextColor: colorScheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        indicatorShape: const CircleBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: sem.onSurfaceMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 24);
          }
          return IconThemeData(color: sem.onSurfaceMuted, size: 24);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: sem.surfaceElevated2,
        selectedColor: colorScheme.primary.withValues(alpha: 0.18),
        disabledColor: sem.surfaceElevated2,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: sem.borderSubtle, width: 0.8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: sem.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : sem.onSurfaceMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? colorScheme.primary
              : sem.borderSubtle,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: _inputTheme(colorScheme),
      filledButtonTheme: _filledButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme),
      extensions: [
        sem,
        lecture,
        SchedlySkinExtension(skin: HeritageSkin(isDark: isDark)),
      ],
    );
  }

  // ─── Future Theme Builder ─────────────────────────────────────────────────
  static ThemeData _buildFutureTheme({
    required bool isDark,
    bool transparentScaffold = false,
  }) {
    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFF00D8FF),
            primaryContainer: Color(0xFF0C243B),
            onPrimaryContainer: Color(0xFF00D8FF),
            secondary: Color(0xFF7986CB),
            secondaryContainer: Color(0xFF121B2C),
            tertiary: Color(0xFF06D6A0),
            surface: Color(0xFF0B111D),
            onPrimary: Colors.black,
            onSecondary: Colors.white,
            onTertiary: Colors.black,
            onSurface: Color(0xFFE2E8F0),
            error: Color(0xFFFF3366),
            onError: Colors.white,
            outline: Color(0xFF1E2F48),
            outlineVariant: Color(0xFF121B2C),
            surfaceContainerHighest: Color(0xFF121B2C),
            scrim: Color(0x77000000),
          )
        : const ColorScheme.light(
            primary: Color(0xFF0284C7),
            primaryContainer: Color(0xFFE0F2FE),
            onPrimaryContainer: Color(0xFF0284C7),
            secondary: Color(0xFF475569),
            secondaryContainer: Color(0xFFF0F5FA),
            tertiary: Color(0xFF059669),
            surface: Color(0xFFFFFFFF),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onTertiary: Colors.white,
            onSurface: Color(0xFF0F172A),
            error: Color(0xFFE11D48),
            onError: Colors.white,
            outline: Color(0xFFD6E2EE),
            outlineVariant: Color(0xFFF0F5FA),
            surfaceContainerHighest: Color(0xFFF0F5FA),
            scrim: Color(0x1A000000),
          );

    final textTheme = _buildFutureTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      isDark: isDark,
    );

    final sem = isDark ? futureDarkSemanticColors : futureLightSemanticColors;
    final lecture = isDark ? futureDarkLectureColors : futureLightLectureColors;
    final bgColor = isDark ? const Color(0xFF060A12) : const Color(0xFFF0F4F8);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scrollbarTheme: _commonScrollbarTheme,
      colorScheme: colorScheme,
      textTheme: textTheme,
      canvasColor: transparentScaffold
          ? Colors.transparent
          : colorScheme.surface,
      scaffoldBackgroundColor: transparentScaffold
          ? Colors.transparent
          : bgColor,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(
            fillColor: transparentScaffold ? Colors.transparent : null,
          ),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(
            fillColor: transparentScaffold ? Colors.transparent : null,
          ),
        },
      ),
      typography: Typography.material2021(colorScheme: colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: transparentScaffold ? Colors.transparent : bgColor,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 20),
      ),
      cardTheme: CardThemeData(
        color: sem.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: sem.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sem.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 20,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: sem.borderSubtle, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: sem.onSurfaceMuted,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF121B2C)
            : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: sem.borderSubtle, width: 1),
        ),
        elevation: 6,
        actionTextColor: colorScheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        indicatorShape: const CircleBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: sem.onSurfaceMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 24);
          }
          return IconThemeData(color: sem.onSurfaceMuted, size: 24);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: sem.surfaceElevated2,
        selectedColor: colorScheme.primary.withValues(alpha: 0.16),
        disabledColor: sem.surfaceElevated2,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: sem.borderSubtle, width: 0.8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: sem.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : sem.onSurfaceMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? colorScheme.primary
              : sem.borderSubtle,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: _inputTheme(colorScheme),
      filledButtonTheme: _filledButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme),
      extensions: [
        sem,
        lecture,
        SchedlySkinExtension(skin: FutureSkin(isDark: isDark)),
      ],
    );
  }

  // ─── Bloom Theme Builder ──────────────────────────────────────────────────
  static ThemeData _buildBloomTheme({
    required bool isDark,
    bool transparentScaffold = false,
  }) {
    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFFF472B6),
            primaryContainer: Color(0xFF33162C),
            onPrimaryContainer: Color(0xFFF472B6),
            secondary: Color(0xFFC084FC),
            secondaryContainer: Color(0xFF22182B),
            tertiary: Color(0xFF34D399),
            surface: Color(0xFF18111E),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onTertiary: Colors.black,
            onSurface: Color(0xFFFDF4F8),
            error: Color(0xFFFB7185),
            onError: Colors.white,
            outline: Color(0xFF362443),
            outlineVariant: Color(0xFF22182B),
            surfaceContainerHighest: Color(0xFF22182B),
            scrim: Color(0x66000000),
          )
        : const ColorScheme.light(
            primary: Color(0xFFE11D74),
            primaryContainer: Color(0xFFFCE7F3),
            onPrimaryContainer: Color(0xFFE11D74),
            secondary: Color(0xFF9333EA),
            secondaryContainer: Color(0xFFFAF2F6),
            tertiary: Color(0xFF0D9488),
            surface: Color(0xFFFFFFFF),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onTertiary: Colors.white,
            onSurface: Color(0xFF281423),
            error: Color(0xFFE11D48),
            onError: Colors.white,
            outline: Color(0xFFF1DEE7),
            outlineVariant: Color(0xFFFAF2F6),
            surfaceContainerHighest: Color(0xFFFAF2F6),
            scrim: Color(0x1A000000),
          );

    final textTheme = _buildBloomTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      isDark: isDark,
    );

    final sem = isDark ? bloomDarkSemanticColors : bloomLightSemanticColors;
    final lecture = isDark ? bloomDarkLectureColors : bloomLightLectureColors;
    final bgColor = isDark ? const Color(0xFF120C17) : const Color(0xFFFDF6F8);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scrollbarTheme: _commonScrollbarTheme,
      colorScheme: colorScheme,
      textTheme: textTheme,
      canvasColor: transparentScaffold
          ? Colors.transparent
          : colorScheme.surface,
      scaffoldBackgroundColor: transparentScaffold
          ? Colors.transparent
          : bgColor,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(
            fillColor: transparentScaffold ? Colors.transparent : null,
          ),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(
            fillColor: transparentScaffold ? Colors.transparent : null,
          ),
        },
      ),
      typography: Typography.material2021(colorScheme: colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: transparentScaffold ? Colors.transparent : bgColor,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 20),
      ),
      cardTheme: CardThemeData(
        color: sem.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.0),
          side: BorderSide(color: sem.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sem.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 20,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: BorderSide(color: sem.borderSubtle, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: sem.onSurfaceMuted,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF22182B)
            : const Color(0xFF281423),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: sem.borderSubtle, width: 1),
        ),
        elevation: 6,
        actionTextColor: colorScheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        indicatorShape: const CircleBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: sem.onSurfaceMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 24);
          }
          return IconThemeData(color: sem.onSurfaceMuted, size: 24);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: sem.surfaceElevated2,
        selectedColor: colorScheme.primary.withValues(alpha: 0.16),
        disabledColor: sem.surfaceElevated2,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: sem.borderSubtle, width: 0.8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: sem.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : sem.onSurfaceMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? colorScheme.primary
              : sem.borderSubtle,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: _inputTheme(colorScheme),
      filledButtonTheme: _filledButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme),
      extensions: [
        sem,
        lecture,
        SchedlySkinExtension(skin: BloomSkin(isDark: isDark)),
      ],
    );
  }
}
