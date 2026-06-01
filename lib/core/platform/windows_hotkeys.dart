import 'dart:io' show Platform;

import 'package:flutter/services.dart';

enum WindowsHotkeyAction { playPause, previousTrack, nextTrack, toggleWindow }

const windowsHotkeyActions = <WindowsHotkeyAction>[
  WindowsHotkeyAction.playPause,
  WindowsHotkeyAction.previousTrack,
  WindowsHotkeyAction.nextTrack,
  WindowsHotkeyAction.toggleWindow,
];

extension WindowsHotkeyActionLabel on WindowsHotkeyAction {
  String get label => switch (this) {
    WindowsHotkeyAction.playPause => '播放 / 暂停',
    WindowsHotkeyAction.previousTrack => '上一首',
    WindowsHotkeyAction.nextTrack => '下一首',
    WindowsHotkeyAction.toggleWindow => '隐藏 / 显示主窗口',
  };

  String get description => switch (this) {
    WindowsHotkeyAction.playPause => '全局控制当前曲目的播放状态',
    WindowsHotkeyAction.previousTrack => '回到上一首或当前曲目开头',
    WindowsHotkeyAction.nextTrack => '播放队列中的下一首',
    WindowsHotkeyAction.toggleWindow => '显示前台窗口，或隐藏到托盘',
  };
}

WindowsHotkeyAction? windowsHotkeyActionFromName(String? value) {
  for (final action in WindowsHotkeyAction.values) {
    if (action.name == value) return action;
  }
  return null;
}

enum HotkeyModifier { control, alt, shift, win }

extension HotkeyModifierLabel on HotkeyModifier {
  String get label => switch (this) {
    HotkeyModifier.control => 'Ctrl',
    HotkeyModifier.alt => 'Alt',
    HotkeyModifier.shift => 'Shift',
    HotkeyModifier.win => 'Win',
  };
}

HotkeyModifier? hotkeyModifierFromName(String? value) {
  for (final modifier in HotkeyModifier.values) {
    if (modifier.name == value) return modifier;
  }
  return null;
}

class WindowsHotkeyBinding {
  const WindowsHotkeyBinding({
    required this.action,
    required this.key,
    this.modifiers = const <HotkeyModifier>{},
  });

  final WindowsHotkeyAction action;
  final String key;
  final Set<HotkeyModifier> modifiers;

  bool get isSet => key.isNotEmpty;

  String get displayLabel {
    if (!isSet) return '未设置';
    final parts = <String>[
      for (final modifier in HotkeyModifier.values)
        if (modifiers.contains(modifier)) modifier.label,
      _keyLabel(key),
    ];
    return parts.join(' + ');
  }

  String get signature {
    final modifierNames = modifiers.map((item) => item.name).toList()..sort();
    return [...modifierNames, key].join('+');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'action': action.name,
      'key': key,
      'modifiers': modifiers.map((item) => item.name).toList(growable: false),
    };
  }

  Map<String, dynamic> toNativeJson() => toJson();

  factory WindowsHotkeyBinding.fromJson(Map<String, dynamic> json) {
    final action = windowsHotkeyActionFromName(json['action']?.toString());
    if (action == null) {
      throw FormatException('Unknown hotkey action: ${json['action']}');
    }
    return WindowsHotkeyBinding(
      action: action,
      key: json['key']?.toString() ?? '',
      modifiers:
          (json['modifiers'] as List?)
              ?.map((item) => hotkeyModifierFromName(item.toString()))
              .whereType<HotkeyModifier>()
              .toSet() ??
          const <HotkeyModifier>{},
    );
  }

  static String _keyLabel(String key) {
    return switch (key) {
      'Space' => 'Space',
      'Enter' => 'Enter',
      'Escape' => 'Esc',
      'Backspace' => 'Backspace',
      'Tab' => 'Tab',
      'ArrowLeft' => 'Left',
      'ArrowRight' => 'Right',
      'ArrowUp' => 'Up',
      'ArrowDown' => 'Down',
      'PageUp' => 'Page Up',
      'PageDown' => 'Page Down',
      'MediaPlayPause' => 'Media Play/Pause',
      'MediaNextTrack' => 'Media Next',
      'MediaPreviousTrack' => 'Media Previous',
      'MediaStop' => 'Media Stop',
      _ => key,
    };
  }
}

