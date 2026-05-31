import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../data/repositories/bili_auth_repository.dart';
import '../../state/providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width >= AppLayout.desktopBreakpoint
        ? AppSpacing.s6
        : AppSpacing.s4;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final closeBehavior = ref.watch(windowCloseBehaviorProvider);
    final auth = ref.watch(authProvider);
    final account = auth.account;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, AppSpacing.s4, pad, AppSpacing.s12),
      children: [
        Text(
          '设置',
          style: AppTypography.titleL.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.s6),
        _Section(
          title: '外观',
          children: [
            _SwitchTile(
              icon: Icons.dark_mode_outlined,
              title: '深色模式',
              subtitle: '关闭后切换为浅色主题',
              value: isDark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            ),
            _NavTile(
              icon: Icons.palette_outlined,
              title: '主题色',
              trailing: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colors.brand,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        _Section(
          title: '播放',
          children: const [
            _NavTile(
              icon: Icons.high_quality_outlined,
              title: '默认音质',
              value: '自动',
            ),
            _NavTile(icon: Icons.speed_rounded, title: '播放倍速', value: '1.0x'),
            _NavTile(
              icon: Icons.equalizer_rounded,
              title: '响度均衡',
              value: '未启用',
            ),
          ],
        ),
        _Section(
          title: '下载',
          children: const [
            _NavTile(
              icon: Icons.audio_file_outlined,
              title: '下载格式',
              value: '原始音频',
            ),
            _NavTile(
              icon: Icons.download_for_offline_outlined,
              title: '同时下载数',
              value: '3',
            ),
          ],
        ),
        if (Platform.isWindows)
          _Section(
            title: 'Windows',
            children: [
              _CloseBehaviorTile(
                value: closeBehavior,
                onChanged: (behavior) => ref
                    .read(windowCloseBehaviorProvider.notifier)
                    .set(behavior),
              ),
            ],
          ),
        _Section(
          title: '账号',
          children: [
            _NavTile(
              icon: account == null
                  ? Icons.account_circle_outlined
                  : Icons.verified_user_outlined,
              title: account?.name ?? '登录 Bilibili 账号',
              value: account == null
                  ? '未登录'
                  : 'MID ${account.mid}${account.isVip ? ' · 大会员' : ''}',
              onTap: () => showAccountDialog(context),
            ),
            if (auth.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  0,
                  AppSpacing.s4,
                  AppSpacing.s3,
                ),
                child: Text(
                  auth.errorMessage!,
                  style: AppTypography.caption.copyWith(color: colors.error),
                ),
              ),
          ],
        ),
        _Section(
          title: '关于',
          children: const [
            _NavTile(
              icon: Icons.info_outline_rounded,
              title: '版本',
              value: 'v0.1.0',
            ),
            _NavTile(icon: Icons.system_update_outlined, title: '检查更新'),
          ],
        ),
      ],
    );
  }
}

void showAccountDialog(BuildContext context) {
  showDialog<void>(context: context, builder: (_) => const AccountDialog());
}

