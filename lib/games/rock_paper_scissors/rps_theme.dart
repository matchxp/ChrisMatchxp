// ─────────────────────────────────────────────────────────────
//  Rock Paper Scissors – Theme
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RPSTheme {
  RPSTheme._();

  static const Color bg      = Color(0xFF040210);
  static const Color bgCard  = Color(0xFF1A0A2E);
  static const Color bgPanel = Color(0xFF120D2E);

  static const Color purple      = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFFA78BFA);
  static const Color gold        = Color(0xFFFFB800);
  static const Color cyan        = Color(0xFF06B6D4);
  static const Color muted       = Color(0xFF6D5F8A);
  static const Color dimLine     = Color(0xFF2A2050);

  static const BoxDecoration bgDecoration = BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(0.0, -1.0),
      radius: 1.6,
      colors: [
        Color(0xFF3B1580),
        Color(0xFF1E0A50),
        Color(0xFF110630),
        Color(0xFF080418),
        Color(0xFF040210),
      ],
      stops: [0.0, 0.22, 0.48, 0.74, 1.0],
    ),
  );

  static const LinearGradient pillGradient = LinearGradient(
    colors: [
      Color(0xFF5B2FCE),
      Color(0xFF7C3AED),
      Color(0xFF9B6DF5),
      Color(0xFFB07CFF),
    ],
  );

  static const Color blob1 = Color(0x526D28D9);
  static const Color blob2 = Color(0x329333EA);
  static const Color blob3 = Color(0x287C3AED);

  // Now using GoogleFonts.fredoka() to match Emoji Charades exactly.
  // (The old 'Fredoka One'/'Fredoka' family names weren't declared as
  //  pubspec assets, so they were silently falling back to the default
  //  system font.)
  //
  // Use `RPSTheme.font(...)` from any call site that previously did
  // `TextStyle(fontFamily: RPSTheme.fontTitle/fontBody, ...)`.

  /// One-stop helper — matches the `_f(...)` shorthand used in
  /// Emoji Charades. Returns a Fredoka TextStyle.
  static TextStyle font(
    double size, {
    FontWeight fw = FontWeight.w400,
    Color color = Colors.white,
    double letterSpacing = 0,
    double height = 1.0,
  }) => GoogleFonts.fredoka(
        fontSize: size, fontWeight: fw, color: color,
        letterSpacing: letterSpacing, height: height,
      );

  static TextStyle titleStyle({double size = 62, Color color = Colors.white}) =>
      font(size, fw: FontWeight.w700, color: color);

  static TextStyle bodyStyle({double size = 15, Color color = Colors.white}) =>
      font(size, fw: FontWeight.w600, color: color);

  static TextStyle navLabel = font(11,
      fw: FontWeight.w700, color: purpleLight, letterSpacing: 2.2);

  static BorderRadius pillRadius = BorderRadius.circular(50);
  static BorderRadius cardRadius = BorderRadius.circular(20);
}
