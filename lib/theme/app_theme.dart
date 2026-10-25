import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData dark({ColorScheme? dynamicScheme, bool amoled = false}) {
    final base = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B9BB4),
          brightness: Brightness.dark,
        );
    final bg = amoled ? Colors.black : const Color(0xFF0C0C0E);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base.copyWith(surface: bg, surfaceContainerLowest: bg),
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: base.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: base.primary,
        inactiveTrackColor: base.onSurface.withOpacity(0.12),
        thumbColor: base.primary,
      ),
    );
  }

  static ThemeData light({ColorScheme? dynamicScheme}) {
    final base = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B6B82),
          brightness: Brightness.light,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: base,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        activeTrackColor: base.primary,
        inactiveTrackColor: base.onSurface.withOpacity(0.12),
        thumbColor: base.primary,
      ),
    );
  }
}
