import 'dart:io' show File, Platform, Process, ProcessStartMode, exit;

import 'package:flutter/services.dart';

class AppInstaller {
  AppInstaller._();

  static const _channel = MethodChannel('com.wep56.bilitune/update');

  static Future<bool> canInstallApk() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('canInstallApk') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> openInstallSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on MissingPluginException {
      // No-op for tests and embedders without the Android bridge.
    }
  }

  static Future<bool> launchInstaller(String path) async {
    if (Platform.isWindows) {
      final file = File(path);
      final lowerPath = file.path.toLowerCase();
      if (lowerPath.endsWith('.msi')) {
        await Process.start(
          'msiexec.exe',
          <String>['/i', file.path],
          mode: ProcessStartMode.detached,
        );
      } else {
        await Process.start(
          file.path,
          const <String>[],
          mode: ProcessStartMode.detached,
        );
      }
      exit(0);
    }

    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('installApk', <String, String>{
            'path': path,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
