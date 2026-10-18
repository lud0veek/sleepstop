import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OledColors {
  static const Color trueBlack = Color(0xFF000000);
  static const Color cardSurface = Color(0xFF0A0A0D);
  static const Color elevatedSurface = Color(0xFF121217);
  static const Color subtleBorder = Color(0xFF1F1F27);

  // Warm Bedroom Accents (Amber / Deep Orange / Soft Indigo)
  static const Color warmAmber = Color(0xFFFF9E44);
  static const Color deepOrange = Color(0xFFE65C2E);
  static const Color softIndigo = Color(0xFF7B83EB);
  static const Color mutedRose = Color(0xFFD9536F);
  static const Color calmTeal = Color(0xFF4DB6AC);

  // Premium (Pro) accent: muted champagne gold, never neon.
  static const Color gold = Color(0xFFD9B46A);
  static const Color goldDeep = Color(0xFF8E6F35);

  // Low-glare Typography
  static const Color textPrimary = Color(0xFFDCD8D0);
  static const Color textSecondary = Color(0xFF8C8881);
  static const Color textMuted = Color(0xFF56534E);
}

class OledTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: OledColors.trueBlack,
      canvasColor: OledColors.trueBlack,
      splashFactory: NoSplash.splashFactory,
      highlightColor: OledColors.warmAmber.withValues(alpha: 0.08),
      colorScheme: const ColorScheme.dark(
        surface: OledColors.trueBlack,
        primary: OledColors.warmAmber,
        onPrimary: OledColors.trueBlack,
        secondary: OledColors.softIndigo,
        onSecondary: OledColors.trueBlack,
        tertiary: OledColors.deepOrange,
        error: OledColors.mutedRose,
        onSurface: OledColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: OledColors.trueBlack,
        foregroundColor: OledColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: OledColors.trueBlack,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: OledColors.cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: OledColors.subtleBorder, width: 1),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: OledColors.warmAmber,
        inactiveTrackColor: OledColors.subtleBorder,
        thumbColor: OledColors.warmAmber,
        overlayColor: OledColors.warmAmber.withValues(alpha: 0.14),
        trackHeight: 4,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? OledColors.warmAmber.withValues(alpha: 0.16)
                : OledColors.elevatedSurface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? OledColors.warmAmber
                : OledColors.textPrimary,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? OledColors.warmAmber
                : OledColors.textSecondary,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: OledColors.subtleBorder),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: OledColors.cardSurface,
        modalBackgroundColor: OledColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: OledColors.subtleBorder, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: OledColors.trueBlack,
        indicatorColor: OledColors.warmAmber.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: OledColors.warmAmber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: OledColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
    );
  }
}
