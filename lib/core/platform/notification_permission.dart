import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class NotificationPermission {
  const NotificationPermission._();

  static const _channel = MethodChannel('com.wep56.bilitune/notifications');

  static Future<void> requestIfNeeded() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('requestPostNotifications');
    } on PlatformException {
      // Playback can still work without the notification permission; Android
      // simply suppresses the foreground media notification until it is granted.
    } on MissingPluginException {
      // Keeps tests and non-standard embedders from failing during startup.
    }
  }
}
