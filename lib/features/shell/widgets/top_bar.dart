import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../state/providers.dart';
import '../../../shared/widgets/brand_button.dart';

/// Desktop top bar (design doc §6.1): back/forward, theme toggle, account.
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Container(
      height: AppLayout.topBarHeight,
      color: colors.bgBase,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        children: [
          if (collapsed)
            _CircleIcon(
              icon: Icons.menu_rounded,
              onTap: () =>
                  ref.read(sidebarCollapsedProvider.notifier).toggle(),
            ),
          if (collapsed) const SizedBox(width: AppSpacing.s2),
          _CircleIcon(icon: Icons.chevron_left_rounded, onTap: () {}),
          const SizedBox(width: AppSpacing.s2),
          _CircleIcon(icon: Icons.chevron_right_rounded, onTap: () {}),
          const Spacer(),
          _CircleIcon(
            icon: themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: AppSpacing.s2),
          _CircleIcon(icon: Icons.notifications_none_rounded, onTap: () {}),
          const SizedBox(width: AppSpacing.s4),
          BrandButton(
            label: '登录',
            variant: BiliButtonVariant.secondary,
            onTap: () {},
          ),
          const SizedBox(width: AppSpacing.s3),
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.bgActive,
            child: Icon(Icons.person_rounded,
                size: 18, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.bgSurface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: colors.textPrimary),
        ),
      ),
    );
  }
}
