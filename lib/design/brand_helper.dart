import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ---------------------------------------------------------------------------
///  SWIMSUITE DESIGN SYSTEM
/// ---------------------------------------------------------------------------

class SwimSuiteColors {
  // YOUR BRAND COLORS
  static const Color main = Color(0xFF03254C); // Main color
  static const Color accent = Color(0xFF3A86FF); // Accent blue
  static const Color success = Color(0xFFFFC300); // Gold / Framgång
  static const Color background = Color(0xFFF7F7FF); // Light grey

  // Neutral palette
  static const Color black = Color(0xFF0A0A0F);
  static const Color grey900 = Color(0xFF1C1C25);
  static const Color grey700 = Color(0xFF3B3B45);
  static const Color grey500 = Color(0xFF7C7C87);
  static const Color grey300 = Color(0xFFD5D5DB);
  static const Color grey100 = Color(0xFFF0F0F7);
  static const Color white = Color(0xFFFFFFFF);

  static const LinearGradient mainGradient = LinearGradient(
    colors: [main, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// ---------------------------------------------------------------------------
/// TYPOGRAPHY
/// Montserrat = headlines
/// Arial = body
/// ---------------------------------------------------------------------------
class SwimSuiteText {
  static const String headlineFont = 'Montserrat';
  static const String bodyFont = 'Arial';

  // HEADLINES
  static const TextStyle h1 = TextStyle(
    fontFamily: headlineFont,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: headlineFont,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: headlineFont,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // BODY
  static const TextStyle body = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    height: 1.45,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: bodyFont,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    height: 1.45,
  );

  static const TextStyle small = TextStyle(
    fontFamily: bodyFont,
    fontSize: 14,
    height: 1.4,
  );

  static const TextStyle tiny = TextStyle(
    fontFamily: bodyFont,
    fontSize: 12,
    height: 1.3,
  );
}

/// ---------------------------------------------------------------------------
/// SPACING
/// ---------------------------------------------------------------------------
class SwimSuiteSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// ---------------------------------------------------------------------------
/// THEME DATA
/// Ensures Material widgets automatically use Montserrat/Arial
/// ---------------------------------------------------------------------------
class SwimSuiteTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // ------------------------------
    // GLOBAL COLORS
    // ------------------------------
    scaffoldBackgroundColor: SwimSuiteColors.background,
    primaryColor: SwimSuiteColors.main,
    colorScheme: const ColorScheme.light(
      primary: SwimSuiteColors.main,
      secondary: SwimSuiteColors.accent,
      surface: SwimSuiteColors.background,
      tertiary: SwimSuiteColors.success,
      error: Colors.red,
    ),

    // ------------------------------
    // GLOBAL TYPOGRAPHY
    // Default = Arial, Headlines = Montserrat
    // ------------------------------
    fontFamily: SwimSuiteText.bodyFont,
    textTheme: const TextTheme(
      headlineLarge: SwimSuiteText.h1,
      headlineMedium: SwimSuiteText.h2,
      headlineSmall: SwimSuiteText.h3,
      bodyLarge: SwimSuiteText.body,
      bodyMedium: SwimSuiteText.small,
      bodySmall: SwimSuiteText.tiny,
    ).apply(
      bodyColor: SwimSuiteColors.grey900,
      displayColor: SwimSuiteColors.grey900,
    ),

    // ------------------------------
    // APP BAR
    // ------------------------------
    appBarTheme: AppBarTheme(
      backgroundColor: SwimSuiteColors.main,
      foregroundColor: SwimSuiteColors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: SwimSuiteText.h2,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    // ------------------------------
    // NAVIGATION BAR (bottom)
    // ------------------------------
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: SwimSuiteColors.white,
      indicatorColor: SwimSuiteColors.accent.withAlpha(12),
      labelTextStyle: WidgetStateProperty.all(
        SwimSuiteText.small.copyWith(color: SwimSuiteColors.main),
      ),
      iconTheme: WidgetStateProperty.all(
        const IconThemeData(color: SwimSuiteColors.grey700),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: SwimSuiteColors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: SwimSuiteText.h3.copyWith(
        color: SwimSuiteColors.grey900,
      ),
      contentTextStyle: SwimSuiteText.body.copyWith(
        color: SwimSuiteColors.grey900,
      ),
    ),

    // ------------------------------
    // ICON THEME
    // ------------------------------
    iconTheme: const IconThemeData(
      color: SwimSuiteColors.main,
      size: 24,
    ),

    // ------------------------------
    // BUTTONS
    // ------------------------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SwimSuiteColors.main,
        foregroundColor: SwimSuiteColors.white,
        textStyle: SwimSuiteText.bodyBold,
        minimumSize: const Size(120, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SwimSuiteColors.accent,
        textStyle: SwimSuiteText.bodyBold,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SwimSuiteColors.accent,
        foregroundColor: SwimSuiteColors.white,
        textStyle: SwimSuiteText.bodyBold,
      ),
    ),

    // ------------------------------
    // INPUTS / TEXTFIELDS
    // ------------------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SwimSuiteColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SwimSuiteColors.grey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SwimSuiteColors.accent, width: 2),
      ),
      labelStyle: SwimSuiteText.small,
      hintStyle: SwimSuiteText.small,
    ),

    // ------------------------------
    // DIVIDERS
    // ------------------------------
    dividerTheme: const DividerThemeData(
      color: SwimSuiteColors.grey300,
      thickness: 1,
    ),

