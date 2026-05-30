import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../playbar/mini_player.dart';
import '../player/full_screen_player.dart';

/// Mobile shell (design doc §7.1): page content with a floating mini player
/// stacked above a 4-tab bottom bar.
class MobileShell extends ConsumerWidget {
  const MobileShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _openFullScreen(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => const FullScreenPlayer(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(onTap: () => _openFullScreen(context)),
          _BottomTabs(navigationShell: navigationShell),
        ],
      ),
    );
  }
}

class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgSidebar,
        border: Border(
          top: BorderSide(color: colors.textPrimary.withValues(alpha: 0.06)),
        ),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        height: AppLayout.bottomNavHeight,
        child: Row(
          children: [
            for (final tab in mobileTabs)
              Expanded(
                child: _TabItem(
                  icon: tab.icon,
                  selectedIcon: tab.selectedIcon,
                  label: tab.label,
                  selected: navigationShell.currentIndex == tab.branch,
                  onTap: () => navigationShell.goBranch(
                    tab.branch,
                    initialLocation: tab.branch == navigationShell.currentIndex,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = selected ? colors.brand : colors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? selectedIcon : icon, color: fg, size: 24),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.overline.copyWith(color: fg)),
        ],
      ),
    );
  }
}
