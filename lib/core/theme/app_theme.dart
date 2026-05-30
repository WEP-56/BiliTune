import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Assembles dark/light [ThemeData] from BiliTune design tokens. Dark mode is
/// the primary experience: no shadows, hierarchy via surface brightness.
class AppTheme {
  const AppTheme._();

  static ThemeData dark() => _build(BiliColors.dark, Brightness.dark);
  static ThemeData light() => _build(BiliColors.light, Brightness.light);

  static ThemeData _build(BiliColors c, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: c.onBrand,
      secondary: c.accent,
      onSecondary: c.onBrand,
      error: c.error,
      onError: Colors.white,
      surface: c.bgElevated,
      onSurface: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.bgBase,
      canvasColor: c.bgBase,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: AppTypography.textTheme(c.textPrimary),
      iconTheme: IconThemeData(color: c.textSecondary, size: 24),
      dividerTheme: DividerThemeData(
        color: c.textPrimary.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: AppTypography.caption.copyWith(color: c.textPrimary),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: c.brand,
        inactiveTrackColor: c.bgActive,
        thumbColor: c.textPrimary,
        overlayColor: c.brand.withValues(alpha: 0.16),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }
}
