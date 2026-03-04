import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Boiler Room typography — industrial, utilitarian.
///
/// - **Oswald**: Headers (all-caps, condensed)
/// - **Source Code Pro**: Chat messages (monospaced, readable)
/// - **Barlow Condensed**: Gauges, labels, status bar
/// - **JetBrains Mono**: Code blocks
abstract final class BoilerTypography {
  // ── Font families ──

  static TextStyle oswald({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    Color color = BoilerColors.steamWhite,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 1.2,
    );
  }

  static TextStyle sourceCodePro({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = BoilerColors.steamWhite,
  }) {
    return GoogleFonts.sourceCodePro(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.5,
    );
  }

  static TextStyle barlowCondensed({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color color = BoilerColors.steamMuted,
  }) {
    return GoogleFonts.barlowCondensed(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle jetBrainsMono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color color = BoilerColors.steamWhite,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.4,
    );
  }

  // ── Presets ──

  static TextStyle get header =>
      oswald(fontSize: 16, fontWeight: FontWeight.w700);

  static TextStyle get headerLarge =>
      oswald(fontSize: 20, fontWeight: FontWeight.w700);

  static TextStyle get chatMessage => sourceCodePro(fontSize: 14);

  static TextStyle get chatNick => sourceCodePro(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: BoilerColors.furnaceOrange,
      );

  static TextStyle get chatTimestamp => barlowCondensed(
        fontSize: 12,
        color: BoilerColors.steamDim,
      );

  static TextStyle get label => barlowCondensed(fontSize: 13);

  static TextStyle get statusBar => barlowCondensed(
        fontSize: 12,
        color: BoilerColors.steamMuted,
      );

  static TextStyle get codeBlock => jetBrainsMono(fontSize: 13);

  static TextStyle get gaugeValue => barlowCondensed(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: BoilerColors.gaugeAmber,
      );

  /// Text theme for Material widget compatibility.
  static TextTheme get textTheme => TextTheme(
        displayLarge: headerLarge,
        displayMedium: header,
        titleLarge: oswald(fontSize: 18),
        titleMedium: oswald(fontSize: 16),
        titleSmall: oswald(fontSize: 14),
        bodyLarge: sourceCodePro(fontSize: 15),
        bodyMedium: chatMessage,
        bodySmall: sourceCodePro(fontSize: 12),
        labelLarge: barlowCondensed(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: label,
        labelSmall: barlowCondensed(fontSize: 11),
      );
}
