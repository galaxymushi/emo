import 'package:flutter/material.dart';

class EmoColors {
  static const ink = Color(0xFF0A1B3D);
  static const inkSoft = Color(0xFF2B3F63);
  static const muted = Color(0xFF63769A);
  static const faint = Color(0xFF93A3C1);
  static const blue = Color(0xFF2E7DFF);
  static const blueDeep = Color(0xFF1449E8);
  static const blueInk = Color(0xFF0E3AA8);
  static const sky = Color(0xFF6FB6FF);
  static const ice = Color(0xFFE4F0FF);
  static const white = Color(0xFFFFFFFF);
  static const success = Color(0xFF0E9F6E);
  static const warning = Color(0xFFD98A25);
  static const danger = Color(0xFFDE3B45);
}

class EmoSizes {
  static const double page = 22;
  static const double cardRadius = 26;
  static const double smallRadius = 18;
  static const double pill = 100;
  static const double navSpace = 118;
}

class EmoGradients {
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4C93FF), EmoColors.blue, Color(0xFF1A52F0)],
    stops: [0.0, 0.45, 1.0],
  );

  static const primarySoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEAF3FF), Color(0xFFD6E8FF)],
  );

  static const glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xC7FFFFFF), Color(0x8AFFFFFF)],
  );

  static const glassDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xE0FFFFFF), Color(0xB8F2F8FF)],
  );

  static const userBubble = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4C93FF), Color(0xFF1F5CF5)],
  );
}

class EmoShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF1A4FA8).withValues(alpha: 0.10),
      blurRadius: 30,
      offset: const Offset(0, 16),
      spreadRadius: -8,
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.65),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: const Color(0xFF1449E8).withValues(alpha: 0.28),
      blurRadius: 30,
      offset: const Offset(0, 14),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> button = [
    BoxShadow(
      color: EmoColors.blue.withValues(alpha: 0.38),
      blurRadius: 22,
      offset: const Offset(0, 10),
      spreadRadius: -6,
    ),
  ];
}

class EmoTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: EmoColors.blue,
        brightness: Brightness.light,
        primary: EmoColors.blue,
        surface: Colors.white,
      ),
      splashColor: EmoColors.blue.withValues(alpha: 0.06),
      highlightColor: Colors.transparent,
      hoverColor: EmoColors.blue.withValues(alpha: 0.04),
    );

    final text = base.textTheme
        .apply(fontFamily: 'Manrope', bodyColor: EmoColors.ink, displayColor: EmoColors.ink);

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 40,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
          color: EmoColors.ink,
        ),
        displayMedium: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 32,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          color: EmoColors.ink,
        ),
        headlineSmall: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 24,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: EmoColors.ink,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 19,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: EmoColors.ink,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 15.5,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
          color: EmoColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 15,
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: EmoColors.ink,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13.5,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: EmoColors.inkSoft,
        ),
        bodySmall: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: EmoColors.muted,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: EmoColors.ink,
        ),
        labelSmall: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: EmoColors.muted,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: EmoColors.blue,
        inactiveTrackColor: EmoColors.blue.withValues(alpha: 0.14),
        thumbColor: Colors.white,
        overlayColor: EmoColors.blue.withValues(alpha: 0.10),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9, elevation: 4),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
      ),
      dividerTheme: DividerThemeData(
        color: EmoColors.ink.withValues(alpha: 0.07),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: EmoColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: EdgeInsets.fromLTRB(20, 0, 20, 110),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: Color(0x66081B3D),
      ),
    );
  }
}

TextStyle emoLabel({Color color = EmoColors.muted, double size = 11}) => TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.9,
      color: color,
    );
