import 'dart:io' show Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/settings/settings_page.dart';
import '../../../state/providers.dart';

/// Desktop top bar (design doc §6.1): navigation, account, theme, notifications.
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final themeMode = ref.watch(themeModeProvider);
    final auth = ref.watch(authProvider);
    final account = auth.account;

    final bar = Container(
      height: AppLayout.topBarHeight,
      color: colors.bgBase,
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: Platform.isWindows ? 0 : AppSpacing.s4,
      ),
      child: Row(
        children: [
          if (collapsed)
            _CircleIcon(
              icon: Icons.menu_rounded,
              onTap: () => ref.read(sidebarCollapsedProvider.notifier).toggle(),
            ),
          if (collapsed) const SizedBox(width: AppSpacing.s2),
          _CircleIcon(icon: Icons.chevron_left_rounded, onTap: () {}),
          const SizedBox(width: AppSpacing.s2),
          _CircleIcon(icon: Icons.chevron_right_rounded, onTap: () {}),
          Expanded(
            child: Platform.isWindows
                ? ExcludeSemantics(child: DragToMoveArea(child: Container()))
                : const SizedBox.shrink(),
          ),
          _AccountPill(
            label: account?.name ?? (auth.isSignedIn ? '已登录' : '登录'),
            isSignedIn: auth.isSignedIn,
            isLoading: auth.isLoading,
            onTap: auth.isSignedIn
                ? () => ref.read(authProvider.notifier).logout()
                : () => showAccountDialog(context),
          ),
          const SizedBox(width: AppSpacing.s2),
          _AvatarButton(
            imageUrl: account?.avatarUrl,
            onTap: () => showAccountDialog(context),
          ),
          const SizedBox(width: AppSpacing.s4),
          _CircleIcon(
            icon: themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: AppSpacing.s2),
          _CircleIcon(icon: Icons.notifications_none_rounded, onTap: () {}),
          if (Platform.isWindows) ...[
            const SizedBox(width: AppSpacing.s3),
            const _WindowControls(),
          ],
        ],
      ),
    );

    return bar;
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

class _AccountPill extends StatelessWidget {
  const _AccountPill({
    required this.label,
    required this.isSignedIn,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isSignedIn;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: isSignedIn ? '点击退出登录' : '登录 Bilibili',
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: isLoading ? null : onTap,
          child: Container(
            height: 36,
            constraints: const BoxConstraints(minWidth: 76, maxWidth: 148),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
            decoration: BoxDecoration(
              border: Border.all(color: colors.textSecondary),
              borderRadius: AppRadius.pillAll,
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textPrimary,
                    ),
                  )
                : Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.imageUrl, required this.onTap});

  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = _normalizeImageUrl(imageUrl);
    return Material(
      color: colors.bgSurface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: url == null
              ? Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: colors.textSecondary,
                )
              : Image(
                  image: CachedNetworkImageProvider(url),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
        ),
      ),
    );
  }

  String? _normalizeImageUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('http://')) {
      return value.replaceFirst('http://', 'https://');
    }
    return value;
  }
}

class _WindowControls extends StatelessWidget {
  const _WindowControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WindowButton(
          icon: Icons.remove_rounded,
          onTap: () => windowManager.minimize(),
        ),
        _WindowButton(
          icon: Icons.crop_square_rounded,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.restore();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _WindowButton(
          icon: Icons.close_rounded,
          danger: true,
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = _hover
        ? (widget.danger ? colors.error : colors.bgSurface)
        : Colors.transparent;
    final fg = _hover && widget.danger ? Colors.white : colors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          width: 42,
          height: AppLayout.topBarHeight,
          color: bg,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: fg),
        ),
      ),
    );
  }
}
