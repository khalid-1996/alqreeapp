import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF000A3A);
  static const card = Color(0xFF051755);
  static const miniPlayer = Color(0xFF0A1E6B);
  static const accent = Color(0xFF3BA7FF);
  static const text = Colors.white;
  static const muted = Color(0xFFA9B3D6);
  static const soft = Color(0xFFDDE3F7);
  static const live = Color(0xFFFF5A5A);
  static const liveText = Color(0xFFFF8A8A);

  static const glass = Color(0x14FFFFFF); // white 8%
  static const glassSoft = Color(0x0FFFFFFF); // white 6%
  static const glassBorder = Color(0x24FFFFFF); // white 14%
  static const glassBorderSoft = Color(0x1AFFFFFF); // white 10%
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accent,
        surface: AppColors.background,
        onPrimary: AppColors.background,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.tajawalTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Font for Quran, hadith and adhkar text.
  static TextStyle scripture({double size = 19, Color color = Colors.white, FontWeight weight = FontWeight.w400, double height = 1.85}) =>
      GoogleFonts.amiri(fontSize: size, color: color, fontWeight: weight, height: height);
}

/// Picks a font size from text length so long texts shrink instead of being cut.
double autoScriptureSize(String text, {double max = 20, double min = 14.5}) {
  final len = text.length;
  double size;
  if (len <= 70) {
    size = max;
  } else if (len <= 130) {
    size = max - 2;
  } else if (len <= 220) {
    size = max - 4;
  } else {
    size = min;
  }
  return size < min ? min : size;
}