    // ------------------------------
    // PAGE TRANSITIONS (iOS-like smooth)
    // ------------------------------
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    // ------------------------------
    // TABS (optional if used)
    // ------------------------------
    tabBarTheme: TabBarThemeData(
      labelColor: SwimSuiteColors.main,
      unselectedLabelColor: SwimSuiteColors.grey700,
      labelStyle: SwimSuiteText.bodyBold,
      unselectedLabelStyle: SwimSuiteText.small,
      indicatorColor: SwimSuiteColors.accent,
    ),
  );

// ---------------------------------------------------------------------------
// SWIMSUITE DARK THEME
// ---------------------------------------------------------------------------
  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // -----------------------------------------------------------------------
    // GLOBAL COLORS
    // -----------------------------------------------------------------------
    scaffoldBackgroundColor: const Color(0xFF0E1A2B),
    // Deep navy variant
    primaryColor: SwimSuiteColors.main,
    colorScheme: const ColorScheme.dark(
      primary: SwimSuiteColors.accent,
      secondary: SwimSuiteColors.main,
      surface: Color(0xFF101824),
      tertiary: SwimSuiteColors.success,
      error: Colors.red,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF182233),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: SwimSuiteText.h3.copyWith(
        color: SwimSuiteColors.white,
      ),
      contentTextStyle: SwimSuiteText.body.copyWith(
        color: SwimSuiteColors.grey100,
      ),
    ),
    // -----------------------------------------------------------------------
    // GLOBAL TYPOGRAPHY
    // -----------------------------------------------------------------------
    fontFamily: SwimSuiteText.bodyFont,
    textTheme: const TextTheme(
      headlineLarge: SwimSuiteText.h1,
      // White already in style
      headlineMedium: SwimSuiteText.h2,
      headlineSmall: SwimSuiteText.h3,
      bodyLarge: SwimSuiteText.body,
      // Will override color below
      bodyMedium: SwimSuiteText.small,
      bodySmall: SwimSuiteText.tiny,
    ).apply(
      bodyColor: SwimSuiteColors.grey100,
      displayColor: SwimSuiteColors.white,
    ),

    // -----------------------------------------------------------------------
    // APP BAR
    // -----------------------------------------------------------------------
    appBarTheme: const AppBarTheme(
      backgroundColor: SwimSuiteColors.main,
      foregroundColor: SwimSuiteColors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: SwimSuiteText.h2,
    ),

    // -----------------------------------------------------------------------
    // BOTTOM NAVIGATION BAR
    // -----------------------------------------------------------------------
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0D1520),
      indicatorColor: SwimSuiteColors.accent.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(
        SwimSuiteText.small.copyWith(color: SwimSuiteColors.grey100),
      ),
      iconTheme: WidgetStateProperty.all(
        const IconThemeData(color: SwimSuiteColors.grey300),
      ),
    ),

    // -----------------------------------------------------------------------
    // ICONS
    // -----------------------------------------------------------------------
    iconTheme: const IconThemeData(
      color: SwimSuiteColors.grey100,
      size: 24,
    ),

    // -----------------------------------------------------------------------
    // BUTTONS
    // -----------------------------------------------------------------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SwimSuiteColors.accent,
        foregroundColor: SwimSuiteColors.white,
        textStyle: SwimSuiteText.bodyBold,
        minimumSize: const Size(120, 48),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        shadowColor: SwimSuiteColors.accent,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SwimSuiteColors.accent,
        textStyle: SwimSuiteText.bodyBold.copyWith(
          color: SwimSuiteColors.accent,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SwimSuiteColors.main,
        foregroundColor: SwimSuiteColors.white,
        textStyle: SwimSuiteText.bodyBold,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),

    // -----------------------------------------------------------------------
    // INPUT FIELDS
    // -----------------------------------------------------------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A2433),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SwimSuiteColors.grey700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: SwimSuiteColors.accent, width: 2),
      ),
      labelStyle: SwimSuiteText.small.copyWith(color: SwimSuiteColors.grey300),
      hintStyle: SwimSuiteText.small.copyWith(color: SwimSuiteColors.grey500),
    ),

    // -----------------------------------------------------------------------
    // DIVIDERS
    // -----------------------------------------------------------------------
    dividerTheme: const DividerThemeData(
      color: SwimSuiteColors.grey700,
      thickness: 1,
    ),

    // -----------------------------------------------------------------------
    // CARD / SURFACE BACKGROUNDS
    // -----------------------------------------------------------------------
    cardColor: const Color(0xFF182233),
    // Navy card
    popupMenuTheme: const PopupMenuThemeData(
      color: Color(0xFF16202E),
      surfaceTintColor: Colors.transparent,
    ),

    // -----------------------------------------------------------------------
    // PAGE TRANSITIONS
    // -----------------------------------------------------------------------
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    // -----------------------------------------------------------------------
    // TABS
    // -----------------------------------------------------------------------
    tabBarTheme: TabBarThemeData(
      labelColor: SwimSuiteColors.accent,
      unselectedLabelColor: SwimSuiteColors.grey500,
      labelStyle: SwimSuiteText.bodyBold.copyWith(color: SwimSuiteColors.white),
      unselectedLabelStyle:
          SwimSuiteText.small.copyWith(color: SwimSuiteColors.grey500),
      indicatorColor: SwimSuiteColors.accent,
    ),
  );
}

extension SwimSuiteTextColor on BuildContext {
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;

  Color get textSecondary =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.7);

  Color get textInverse => Theme.of(this).colorScheme.onPrimary;

  Color get textAccent => Theme.of(this).colorScheme.primary;

  Color get textMuted => Theme.of(this).disabledColor;
}
