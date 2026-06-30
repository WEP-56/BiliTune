import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../core/platform/windows_directory_picker.dart';
import '../../core/platform/windows_hotkeys.dart';
import '../../shared/widgets/app_toast.dart';
import 'web_login_dialog.dart';
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
    final packageInfoAsync = ref.watch(packageInfoProvider);
    final updateState = ref.watch(appUpdateProvider);
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
            _DropdownTile<ImmersiveThemePreference>(
              icon: Icons.fullscreen_rounded,
              title: '沉浸模式默认主题',
              subtitle: playbackSettings.immersiveDefaultTheme.description,
              value: playbackSettings.immersiveDefaultTheme,
              values: ImmersiveThemePreference.values,
              labelFor: (value) => value.label,
              onChanged: (value) => ref
                  .read(playbackSettingsProvider.notifier)
                  .setImmersiveDefaultTheme(value),
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
          children: [
            _NavTile(
              icon: Icons.info_outline_rounded,
              title: '版本',
              value: packageInfoAsync.when(
                data: _formatVersionLabel,
                loading: () => '读取中...',
                error: (_, _) => '未知',
              ),
              onTap: () => _showAboutDialog(context, packageInfoAsync),
            ),
            _NavTile(
              icon: Icons.system_update_outlined,
              title: '检查更新',
              value: updateState.label,
              onTap: updateState.isChecking
                  ? null
                  : () async => _checkAndHandleUpdate(context, ref),
            ),
            if (updateState.errorMessage != null)
              _SectionNote(text: '更新检查失败：${updateState.errorMessage}'),
          ],
        ),
      ],
    );
  }
}

void showAccountDialog(BuildContext context) {
  showDialog<void>(context: context, builder: (_) => const AccountDialog());
}

const _githubRepositoryUrl = 'https://github.com/WEP-56/BiliTune';

String _formatVersionLabel(PackageInfo info) {
  final version = info.version.trim().isEmpty ? '0.0.0' : info.version.trim();
  final build = info.buildNumber.trim();
  if (build.isEmpty || build == '0') return 'v$version';
  return 'v$version+$build';
}

Future<void> _showAboutDialog(
  BuildContext context,
  AsyncValue<PackageInfo> packageInfoAsync,
) {
  final colors = context.colors;
  final versionLabel = packageInfoAsync.maybeWhen(
    data: _formatVersionLabel,
    orElse: () => '读取中...',
  );

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: colors.bgElevated,
        title: Text(
          '关于 BiliTune',
          style: AppTypography.titleM.copyWith(color: colors.textPrimary),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前版本：$versionLabel',
                style: AppTypography.body.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                '免责声明',
                style: AppTypography.titleS.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'BiliTune 是基于公开网络服务实现的第三方音乐客户端，与 Bilibili 官方无从属、授权或背书关系。请遵守相关平台协议与所在地法律法规使用。',
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'GitHub 仓库',
                style: AppTypography.titleS.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.s2),
              SelectableText(
                _githubRepositoryUrl,
                style: AppTypography.body.copyWith(color: colors.accent),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('打开仓库'),
            onPressed: () async {
              final opened = await launchUrl(
                Uri.parse(_githubRepositoryUrl),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && context.mounted) {
                showAppToast(
                  context,
                  message: '无法打开 GitHub 仓库',
                  icon: Icons.error_outline_rounded,
                  accentColor: colors.error,
                );
              }
            },
          ),
        ],
      );
    },
  );
}

Future<void> _checkAndHandleUpdate(BuildContext context, WidgetRef ref) async {
  final colors = context.colors;
  final result = await ref.read(appUpdateProvider.notifier).checkForUpdate();
  if (!context.mounted) return;

  if (result == null) {
    final error = ref.read(appUpdateProvider).errorMessage ?? '检查更新失败';
    showAppToast(
      context,
      message: error,
      icon: Icons.error_outline_rounded,
      accentColor: colors.error,
    );
    return;
  }

  if (!result.hasUpdate) {
    showAppToast(
      context,
      message: '已经是最新版本',
      icon: Icons.check_circle_outline_rounded,
      accentColor: colors.success,
    );
    return;
  }

  if (result.installerAsset == null) {
    showAppToast(
      context,
      message: '发现 ${result.latestRelease.tagName}，但没有适合当前平台的安装包',
      icon: Icons.warning_amber_rounded,
      accentColor: colors.warning,
    );
    return;
  }

  final confirmed = await _confirmInstallUpdate(context, result);
  if (confirmed != true || !context.mounted) return;
  await _downloadAndInstallUpdate(context, ref, result);
}

