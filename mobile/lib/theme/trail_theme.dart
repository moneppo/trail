import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Trail Cartography color tokens: a day chart and a night chart. Values come
/// from the design system's tokens.json.
class TrailColors {
  final Color paper;
  final Color paperShade;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color rule;
  final Color route;
  final Color onRoute;
  final Color unmapped;
  final Color candidate;
  final Color accepted;

  const TrailColors({
    required this.paper,
    required this.paperShade,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.rule,
    required this.route,
    required this.onRoute,
    required this.unmapped,
    required this.candidate,
    required this.accepted,
  });

  static const day = TrailColors(
    paper: Color(0xFFF8F7F2),
    paperShade: Color(0xFFDDD3B5),
    ink: Color(0xFF1C1915),
    inkSoft: Color(0xFF4D463B),
    inkFaint: Color(0xFF7A7261),
    rule: Color(0xFFB8AD92),
    route: Color(0xFF8C2B22),
    onRoute: Color(0xFFF8F7F2),
    unmapped: Color(0xFF8A5A10),
    candidate: Color(0xFF2F4A6B),
    accepted: Color(0xFF2B6A52),
  );

  static const night = TrailColors(
    paper: Color(0xFF17150F),
    paperShade: Color(0xFF322E23),
    ink: Color(0xFFECE4D0),
    inkSoft: Color(0xFFBFB59D),
    inkFaint: Color(0xFF8F8671),
    rule: Color(0xFF4D4636),
    route: Color(0xFFE4745F),
    onRoute: Color(0xFF17150F),
    unmapped: Color(0xFFDCA847),
    candidate: Color(0xFF94B5D9),
    accepted: Color(0xFF86C9A9),
  );

  static TrailColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? night : day;
}

/// Line weights and dash pattern, in logical pixels.
const strokeHair = 0.75;
const strokeLine = 1.5;
const strokeBold = 2.5;
const strokeRoute = 4.0;
const strokeTrail = 6.0;
const dashUnmapped = [10.0, 7.0];

const radiusSm = 2.0;
const radiusMd = 6.0;

/// Type styles. Titles in IM Fell English SC, text in IM Fell English, labels,
/// numbers and buttons in Barlow Condensed. Letter spacing is the token's em
/// value times the font size.
class TrailText {
  static TextStyle titleXl(TrailColors c) => GoogleFonts.imFellEnglishSc(
      fontSize: 40, height: 44 / 40, letterSpacing: 0.8, color: c.ink);
  static TextStyle titleLg(TrailColors c) => GoogleFonts.imFellEnglishSc(
      fontSize: 28, height: 32 / 28, letterSpacing: 0.56, color: c.ink);
  static TextStyle titleMd(TrailColors c) => GoogleFonts.imFellEnglishSc(
      fontSize: 20, height: 26 / 20, letterSpacing: 0.6, color: c.ink);

  static TextStyle body(TrailColors c) =>
      GoogleFonts.imFellEnglish(fontSize: 17, height: 24 / 17, color: c.ink);
  static TextStyle bodySm(TrailColors c) =>
      GoogleFonts.imFellEnglish(fontSize: 15, height: 21 / 15, color: c.ink);
  static TextStyle caption(TrailColors c) => GoogleFonts.imFellEnglish(
      fontSize: 14,
      height: 20 / 14,
      fontStyle: FontStyle.italic,
      color: c.inkSoft);
  static TextStyle hint(TrailColors c) => GoogleFonts.imFellEnglish(
      fontSize: 15,
      height: 21 / 15,
      fontStyle: FontStyle.italic,
      color: c.unmapped);
  static TextStyle error(TrailColors c) => GoogleFonts.imFellEnglish(
      fontSize: 15,
      height: 21 / 15,
      fontStyle: FontStyle.italic,
      color: c.route);

  /// Set in uppercase: pass the text through [String.toUpperCase].
  static TextStyle label(TrailColors c) => GoogleFonts.barlowCondensed(
      fontSize: 13,
      height: 16 / 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.82,
      color: c.inkSoft);
  static TextStyle data(TrailColors c) => GoogleFonts.barlowCondensed(
      fontSize: 16,
      height: 20 / 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.64,
      color: c.ink,
      fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle button(TrailColors c) => GoogleFonts.barlowCondensed(
      fontSize: 16,
      height: 18 / 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.92,
      color: c.ink);
}

ThemeData trailTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? TrailColors.night : TrailColors.day;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.route,
    onPrimary: c.onRoute,
    secondary: c.candidate,
    onSecondary: c.paper,
    error: c.route,
    onError: c.onRoute,
    surface: c.paper,
    onSurface: c.ink,
  );
  final focusBorder = UnderlineInputBorder(
    borderSide: BorderSide(color: c.candidate, width: strokeBold),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.paper,
    canvasColor: c.paper,
    dividerColor: c.rule,
    textTheme: TextTheme(
      displayMedium: TrailText.titleXl(c),
      headlineSmall: TrailText.titleLg(c),
      titleLarge: TrailText.titleMd(c),
      bodyLarge: TrailText.body(c),
      bodyMedium: TrailText.body(c),
      bodySmall: TrailText.caption(c),
      labelLarge: TrailText.button(c),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.route),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      hintStyle: TrailText.body(c).copyWith(color: c.inkSoft),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: c.ink, width: strokeLine),
      ),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: c.ink, width: strokeLine),
      ),
      focusedBorder: focusBorder,
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.ink),
  );
}
