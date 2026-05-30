import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../state/providers.dart';

/// Settings page (design doc §6.3). M0 wires the dark/light theme switch to a
/// real provider; other rows are placeholders for later milestones.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final pad =
        width >= AppLayout.desktopBreakpoint ? AppSpacing.s6 : AppSpacing.s4;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        Text('设置',
            style: AppTypography.titleL.copyWith(color: colors.textPrimary)),
        const SizedBox(height: AppSpacing.s6),
        _Section(title: '外观', children: [
          _SwitchTile(
            icon: Icons.dark_mode_outlined,
            title: '深色模式',
            subtitle: '关闭后跟随浅色主题',
            value: isDark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
          _NavTile(
            icon: Icons.palette_outlined,
            title: '主题色',
            trailing: Container(
              width: 20,
              height: 20,
              decoration:
                  BoxDecoration(color: colors.brand, shape: BoxShape.circle),
            ),
          ),
        ]),
        _Section(title: '播放', children: const [
          _NavTile(
              icon: Icons.high_quality_outlined,
              title: '默认音质',
              value: '320kbps'),
          _NavTile(icon: Icons.speed_rounded, title: '播放倍速', value: '1.0x'),
          _NavTile(
              icon: Icons.equalizer_rounded, title: '响度均衡', value: '关闭'),
        ]),
        _Section(title: '下载', children: const [
          _NavTile(
              icon: Icons.audio_file_outlined, title: '下载格式', value: 'FLAC'),
          _NavTile(
              icon: Icons.download_for_offline_outlined,
              title: '同时下载数',
              value: '3'),
        ]),
        _Section(title: '账号', children: const [
          _NavTile(
              icon: Icons.account_circle_outlined,
              title: '登录 Bilibili 账号',
              value: '未登录'),
        ]),
        _Section(title: '关于', children: const [
          _NavTile(icon: Icons.info_outline_rounded, title: '版本', value: 'v0.1.0 (M0)'),
          _NavTile(icon: Icons.system_update_outlined, title: '检查更新'),
        ]),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              bottom: AppSpacing.s2, top: AppSpacing.s2),
          child: Text(title,
              style: AppTypography.overline
                  .copyWith(color: colors.textTertiary)),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: AppRadius.mdAll,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
        const SizedBox(height: AppSpacing.s6),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(icon, color: colors.textSecondary),
      title: Text(title,
          style: AppTypography.body.copyWith(color: colors.textPrimary)),
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                Text(value!,
                    style: AppTypography.caption
                        .copyWith(color: colors.textSecondary)),
              const SizedBox(width: AppSpacing.s2),
              Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
      onTap: () {},
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SwitchListTile(
      secondary: Icon(icon, color: colors.textSecondary),
      title: Text(title,
          style: AppTypography.body.copyWith(color: colors.textPrimary)),
      subtitle: Text(subtitle,
          style:
              AppTypography.caption.copyWith(color: colors.textSecondary)),
      value: value,
      activeThumbColor: colors.brand,
      onChanged: onChanged,
    );
  }
}
