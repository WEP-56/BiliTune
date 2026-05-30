import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../../core/theme/app_dimens.dart';
import '../playbar/play_bar.dart';
import 'widgets/now_playing_panel.dart';
import 'widgets/sidebar.dart';
import 'widgets/top_bar.dart';

/// Desktop 3-column shell (design doc §6.1): top bar over [sidebar | content |
/// now-playing], with the play bar pinned to the bottom across the full width.
class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowPlayingOpen = ref.watch(nowPlayingOpenProvider);

    return Scaffold(
      body: Column(
        children: [
          const TopBar(),
          Expanded(
            child: Row(
              children: [
                Sidebar(navigationShell: navigationShell),
                Expanded(child: navigationShell),
                AnimatedSwitcher(
                  duration: AppDuration.normal,
                  transitionBuilder: (child, anim) => SizeTransition(
                    axis: Axis.horizontal,
                    sizeFactor: anim,
                    child: child,
                  ),
                  child: nowPlayingOpen
                      ? const NowPlayingPanel(key: ValueKey('now-playing'))
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const PlayBar(),
        ],
      ),
    );
  }
}
