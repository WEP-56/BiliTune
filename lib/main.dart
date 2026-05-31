import 'dart:io' show Platform;

import 'package:media_kit/media_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/platform/notification_permission.dart';
import 'core/platform/system_media_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await SystemMediaControls.instance.initialize();
  await NotificationPermission.requestIfNeeded();

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

  runApp(const ProviderScope(child: BiliTuneApp()));
}
