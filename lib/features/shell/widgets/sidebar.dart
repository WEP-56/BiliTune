import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/mock/mock_data.dart';
import '../../../state/providers.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final width = collapsed
        ? AppLayout.sidebarCollapsedWidth
        : AppLayout.sidebarWidth;
    final library = ref.watch(libraryProvider);
    final folders = library.folders.isEmpty
        ? MockData.libraryFolders
        : library.folders
              .map((folder) => folder.toCardItem())
              .toList(growable: false);

    return AnimatedContainer(
      duration: AppDuration.normal,
      curve: Curves.ease,
      width: width,
      color: colors.bgSidebar,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(collapsed: collapsed),
          const SizedBox(height: AppSpacing.s4),
          for (int i = 0; i < navDestinations.length; i++)
            _NavTile(
              icon: navDestinations[i].icon,
              selectedIcon: navDestinations[i].selectedIcon,
              label: navDestinations[i].label,
              collapsed: collapsed,
              selected: navigationShell.currentIndex == i,
              onTap: () => navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.s2,
              vertical: AppSpacing.s3,
            ),
            child: Divider(height: 1),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s2,
                0,
                AppSpacing.s2,
                AppSpacing.s2,
              ),
              child: Text(
                '我的歌单',
                style: AppTypography.overline.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final folder in folders)
                  _PlaylistTile(
                    title: folder.title,
                    subtitle: folder.subtitle,
                    seed: folder.gradientSeed,
                    collapsed: collapsed,
                  ),
              ],
            ),
          ),
          if (library.errorMessage != null && !collapsed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Text(
                library.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
      child: Row(
        mainAxisAlignment: collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Icon(Icons.graphic_eq_rounded, color: colors.brand, size: 26),
          if (!collapsed) ...[
            const SizedBox(width: AppSpacing.s2),
            Text(
              'BiliTune',
              style: AppTypography.titleS.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
          ],
          if (!collapsed)
            _IconBtn(
              icon: Icons.menu_open_rounded,
              onTap: () => ref.read(sidebarCollapsedProvider.notifier).toggle(),
            ),
        ],
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = widget.selected ? colors.textPrimary : colors.textSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? colors.bgActive
                : (_hover ? colors.bgHighlight : Colors.transparent),
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            mainAxisAlignment: widget.collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                widget.selected ? widget.selectedIcon : widget.icon,
                color: fg,
                size: 22,
              ),
              if (!widget.collapsed) ...[
                const SizedBox(width: AppSpacing.s3),
                Text(
                  widget.label,
                  style: AppTypography.body.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatefulWidget {
  const _PlaylistTile({
    required this.title,
    required this.subtitle,
    required this.seed,
    required this.collapsed,
  });

  final String title;
  final String subtitle;
  final int seed;
  final bool collapsed;

  @override
  State<_PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends State<_PlaylistTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hue = (widget.seed * 47) % 360;
    final c1 = HSLColor.fromAHSL(1, hue.toDouble(), 0.5, 0.42).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 35) % 360, 0.55, 0.26).toColor();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.all(AppSpacing.s2),
        decoration: BoxDecoration(
          color: _hover ? colors.bgHighlight : Colors.transparent,
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          mainAxisAlignment: widget.collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: AppRadius.smAll,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c1, c2],
                ),
              ),
              child: Icon(
                Icons.queue_music_rounded,
                size: 18,
                color: colors.onBrand.withValues(alpha: 0.6),
              ),
            ),
            if (!widget.collapsed) ...[
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: context.colors.textSecondary),
    );
  }
}
