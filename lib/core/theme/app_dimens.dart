import 'package:flutter/widgets.dart';

/// Spacing scale on a 4px baseline grid (design doc §4).
class AppSpacing {
  const AppSpacing._();

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
}

/// Corner radii (design doc §5). Shape encodes type: rounded-square = content,
/// circle = creator/user.
class AppRadius {
  const AppRadius._();

  static const double sm = 4; // album/playlist cover
  static const double md = 8; // standard card
  static const double lg = 12; // window, dialog
  static const double pill = 24; // inputs, primary buttons

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Motion timings (design doc §9). opacity + transform driven, ease curve.
class AppDuration {
  const AppDuration._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration page = Duration(milliseconds: 250);
}

/// Fixed chrome dimensions (design doc §6.6 / §7.5).
class AppLayout {
  const AppLayout._();

  // Desktop
  static const double topBarHeight = 56;
  static const double playBarHeight = 80;
  static const double sidebarWidth = 240;
  static const double sidebarCollapsedWidth = 64;
  static const double nowPlayingWidth = 320;

  // Mobile
  static const double mobileTopBarHeight = 48;
  static const double miniPlayerHeight = 64;
  static const double bottomNavHeight = 56;

  /// Width at/above which we render the desktop 3-column shell.
  static const double desktopBreakpoint = 900;

  // Window
  static const Size defaultWindowSize = Size(1280, 800);
  static const Size minWindowSize = Size(960, 600);
}
