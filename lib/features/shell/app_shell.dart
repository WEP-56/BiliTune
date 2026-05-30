import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/breakpoints.dart';
import 'desktop_shell.dart';
import 'mobile_shell.dart';

/// Chooses the desktop 3-column shell or the mobile tab shell based on the
/// available width. Both render [navigationShell] (the active branch) as their
/// content area, so navigation state survives the layout switch.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Breakpoints.isDesktop(constraints.maxWidth)
            ? DesktopShell(navigationShell: navigationShell)
            : MobileShell(navigationShell: navigationShell);
      },
    );
  }
}
