import 'package:flutter/material.dart';

/// BiliTune design tokens for surface/brand/text/semantic colors, exposed as a
/// [ThemeExtension] so they switch automatically with dark/light mode.
///
/// Hierarchy in dark mode comes from surface brightness (not shadows):
/// bgBase → bgElevated → bgSurface → bgHighlight → bgActive (each lighter =
/// higher = closer to the user). See design doc §2 / §12.
@immutable
class BiliColors extends ThemeExtension<BiliColors> {
  const BiliColors({
    required this.brand,
    required this.brandLight,
    required this.brandDark,
    required this.accent,
    required this.bgBase,
    required this.bgSidebar,
    required this.bgElevated,
    required this.bgSurface,
    required this.bgHighlight,
    required this.bgActive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.onBrand,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  // Brand
  final Color brand; // play buttons, CTAs, active state
  final Color brandLight; // hover
  final Color brandDark; // pressed
  final Color accent; // Bilibili blue: info/links

  // Surfaces
  final Color bgBase;
  final Color bgSidebar;
  final Color bgElevated;
  final Color bgSurface;
  final Color bgHighlight;
  final Color bgActive;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color onBrand;

  // Semantic
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  static const BiliColors dark = BiliColors(
    brand: Color(0xFFFB7299),
    brandLight: Color(0xFFFF8DB1),
    brandDark: Color(0xFFD85A80),
    accent: Color(0xFF00AEEC),
    bgBase: Color(0xFF0A0A0C),
    bgSidebar: Color(0xFF010103),
    bgElevated: Color(0xFF16161A),
    bgSurface: Color(0xFF1C1C22),
    bgHighlight: Color(0xFF23232A),
    bgActive: Color(0xFF2E2E36),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9E9EAF),
    textTertiary: Color(0xFF6A6A78),
    onBrand: Color(0xFFFFFFFF),
    success: Color(0xFF1ED760),
    warning: Color(0xFFFFA42B),
    error: Color(0xFFE91429),
    info: Color(0xFF00AEEC),
  );

  static const BiliColors light = BiliColors(
    brand: Color(0xFFE85680), // -10% lightness for contrast on light surfaces
    brandLight: Color(0xFFFF8DB1),
    brandDark: Color(0xFFD85A80),
    accent: Color(0xFF00AEEC),
    bgBase: Color(0xFFF5F5F7),
    bgSidebar: Color(0xFFEFEFF1),
    bgElevated: Color(0xFFFFFFFF),
    bgSurface: Color(0xFFF0F0F2),
    bgHighlight: Color(0xFFE8E8EB),
    bgActive: Color(0xFFDCDCDF),
    textPrimary: Color(0xFF1D1D1F),
    textSecondary: Color(0xFF6E6E73),
    textTertiary: Color(0xFF8E8E93),
    onBrand: Color(0xFFFFFFFF),
    success: Color(0xFF1ED760),
    warning: Color(0xFFFFA42B),
    error: Color(0xFFE91429),
    info: Color(0xFF00AEEC),
  );

  @override
  BiliColors copyWith({
    Color? brand,
    Color? brandLight,
    Color? brandDark,
    Color? accent,
    Color? bgBase,
    Color? bgSidebar,
    Color? bgElevated,
    Color? bgSurface,
    Color? bgHighlight,
    Color? bgActive,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? onBrand,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
  }) {
    return BiliColors(
      brand: brand ?? this.brand,
      brandLight: brandLight ?? this.brandLight,
      brandDark: brandDark ?? this.brandDark,
      accent: accent ?? this.accent,
      bgBase: bgBase ?? this.bgBase,
      bgSidebar: bgSidebar ?? this.bgSidebar,
      bgElevated: bgElevated ?? this.bgElevated,
      bgSurface: bgSurface ?? this.bgSurface,
      bgHighlight: bgHighlight ?? this.bgHighlight,
      bgActive: bgActive ?? this.bgActive,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      onBrand: onBrand ?? this.onBrand,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }

  @override
  BiliColors lerp(ThemeExtension<BiliColors>? other, double t) {
    if (other is! BiliColors) return this;
    return BiliColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandLight: Color.lerp(brandLight, other.brandLight, t)!,
      brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      bgSidebar: Color.lerp(bgSidebar, other.bgSidebar, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgHighlight: Color.lerp(bgHighlight, other.bgHighlight, t)!,
      bgActive: Color.lerp(bgActive, other.bgActive, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// Ergonomic access: `context.colors.brand`.
extension BiliColorsX on BuildContext {
  BiliColors get colors => Theme.of(this).extension<BiliColors>()!;
}