class AccountDialog extends ConsumerWidget {
  const AccountDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);
    final account = auth.account;

    return Dialog(
      backgroundColor: colors.bgElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Bilibili 账号',
                    style: AppTypography.titleM.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              if (account != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colors.bgHighlight,
                      backgroundImage:
                          account.avatarUrl == null ||
                              account.avatarUrl!.isEmpty
                          ? null
                          : NetworkImage(account.avatarUrl!),
                      child:
                          account.avatarUrl == null ||
                              account.avatarUrl!.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              color: colors.textSecondary,
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            account.name,
                            style: AppTypography.titleS.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'MID ${account.mid}${account.isVip ? ' · 大会员' : ''}',
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s5),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('刷新账号'),
                        onPressed: () =>
                            ref.read(authProvider.notifier).refreshAccount(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('退出登录'),
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  '扫码登录适合常规使用；手动 Cookie 适合调试或迁移已有登录态。',
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s5),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text('扫码登录'),
                    onPressed: auth.isLoading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            showDialog<void>(
                              context: context,
                              builder: (_) => const QrLoginDialog(),
                            );
                          },
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cookie_outlined),
                    label: const Text('手动填入 Cookie'),
                    onPressed: auth.isLoading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            showDialog<void>(
                              context: context,
                              builder: (_) => const CookieLoginDialog(),
                            );
                          },
                  ),
                ),
              ],
              if (auth.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  auth.errorMessage!,
                  style: AppTypography.caption.copyWith(color: colors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class QrLoginDialog extends ConsumerStatefulWidget {
  const QrLoginDialog({super.key});

  @override
  ConsumerState<QrLoginDialog> createState() => _QrLoginDialogState();
}

class _QrLoginDialogState extends ConsumerState<QrLoginDialog> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(authProvider.notifier).createQrLoginSession();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        ref.read(authProvider.notifier).pollQrLogin();
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);
    final session = auth.qrSession;
    final status = auth.qrStatus;

    if (status == QrLoginStatus.confirmed) {
      _pollTimer?.cancel();
    }

    return Dialog(
      backgroundColor: colors.bgElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '扫码登录',
                    style: AppTypography.titleM.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              if (auth.isLoading || session == null)
                const SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: QrImageView(
                    data: session.url,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                _statusText(status),
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s3),
                Text(
                  auth.errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.s5),
              Row(
                children: [
                  if (status == QrLoginStatus.expired)
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重新生成'),
                        onPressed: () {
                          ref
                              .read(authProvider.notifier)
                              .createQrLoginSession();
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          status == QrLoginStatus.confirmed ? '完成' : '取消',
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(QrLoginStatus? status) {
    return switch (status) {
      QrLoginStatus.scanned => '已扫码，请在 Bilibili 客户端确认登录',
      QrLoginStatus.confirmed => '登录成功',
      QrLoginStatus.expired => '二维码已过期',
      QrLoginStatus.failed => '登录失败',
      _ => '请使用 Bilibili 客户端扫码',
    };
  }
}

class CookieLoginDialog extends ConsumerStatefulWidget {
  const CookieLoginDialog({super.key});

  @override
  ConsumerState<CookieLoginDialog> createState() => _CookieLoginDialogState();
}

class _CookieLoginDialogState extends ConsumerState<CookieLoginDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);

    return Dialog(
      backgroundColor: colors.bgElevated,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '手动 Cookie 登录',
                    style: AppTypography.titleM.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                '粘贴包含 SESSDATA、bili_jct、DedeUserID 的 Cookie 字符串。',
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextField(
                controller: _controller,
                minLines: 5,
                maxLines: 8,
                style: AppTypography.body.copyWith(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'SESSDATA=...; bili_jct=...; DedeUserID=...',
                  hintStyle: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                  filled: true,
                  fillColor: colors.bgHighlight,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s3),
                Text(
                  auth.errorMessage!,
                  style: AppTypography.caption.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.s5),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: FilledButton(
                      onPressed: auth.isLoading ? null : _save,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存并登录'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    await ref
        .read(authProvider.notifier)
        .saveManualCookie(_controller.text.trim());
    if (!mounted) return;
    final signedIn = ref.read(authProvider).isSignedIn;
    if (signedIn) Navigator.of(context).pop();
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
            bottom: AppSpacing.s2,
            top: AppSpacing.s2,
          ),
          child: Text(
            title,
            style: AppTypography.overline.copyWith(color: colors.textTertiary),
          ),
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(icon, color: colors.textSecondary),
      title: Text(
        title,
        style: AppTypography.body.copyWith(color: colors.textPrimary),
      ),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                Text(
                  value!,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              const SizedBox(width: AppSpacing.s2),
              Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
      onTap: onTap,
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
      title: Text(
        title,
        style: AppTypography.body.copyWith(color: colors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: colors.textSecondary),
      ),
      value: value,
      activeThumbColor: colors.brand,
      onChanged: onChanged,
    );
  }
}

class _CloseBehaviorTile extends StatelessWidget {
  const _CloseBehaviorTile({required this.value, required this.onChanged});

  final WindowCloseBehavior value;
  final ValueChanged<WindowCloseBehavior> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(
        Icons.close_fullscreen_rounded,
        color: colors.textSecondary,
      ),
      title: Text(
        '关闭窗口时',
        style: AppTypography.body.copyWith(color: colors.textPrimary),
      ),
      subtitle: Text(
        '控制点击右上角关闭按钮后的行为',
        style: AppTypography.caption.copyWith(color: colors.textSecondary),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<WindowCloseBehavior>(
          value: value,
          dropdownColor: colors.bgElevated,
          borderRadius: AppRadius.mdAll,
          style: AppTypography.body.copyWith(color: colors.textPrimary),
          items: [
            for (final behavior in WindowCloseBehavior.values)
              DropdownMenuItem(value: behavior, child: Text(behavior.label)),
          ],
          onChanged: (behavior) {
            if (behavior != null) onChanged(behavior);
          },
        ),
      ),
    );
  }
}
