import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'state/providers.dart';

/// Root widget: wires the router and the dark/light themes, switching theme
/// mode reactively from [themeModeProvider].
class BiliTuneApp extends ConsumerStatefulWidget {
  const BiliTuneApp({super.key});

  @override
  ConsumerState<BiliTuneApp> createState() => _BiliTuneAppState();
}

class _BiliTuneAppState extends ConsumerState<BiliTuneApp>
    with WindowListener, TrayListener {
  bool _windowsControlsReady = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      unawaited(_initWindowsControls());
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    ref.listen(playbackProvider, (_, next) {
      if (Platform.isWindows) unawaited(_syncTray(next));
    });

    return MaterialApp.router(
      title: 'BiliTune',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return Platform.isWindows ? ExcludeSemantics(child: content) : content;
      },
    );
  }

  Future<void> _initWindowsControls() async {
    await windowManager.setPreventClose(true);
    await trayManager.setIcon('assest/logo.ico');
    await trayManager.setToolTip('BiliTune');
    _windowsControlsReady = true;
    await _syncTray(ref.read(playbackProvider));
  }

  Future<void> _syncTray(PlaybackState playback) async {
    if (!_windowsControlsReady) return;
    final track = playback.track;
    final title = track?.title ?? 'BiliTune';
    await trayManager.setToolTip(
      track == null ? 'BiliTune' : '$title - ${track.artist}',
    );
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(label: title, disabled: true),
          MenuItem.separator(),
          MenuItem(
            key: 'previous',
            label: '上一首',
            onClick: (_) => ref.read(playbackProvider.notifier).previous(),
          ),
          MenuItem(
            key: 'play_pause',
            label: playback.isPlaying ? '暂停' : '播放',
            onClick: (_) =>
                unawaited(ref.read(playbackProvider.notifier).togglePlay()),
          ),
          MenuItem(
            key: 'next',
            label: '下一首',
            onClick: (_) => ref.read(playbackProvider.notifier).next(),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'show',
            label: '显示主窗口',
            onClick: (_) => unawaited(_showWindow()),
          ),
          MenuItem(
            key: 'hide',
            label: '隐藏到托盘',
            onClick: (_) => unawaited(windowManager.hide()),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit',
            label: '退出',
            onClick: (_) => unawaited(_exitApp()),
          ),
        ],
      ),
    );
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exitApp() async {
    await windowManager.setPreventClose(false);
    await trayManager.destroy();
    await windowManager.destroy();
  }

  @override
  Future<void> onWindowClose() async {
    final preventClose = await windowManager.isPreventClose();
    if (!preventClose) return;

    switch (ref.read(windowCloseBehaviorProvider)) {
      case WindowCloseBehavior.minimize:
        await windowManager.minimize();
      case WindowCloseBehavior.tray:
        await windowManager.hide();
      case WindowCloseBehavior.exit:
        await _exitApp();
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }
}
