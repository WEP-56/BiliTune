import 'dart:io' show Platform, Process;

class WindowsStartupManager {
  WindowsStartupManager._();

  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'BiliTune';

  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run('reg', [
        'query',
        _runKey,
        '/v',
        _valueName,
      ]);
      if (result.exitCode != 0) return false;
      final output = '${result.stdout}\n${result.stderr}';
      return output.contains(_valueName) &&
          output.toLowerCase().contains(
            Platform.resolvedExecutable.toLowerCase(),
          );
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isWindows) return;
    final executable = Platform.resolvedExecutable;
    if (executable.isEmpty) return;

    if (enabled) {
      final result = await Process.run('reg', [
        'add',
        _runKey,
        '/v',
        _valueName,
        '/t',
        'REG_SZ',
        '/d',
        '"$executable"',
        '/f',
      ]);
      if (result.exitCode != 0) {
        throw StateError(
          '${result.stderr}'.trim().isEmpty
              ? 'Failed to enable auto-start.'
              : result.stderr.toString().trim(),
        );
      }
      return;
    }

    final result = await Process.run('reg', [
      'delete',
      _runKey,
      '/v',
      _valueName,
      '/f',
    ]);
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      if (stderr.isNotEmpty && !stderr.contains('The system was unable')) {
        throw StateError(stderr);
      }
    }
  }
}
