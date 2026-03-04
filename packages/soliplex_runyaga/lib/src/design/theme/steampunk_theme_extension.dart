import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// Custom theme extension for Boiler Room-specific properties
/// that don't map to Material's built-in theme.
class SteampunkTheme extends ThemeExtension<SteampunkTheme> {
  const SteampunkTheme({
    required this.iron,
    required this.ironLight,
    required this.rust,
    required this.furnaceOrange,
    required this.furnaceRed,
    required this.pipeGreen,
    required this.gaugeAmber,
    required this.steamWhite,
    required this.steamMuted,
    required this.steamDim,
    required this.codeBackground,
    required this.borderColor,
    required this.borderHeavy,
    required this.surfaceHigh,
  });

  final Color iron;
  final Color ironLight;
  final Color rust;
  final Color furnaceOrange;
  final Color furnaceRed;
  final Color pipeGreen;
  final Color gaugeAmber;
  final Color steamWhite;
  final Color steamMuted;
  final Color steamDim;
  final Color codeBackground;
  final Color borderColor;
  final Color borderHeavy;
  final Color surfaceHigh;

  static const defaultTheme = SteampunkTheme(
    iron: BoilerColors.iron,
    ironLight: BoilerColors.ironLight,
    rust: BoilerColors.rust,
    furnaceOrange: BoilerColors.furnaceOrange,
    furnaceRed: BoilerColors.furnaceRed,
    pipeGreen: BoilerColors.pipeGreen,
    gaugeAmber: BoilerColors.gaugeAmber,
    steamWhite: BoilerColors.steamWhite,
    steamMuted: BoilerColors.steamMuted,
    steamDim: BoilerColors.steamDim,
    codeBackground: BoilerColors.codeBackground,
    borderColor: BoilerColors.border,
    borderHeavy: BoilerColors.borderHeavy,
    surfaceHigh: BoilerColors.surfaceHigh,
  );

  static SteampunkTheme of(BuildContext context) {
    return Theme.of(context).extension<SteampunkTheme>() ?? defaultTheme;
  }

  @override
  SteampunkTheme copyWith({
    Color? iron,
    Color? ironLight,
    Color? rust,
    Color? furnaceOrange,
    Color? furnaceRed,
    Color? pipeGreen,
    Color? gaugeAmber,
    Color? steamWhite,
    Color? steamMuted,
    Color? steamDim,
    Color? codeBackground,
    Color? borderColor,
    Color? borderHeavy,
    Color? surfaceHigh,
  }) {
    return SteampunkTheme(
      iron: iron ?? this.iron,
      ironLight: ironLight ?? this.ironLight,
      rust: rust ?? this.rust,
      furnaceOrange: furnaceOrange ?? this.furnaceOrange,
      furnaceRed: furnaceRed ?? this.furnaceRed,
      pipeGreen: pipeGreen ?? this.pipeGreen,
      gaugeAmber: gaugeAmber ?? this.gaugeAmber,
      steamWhite: steamWhite ?? this.steamWhite,
      steamMuted: steamMuted ?? this.steamMuted,
      steamDim: steamDim ?? this.steamDim,
      codeBackground: codeBackground ?? this.codeBackground,
      borderColor: borderColor ?? this.borderColor,
      borderHeavy: borderHeavy ?? this.borderHeavy,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    );
  }

  @override
  SteampunkTheme lerp(covariant SteampunkTheme? other, double t) {
    if (other == null) return this;
    return SteampunkTheme(
      iron: Color.lerp(iron, other.iron, t)!,
      ironLight: Color.lerp(ironLight, other.ironLight, t)!,
      rust: Color.lerp(rust, other.rust, t)!,
      furnaceOrange: Color.lerp(furnaceOrange, other.furnaceOrange, t)!,
      furnaceRed: Color.lerp(furnaceRed, other.furnaceRed, t)!,
      pipeGreen: Color.lerp(pipeGreen, other.pipeGreen, t)!,
      gaugeAmber: Color.lerp(gaugeAmber, other.gaugeAmber, t)!,
      steamWhite: Color.lerp(steamWhite, other.steamWhite, t)!,
      steamMuted: Color.lerp(steamMuted, other.steamMuted, t)!,
      steamDim: Color.lerp(steamDim, other.steamDim, t)!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      borderHeavy: Color.lerp(borderHeavy, other.borderHeavy, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
    );
  }
}
