import 'dart:io' show Platform;

import 'package:media_kit/media_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/platform/notification_permission.dart';
import 'core/platform/system_media_controls.dart';
import 'core/platform/windows_hotkeys.dart';
import 'data/local/app_local_store.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await SystemMediaControls.instance.initialize();
  await NotificationPermission.requestIfNeeded();
  final bootstrap = await _loadBootstrapState();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 820),
      minimumSize: Size(960, 640),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'BiliTune',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    ProviderScope(
      overrides: [
        playbackBootstrapProvider.overrideWithValue(bootstrap.playback),
        windowsHotkeyBootstrapProvider.overrideWithValue(bootstrap.hotkeys),
      ],
      child: const BiliTuneApp(),
    ),
  );
}

Future<_BootstrapState> _loadBootstrapState() async {
  try {
    final store = AppLocalStore(SharedPreferencesAsync());
    final playback = await store.readPlaybackState();
    final hotkeys = await store.readWindowsHotkeys();
    return _BootstrapState(
      playback: playback == null ? null : PlaybackState.fromJson(playback),
      hotkeys: _decodeWindowsHotkeys(hotkeys),
    );
  } catch (_) {
    return const _BootstrapState();
  }
}

List<WindowsHotkeyBinding> _decodeWindowsHotkeys(
  List<Map<String, dynamic>> raw,
) {
  return raw
      .map((item) {
        try {
          return WindowsHotkeyBinding.fromJson(item);
        } catch (_) {
          return null;
        }
      })
      .whereType<WindowsHotkeyBinding>()
      .where((binding) => binding.isSet)
      .toList(growable: false);
}

class _BootstrapState {
  const _BootstrapState({
    this.playback,
    this.hotkeys = const <WindowsHotkeyBinding>[],
  });

  final PlaybackState? playback;
  final List<WindowsHotkeyBinding> hotkeys;
}
