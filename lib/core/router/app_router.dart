import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/downloads/downloads_page.dart';
import '../../features/discover/discover_page.dart';
import '../../features/library/library_page.dart';
import '../../features/search/search_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/shell/app_shell.dart';

/// Top-level navigation targets. Branch index == position in this list.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

const List<NavDestination> navDestinations = <NavDestination>[
  NavDestination(
    label: '发现音乐',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore_rounded,
    route: '/discover',
  ),
  NavDestination(
    label: '搜索',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search_rounded,
    route: '/search',
  ),
  NavDestination(
    label: '我的音乐',
    icon: Icons.library_music_outlined,
    selectedIcon: Icons.library_music_rounded,
    route: '/library',
  ),
  NavDestination(
    label: '下载',
    icon: Icons.download_outlined,
    selectedIcon: Icons.download_rounded,
    route: '/downloads',
  ),
  NavDestination(
    label: '设置',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    route: '/settings',
  ),
];

/// Mobile bottom-tab branches (design doc §7.2): 发现 / 搜索 / 音乐库 / 我的.
/// "我的" reuses the settings branch as a profile hub.
const List<({String label, IconData icon, IconData selectedIcon, int branch})>
mobileTabs =
    <({String label, IconData icon, IconData selectedIcon, int branch})>[
      (
        label: '发现',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        branch: 0,
      ),
      (
        label: '搜索',
        icon: Icons.search_outlined,
        selectedIcon: Icons.search_rounded,
        branch: 1,
      ),
      (
        label: '音乐库',
        icon: Icons.library_music_outlined,
        selectedIcon: Icons.library_music_rounded,
        branch: 2,
      ),
      (
        label: '我的',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        branch: 4,
      ),
    ];

final GoRouter appRouter = GoRouter(
  initialLocation: '/discover',
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/discover', builder: (_, _) => const DiscoverPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/search', builder: (_, _) => const SearchPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/library', builder: (_, _) => const LibraryPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/downloads',
              builder: (_, _) => const DownloadsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          ],
        ),
      ],
    ),
  ],
);
