import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/platform/windows_directory_picker.dart';
import '../../core/platform/windows_hotkeys.dart';
import '../../data/models/models.dart';
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
    final playbackSettings = ref.watch(playbackSettingsProvider);
    final downloadSettings = ref.watch(downloadSettingsProvider);
    final downloadDirectory = ref.watch(downloadDirectoryProvider);
    final cacheState = ref.watch(cacheProvider);
    final windowsStartup = Platform.isWindows
        ? ref.watch(windowsStartupProvider)
        : const WindowsStartupState();
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
          children: [
            _DropdownTile<AudioQualityPreference>(
              icon: Icons.high_quality_outlined,
              title: '默认音质',
              subtitle: playbackSettings.audioQuality.description,
              value: playbackSettings.audioQuality,
              values: AudioQualityPreference.values,
              labelFor: (value) => value.label,
              onChanged: (value) => ref
                  .read(playbackSettingsProvider.notifier)
                  .setAudioQuality(value),
            ),
            _DropdownTile<double>(
              icon: Icons.speed_rounded,
              title: '播放倍速',
              subtitle: '会立即应用到当前播放器',
              value: playbackSettings.playbackSpeed,
              values: const <double>[0.75, 1.0, 1.25, 1.5, 2.0],
              labelFor: _speedLabel,
              onChanged: (value) => ref
                  .read(playbackSettingsProvider.notifier)
                  .setPlaybackSpeed(value),
            ),
            _SwitchTile(
              icon: Icons.equalizer_rounded,
              title: '响度均衡',
              subtitle: '使用播放器音频滤镜拉齐不同曲目的响度',
              value: playbackSettings.loudnessNormalization,
              onChanged: (value) => ref
                  .read(playbackSettingsProvider.notifier)
                  .setLoudnessNormalization(value),
            ),
            _DropdownTile<LyricsSourcePreference>(
              icon: Icons.lyrics_outlined,
              title: '歌词来源优先级',
              subtitle: playbackSettings.lyricsSourcePreference.description,
              value: playbackSettings.lyricsSourcePreference,
              values: LyricsSourcePreference.values,
              labelFor: (value) => value.label,
              onChanged: (value) => ref
                  .read(playbackSettingsProvider.notifier)
                  .setLyricsSourcePreference(value),
            ),
            _DropdownTile<int>(
              icon: Icons.history_rounded,
              title: '播放历史记录上限',
              subtitle: '超过上限时会裁剪本地播放历史',
              value: playbackSettings.historyLimit,
              values: const <int>[20, 50, 100, 200, 500],
              labelFor: (value) => '$value 条',
              onChanged: (value) => ref
                  .read(playbackSettingsProvider.notifier)
                  .setHistoryLimit(value),
            ),
          ],
        ),
        _Section(
          title: '下载',
          children: [
            _DropdownTile<String>(
              icon: Icons.audio_file_outlined,
              title: '下载格式',
              subtitle: '保存 Bilibili 返回的原始音频流',
              value: downloadSettings.outputFileType,
              values: const <String>['audio'],
              labelFor: _downloadFormatLabel,
              onChanged: (value) => ref
                  .read(downloadSettingsProvider.notifier)
                  .setOutputFileType(value),
            ),
            _DropdownTile<int>(
              icon: Icons.download_for_offline_outlined,
              title: '同时下载数',
              subtitle: '超过上限的任务会保持等待',
              value: downloadSettings.maxConcurrent,
              values: const <int>[1, 2, 3, 5],
              labelFor: (value) => '$value',
              onChanged: (value) => ref
                  .read(downloadSettingsProvider.notifier)
                  .setMaxConcurrent(value),
            ),
            _NavTile(
              icon: Icons.folder_open_outlined,
              title: '本地音乐目录',
              value: downloadDirectory.when(
                data: _compactPath,
                loading: () => '读取中',
                error: (_, _) => '读取失败',
              ),
              onTap: () => _openDownloadDirectoryDialog(context, ref),
            ),
          ],
        ),
        _Section(
          title: '缓存',
          children: [
            _NavTile(
              icon: Icons.storage_outlined,
              title: '缓存大小',
              value: cacheState.label,
              onTap: () => ref.read(cacheProvider.notifier).refresh(),
            ),
            _NavTile(
              icon: Icons.delete_sweep_outlined,
              title: '清理缓存',
              value: cacheState.isLoading ? '处理中' : '立即清理',
              onTap: cacheState.isLoading
                  ? null
                  : () async {
                      final confirmed = await _confirmClearCache(
                        context,
                        cacheState,
                      );
                      if (confirmed != true) return;
                      await ref.read(cacheProvider.notifier).clear();
                    },
            ),
            if (cacheState.errorMessage != null)
              _SectionNote(text: '缓存读取失败：${cacheState.errorMessage}'),
          ],
        ),
        if (Platform.isWindows)
          _Section(
            title: 'Windows',
            children: [
              const _SectionNote(text: '全局快捷键默认不绑定，需手动录制后才会在后台生效。'),
              _SwitchTile(
                icon: Icons.bolt_outlined,
                title: '开机自启动',
                subtitle: windowsStartup.isLoading
                    ? '正在读取 Windows 启动项'
                    : windowsStartup.errorMessage ??
                          '登录 Windows 后自动启动 BiliTune',
                value: windowsStartup.enabled,
                onChanged: windowsStartup.isLoading
                    ? null
                    : (value) => ref
                          .read(windowsStartupProvider.notifier)
                          .setEnabled(value),
              ),
              _CloseBehaviorTile(
                value: closeBehavior,
                onChanged: (behavior) => ref
                    .read(windowCloseBehaviorProvider.notifier)
                    .set(behavior),
              ),
              for (final action in windowsHotkeyActions)
                _WindowsHotkeyTile(
                  action: action,
                  binding: _bindingFor(
                    ref.watch(windowsHotkeysProvider),
                    action,
                  ),
                  onRecord: () async {
                    final binding = await _recordWindowsHotkey(context, action);
                    if (binding == null) return;
                    await ref
                        .read(windowsHotkeysProvider.notifier)
                        .setBinding(binding);
                  },
                  onClear: () => ref
                      .read(windowsHotkeysProvider.notifier)
                      .clearBinding(action),
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

WindowsHotkeyBinding? _bindingFor(
  List<WindowsHotkeyBinding> bindings,
  WindowsHotkeyAction action,
) {
  for (final binding in bindings) {
    if (binding.action == action) return binding;
  }
  return null;
}

Future<WindowsHotkeyBinding?> _recordWindowsHotkey(
  BuildContext context,
  WindowsHotkeyAction action,
) {
  return showDialog<WindowsHotkeyBinding>(
    context: context,
    builder: (_) => _WindowsHotkeyRecordDialog(action: action),
  );
}

String _speedLabel(double value) =>
    '${value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}x';

String _downloadFormatLabel(String value) => switch (value) {
  'audio' => '原始音频',
  _ => value,
};

String _compactPath(String path) {
  final normalized = path.trim();
  if (normalized.length <= 42) return normalized;
  return '...${normalized.substring(normalized.length - 39)}';
}

Future<void> _openDownloadDirectoryDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final colors = context.colors;
  final settings = ref.read(downloadSettingsProvider);
  final currentPath = await ref.read(downloadDirectoryProvider.future);
  if (!context.mounted) return;
  if (Platform.isWindows) {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.bgElevated,
          title: Text(
            '本地音乐目录',
            style: AppTypography.titleM.copyWith(color: colors.textPrimary),
          ),
          content: Text(
            currentPath,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          actions: [
            if (settings.directoryPath != null)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop('');
                  await ref
                      .read(downloadSettingsProvider.notifier)
                      .setDirectoryPath(null);
                },
                child: const Text('恢复默认'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final selectedPath =
                    await WindowsDirectoryPicker.pickDirectory();
                if (selectedPath != null && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(selectedPath);
                }
              },
              child: const Text('选择目录'),
            ),
          ],
        );
      },
    );
    if (selected == null || selected.isEmpty) return;
    await ref
        .read(downloadSettingsProvider.notifier)
        .setDirectoryPath(selected);
    return;
  }

  if (Platform.isAndroid) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.bgElevated,
          title: Text(
            '本地音乐目录',
            style: AppTypography.titleM.copyWith(color: colors.textPrimary),
          ),
          content: Text(
            'Android 使用应用专属外部目录保存下载文件，不需要额外存储权限。\n\n$currentPath',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: colors.bgElevated,
        title: Text(
          '本地音乐目录',
          style: AppTypography.titleM.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          currentPath,
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}

Future<bool?> _confirmClearCache(BuildContext context, CacheState cacheState) {
  final colors = context.colors;
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: colors.bgElevated,
        title: Text(
          '清理缓存',
          style: AppTypography.titleM.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          '将清理播放器磁盘缓存，当前占用 ${cacheState.label}。',
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清理'),
          ),
        ],
      );
    },
  );
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
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.s2),
                Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
              ],
            ],
          ),
      onTap: onTap,
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(icon, color: colors.textSecondary),
      title: Text(
        title,
        style: AppTypography.body.copyWith(color: colors.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption.copyWith(color: colors.textSecondary),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: colors.bgElevated,
          borderRadius: AppRadius.mdAll,
          style: AppTypography.body.copyWith(color: colors.textPrimary),
          items: [
            for (final item in values)
              DropdownMenuItem<T>(value: item, child: Text(labelFor(item))),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

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

class _SectionNote extends StatelessWidget {
  const _SectionNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s4,
        AppSpacing.s1,
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

class _WindowsHotkeyTile extends StatelessWidget {
  const _WindowsHotkeyTile({
    required this.action,
    required this.binding,
    required this.onRecord,
    required this.onClear,
  });

  final WindowsHotkeyAction action;
  final WindowsHotkeyBinding? binding;
  final VoidCallback onRecord;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(_iconFor(action), color: colors.textSecondary),
      title: Text(
        action.label,
        style: AppTypography.body.copyWith(color: colors.textPrimary),
      ),
      subtitle: Text(
        action.description,
        style: AppTypography.caption.copyWith(color: colors.textSecondary),
      ),
      trailing: SizedBox(
        width: 240,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                binding?.displayLabel ?? '未设置',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: binding == null
                      ? colors.textTertiary
                      : colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s1),
            Tooltip(
              message: '录制快捷键',
              child: IconButton(
                icon: const Icon(Icons.keyboard_alt_outlined),
                color: colors.textSecondary,
                visualDensity: VisualDensity.compact,
                onPressed: onRecord,
              ),
            ),
            Tooltip(
              message: '清除绑定',
              child: IconButton(
                icon: const Icon(Icons.close_rounded),
                color: colors.textSecondary,
                visualDensity: VisualDensity.compact,
                onPressed: binding == null ? null : onClear,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(WindowsHotkeyAction action) {
  return switch (action) {
    WindowsHotkeyAction.playPause => Icons.play_circle_outline_rounded,
    WindowsHotkeyAction.previousTrack => Icons.skip_previous_rounded,
    WindowsHotkeyAction.nextTrack => Icons.skip_next_rounded,
    WindowsHotkeyAction.toggleWindow => Icons.window_rounded,
  };
}

class _WindowsHotkeyRecordDialog extends StatefulWidget {
  const _WindowsHotkeyRecordDialog({required this.action});

  final WindowsHotkeyAction action;

  @override
  State<_WindowsHotkeyRecordDialog> createState() =>
      _WindowsHotkeyRecordDialogState();
}

class _WindowsHotkeyRecordDialogState
    extends State<_WindowsHotkeyRecordDialog> {
  final _focusNode = FocusNode();
  WindowsHotkeyBinding? _binding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: colors.bgElevated,
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.action.label,
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
                  '按下你想要的组合键，录制完成后点保存。',
                  style: AppTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.bgHighlight,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Text(
                    _binding?.displayLabel ?? '等待录制...',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleS.copyWith(
                      color: _binding == null
                          ? colors.textTertiary
                          : colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: FilledButton(
                        onPressed: _binding == null
                            ? null
                            : () => Navigator.of(context).pop(_binding),
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    final binding = windowsHotkeyFromKeyEvent(widget.action, event);
    if (binding == null) return;
    setState(() => _binding = binding);
  }
}
