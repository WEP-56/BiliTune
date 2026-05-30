import 'package:flutter/material.dart';

/// Type scale (design doc §3.2). Styles are color-agnostic — color is applied
/// by the theme's text color. Tight bold headings create energy; quiet body
/// text recedes; the two poles establish hierarchy without extra ornament.
///
/// Note (§3.3): Chinese titles must not use negative letter-spacing, so title
/// styles keep spacing at 0 and rely on size/weight contrast instead. Only the
/// Hero banner (often mixed Latin) gets a slight negative tracking.
class AppTypography {
  const AppTypography._();

  /// CJK-aware fallback chain (mirrors the design doc's font stack).
  static const List<String> fallback = <String>[
    'Segoe UI',
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans SC',
    'Roboto',
    'Arial',
  ];

  static const TextStyle hero = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static const TextStyle titleL = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle titleM = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle titleS = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.7,
  );

  /// Maps the scale onto a Material [TextTheme] so framework widgets inherit it.
  static TextTheme textTheme(Color primary) {
    final base = TextTheme(
      displayLarge: hero,
      headlineMedium: titleL,
      headlineSmall: titleM,
      titleMedium: titleS,
      bodyMedium: body,
      bodySmall: caption,
      labelSmall: overline,
    );
    return base.apply(
      bodyColor: primary,
      displayColor: primary,
      fontFamilyFallback: fallback,
    );
  }
}
