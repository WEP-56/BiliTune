import '../theme/app_dimens.dart';

/// Layout mode is width-driven: at/above [AppLayout.desktopBreakpoint] we show
/// the 3-column desktop shell, otherwise the mobile tab shell. Narrowing the
/// Windows window therefore previews the mobile layout (design doc §11).
class Breakpoints {
  const Breakpoints._();

  static bool isDesktop(double width) =>
      width >= AppLayout.desktopBreakpoint;
}
