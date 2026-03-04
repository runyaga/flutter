import 'package:flutter/material.dart';

/// The Boiler Room color palette — raw industrial power.
abstract final class BoilerColors {
  // ── Core surfaces ──
  static const background = Color(0xFF1C1C1E); // Cold steel
  static const surface = Color(0xFF2C2C2E); // Steel plate
  static const surfaceHigh = Color(0xFF3C3C3E); // Raised panel

  // ── Metals ──
  static const iron = Color(0xFF6B6B70); // Brushed iron
  static const ironLight = Color(0xFF8A8A90); // Highlight

  // ── Accents ──
  static const rust = Color(0xFFA0522D); // Oxidized iron
  static const furnaceOrange = Color(0xFFE86A17); // Furnace glow
  static const furnaceRed = Color(0xFFCC3300); // Hot metal
  static const pipeGreen = Color(0xFF2E5A3A); // Patina pipe
  static const gaugeAmber = Color(0xFFFFAA00); // Warning

  // ── Text ──
  static const steamWhite = Color(0xFFE8E4DC); // Primary text
  static const steamMuted = Color(0xFFA0A0A4); // Secondary text
  static const steamDim = Color(0xFF707074); // Tertiary text

  // ── Code ──
  static const codeBackground = Color(0xFF12181C); // Deep interior

  // ── Borders ──
  static const border = Color(0xFF404044);
  static const borderHeavy = Color(0xFF555558);

  // ── Semantic ──
  static const error = furnaceRed;
  static const warning = gaugeAmber;
  static const success = pipeGreen;
}
