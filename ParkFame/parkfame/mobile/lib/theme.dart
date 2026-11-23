import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Brand {
  static const navy = Color(0xFF0B1220);
  static const surface = Color(0xFF131C2E);
  static const surface2 = Color(0xFF1B2740);
  static const accent = Color(0xFF00D1A0);
  static const amber = Color(0xFFFFC53D);
  static const danger = Color(0xFFFF5C7A);
  static const muted = Color(0xFF8A97B2);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Brand.accent, brightness: Brightness.dark)
        .copyWith(primary: Brand.accent, onPrimary: Brand.navy, surface: Brand.surface),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Brand.navy,
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: Brand.navy,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Brand.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Brand.surface,
      indicatorColor: Brand.accent.withValues(alpha: 0.18),
    ),
  );
}