WindowsHotkeyBinding? windowsHotkeyFromKeyEvent(
  WindowsHotkeyAction action,
  KeyEvent event,
) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
  if (_isModifierKey(event.logicalKey)) return null;

  final key = _hotkeyToken(event.logicalKey);
  if (key == null) return null;

  final keyboard = HardwareKeyboard.instance;
  return WindowsHotkeyBinding(
    action: action,
    key: key,
    modifiers: <HotkeyModifier>{
      if (keyboard.isControlPressed) HotkeyModifier.control,
      if (keyboard.isAltPressed) HotkeyModifier.alt,
      if (keyboard.isShiftPressed) HotkeyModifier.shift,
      if (keyboard.isMetaPressed) HotkeyModifier.win,
    },
  );
}

bool _isModifierKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.control ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.alt ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.shift ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.meta ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight;
}

String? _hotkeyToken(LogicalKeyboardKey key) {
  final label = key.keyLabel.toUpperCase();
  if (RegExp(r'^[A-Z]$').hasMatch(label)) return label;
  if (RegExp(r'^[0-9]$').hasMatch(label)) return label;
  if (RegExp(r'^F([1-9]|1[0-9]|2[0-4])$').hasMatch(label)) return label;

  if (key == LogicalKeyboardKey.space) return 'Space';
  if (key == LogicalKeyboardKey.enter) return 'Enter';
  if (key == LogicalKeyboardKey.escape) return 'Escape';
  if (key == LogicalKeyboardKey.backspace) return 'Backspace';
  if (key == LogicalKeyboardKey.tab) return 'Tab';
  if (key == LogicalKeyboardKey.arrowLeft) return 'ArrowLeft';
  if (key == LogicalKeyboardKey.arrowRight) return 'ArrowRight';
  if (key == LogicalKeyboardKey.arrowUp) return 'ArrowUp';
  if (key == LogicalKeyboardKey.arrowDown) return 'ArrowDown';
  if (key == LogicalKeyboardKey.home) return 'Home';
  if (key == LogicalKeyboardKey.end) return 'End';
  if (key == LogicalKeyboardKey.pageUp) return 'PageUp';
  if (key == LogicalKeyboardKey.pageDown) return 'PageDown';
  if (key == LogicalKeyboardKey.insert) return 'Insert';
  if (key == LogicalKeyboardKey.delete) return 'Delete';
  if (key == LogicalKeyboardKey.mediaPlayPause) return 'MediaPlayPause';
  if (key == LogicalKeyboardKey.mediaTrackNext) return 'MediaNextTrack';
  if (key == LogicalKeyboardKey.mediaTrackPrevious) {
    return 'MediaPreviousTrack';
  }
  if (key == LogicalKeyboardKey.mediaStop) return 'MediaStop';
  return null;
}

class WindowsHotkeyBridge {
  WindowsHotkeyBridge._();

  static final instance = WindowsHotkeyBridge._();
  static const _channel = MethodChannel('com.wep56.bilitune/hotkeys');

  void setActionHandler(
    Future<void> Function(WindowsHotkeyAction action) onAction,
  ) {
    if (!Platform.isWindows) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onHotkeyPressed') return null;
      final arguments = call.arguments;
      final actionName = arguments is Map
          ? arguments['action']?.toString()
          : arguments?.toString();
      final action = windowsHotkeyActionFromName(actionName);
      if (action != null) await onAction(action);
      return null;
    });
  }

  Future<void> sync(Iterable<WindowsHotkeyBinding> bindings) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('setHotkeys', <String, Object?>{
        'bindings': bindings
            .where((binding) => binding.isSet)
            .map((binding) => binding.toNativeJson())
            .toList(growable: false),
      });
    } on MissingPluginException {
      // The Windows runner owns this channel. Ignoring this keeps tests and
      // unsupported embedders from failing during startup.
    }
  }
}