Future<bool?> _confirmInstallUpdate(
  BuildContext context,
  UpdateCheckResult result,
) {
  final colors = context.colors;
  final release = result.latestRelease;
  final asset = result.installerAsset;
  final notes = release.body.trim().isEmpty ? '暂无更新说明。' : release.body.trim();
  final assetLabel = asset == null
      ? '当前平台暂无安装包'
      : '${asset.name} · ${Format.bytes(asset.sizeBytes)}';

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: colors.bgElevated,
        title: Text(
          '发现新版本 ${release.tagName}',
          style: AppTypography.titleM.copyWith(color: colors.textPrimary),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前版本：${_formatVersionLabel(result.currentVersion)}',
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                '安装包：$assetLabel',
                style: AppTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: SelectableText(
                    notes,
                    style: AppTypography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('下载并安装'),
          ),
        ],
      );
    },
  );
}

Future<void> _downloadAndInstallUpdate(
  BuildContext context,
  WidgetRef ref,
  UpdateCheckResult result,
) async {
  final colors = context.colors;
  final updateNotifier = ref.read(appUpdateProvider.notifier);

  if (Platform.isAndroid && !await updateNotifier.canInstallApk()) {
    if (!context.mounted) return;
    final openSettings = await _confirmAndroidInstallPermission(context);
    if (openSettings == true) {
      await updateNotifier.openInstallSettings();
      if (context.mounted) {
        showAppToast(
          context,
          message: '允许安装未知应用后，请回到 BiliTune 重新下载安装',
          icon: Icons.info_outline_rounded,
          accentColor: colors.info,
          duration: const Duration(seconds: 5),
        );
      }
    }
    return;
  }

  if (!context.mounted) return;
  var progressVisible = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BlockingProgressDialog(
      title: '下载更新',
      message: '正在下载 ${result.installerAsset?.name ?? '安装包'}',
    ),
  );

  try {
    final file = await updateNotifier.downloadInstaller(result.latestRelease);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      progressVisible = false;
    }

    final launched = await updateNotifier.launchInstaller(file.path);
    if (!context.mounted) return;
    showAppToast(
      context,
      message: launched ? '已打开系统安装界面' : '无法打开安装包',
      icon: launched
          ? Icons.system_update_alt_rounded
          : Icons.error_outline_rounded,
      accentColor: launched ? colors.success : colors.error,
    );
  } catch (error) {
    if (!context.mounted) return;
    if (progressVisible) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    showAppToast(
      context,
      message: '更新安装失败：$error',
      icon: Icons.error_outline_rounded,
      accentColor: colors.error,
      duration: const Duration(seconds: 5),
    );
  }
}

Future<bool?> _confirmAndroidInstallPermission(BuildContext context) {
  final colors = context.colors;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: colors.bgElevated,
        title: Text(
          '需要安装权限',
          style: AppTypography.titleM.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Android 需要允许 BiliTune 安装未知来源应用。开启后回到 BiliTune，再重新点击检查更新并安装。',
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去开启'),
          ),
        ],
      );
    },
  );
}

class _BlockingProgressDialog extends StatelessWidget {
  const _BlockingProgressDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      backgroundColor: colors.bgElevated,
      title: Text(
        title,
        style: AppTypography.titleM.copyWith(color: colors.textPrimary),
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.s4),
          Flexible(
            child: Text(
              message,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
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
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.language_rounded),
                    label: const Text('网页登录（短信 / 密码）'),
                    onPressed: auth.isLoading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            showDialog<void>(
                              context: context,
                              builder: (_) => const WebLoginDialog(),
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
