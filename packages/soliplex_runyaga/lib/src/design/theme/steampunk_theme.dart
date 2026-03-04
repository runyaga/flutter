import 'package:flutter/material.dart';

import '../../markdown/markdown_theme_extension.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import 'steampunk_theme_extension.dart';

/// Builds the Boiler Room [ThemeData].
ThemeData boilerRoomTheme() {
  const colorScheme = ColorScheme.dark(
    surface: BoilerColors.background,
    onSurface: BoilerColors.steamWhite,
    primary: BoilerColors.furnaceOrange,
    onPrimary: BoilerColors.background,
    secondary: BoilerColors.iron,
    onSecondary: BoilerColors.steamWhite,
    tertiary: BoilerColors.rust,
    error: BoilerColors.error,
    onError: BoilerColors.steamWhite,
    surfaceContainerHighest: BoilerColors.surface,
    outline: BoilerColors.border,
    outlineVariant: BoilerColors.borderHeavy,
  );

  final textTheme = BoilerTypography.textTheme;

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: BoilerColors.background,
    canvasColor: BoilerColors.surface,
    dividerColor: BoilerColors.border,
    dividerTheme: const DividerThemeData(
      color: BoilerColors.border,
      thickness: 2,
      space: 2,
    ),

    // ── AppBar ──
    appBarTheme: AppBarTheme(
      backgroundColor: BoilerColors.surface,
      foregroundColor: BoilerColors.steamWhite,
      elevation: 0,
      titleTextStyle: BoilerTypography.oswald(fontSize: 18),
    ),

    // ── Cards ──
    cardTheme: CardThemeData(
      color: BoilerColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: BoilerColors.border),
      ),
    ),

    // ── Input ──
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BoilerColors.codeBackground,
      hintStyle: BoilerTypography.sourceCodePro(
        color: BoilerColors.steamDim,
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: BoilerColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: BoilerColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: BoilerColors.furnaceOrange),
      ),
    ),

    // ── Buttons ──
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BoilerColors.rust,
        foregroundColor: BoilerColors.steamWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        textStyle: BoilerTypography.barlowCondensed(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: BoilerColors.iron,
      ),
    ),

    // ── Scrollbar ──
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(BoilerColors.iron.withAlpha(120)),
      trackColor: WidgetStatePropertyAll(BoilerColors.surface.withAlpha(60)),
      radius: const Radius.circular(1),
      thickness: const WidgetStatePropertyAll(6),
    ),

    // ── Tab bar ──
    tabBarTheme: TabBarThemeData(
      labelColor: BoilerColors.furnaceOrange,
      unselectedLabelColor: BoilerColors.steamMuted,
      indicatorColor: BoilerColors.furnaceOrange,
      labelStyle: BoilerTypography.barlowCondensed(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: BoilerTypography.barlowCondensed(fontSize: 13),
    ),

    // ── Tooltip ──
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: BoilerColors.surfaceHigh,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: BoilerColors.border),
      ),
      textStyle: BoilerTypography.barlowCondensed(
        fontSize: 12,
        color: BoilerColors.steamWhite,
      ),
    ),

    // ── SnackBar ──
    snackBarTheme: SnackBarThemeData(
      backgroundColor: BoilerColors.surface,
      contentTextStyle: BoilerTypography.sourceCodePro(fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: BoilerColors.border),
      ),
    ),

    // ── Extensions ──
    extensions: [
      SteampunkTheme.defaultTheme,
      _boilerMarkdownTheme(textTheme),
    ],
  );
}

MarkdownThemeExtension _boilerMarkdownTheme(TextTheme textTheme) {
  return MarkdownThemeExtension(
    h1: BoilerTypography.oswald(
      fontSize: 20,
      color: BoilerColors.furnaceOrange,
    ),
    h2: BoilerTypography.oswald(
      fontSize: 17,
      color: BoilerColors.furnaceOrange,
    ),
    h3: BoilerTypography.oswald(
      fontSize: 15,
      color: BoilerColors.gaugeAmber,
    ),
    body: BoilerTypography.sourceCodePro(fontSize: 14),
    code: BoilerTypography.jetBrainsMono(fontSize: 13).copyWith(
      backgroundColor: BoilerColors.codeBackground,
    ),
    link: TextStyle(
      color: BoilerColors.furnaceOrange,
      decoration: TextDecoration.underline,
      decorationColor: BoilerColors.furnaceOrange.withAlpha(120),
    ),
    codeBlockDecoration: BoxDecoration(
      color: BoilerColors.codeBackground,
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: BoilerColors.border, width: 2),
    ),
    blockquoteDecoration: const BoxDecoration(
      border: Border(
        left: BorderSide(color: BoilerColors.iron, width: 3),
      ),
    ),
  );
}
