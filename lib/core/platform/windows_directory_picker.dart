import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class WindowsDirectoryPicker {
  WindowsDirectoryPicker._();

  static const _channel = MethodChannel('com.wep56.bilitune/downloads');

  static Future<String?> pickDirectory() async {
    if (!Platform.isWindows) return null;
    try {
      final value = await _channel.invokeMethod<String>('pickDirectory');
      final path = value?.trim();
      return path == null || path.isEmpty ? null : path;
    } on MissingPluginException {
      return null;
    }
  }
}
