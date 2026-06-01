import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class AppLocalStore {
  AppLocalStore(this._prefs);

  static const _themeModeKey = 'settings.theme_mode';
  static const _windowCloseBehaviorKey = 'settings.window_close_behavior';
  static const _playbackStateKey = 'playback.state';
  static const _playbackHistoryKey = 'playback.history';
  static const _searchHistoryKey = 'search.history';
  static const _downloadTasksKey = 'downloads.tasks';
  static const _windowsHotkeysKey = 'settings.windows_hotkeys';
  static const _hiddenFolderIdsKey = 'library.hidden_folder_ids';

  final SharedPreferencesAsync _prefs;

  Future<String?> readThemeMode() => _prefs.getString(_themeModeKey);

  Future<void> saveThemeMode(String value) =>
      _prefs.setString(_themeModeKey, value);

  Future<String?> readWindowCloseBehavior() =>
      _prefs.getString(_windowCloseBehaviorKey);

  Future<void> saveWindowCloseBehavior(String value) =>
      _prefs.setString(_windowCloseBehaviorKey, value);

  Future<Map<String, dynamic>?> readPlaybackState() async {
    final raw = await _prefs.getString(_playbackStateKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      await _prefs.remove(_playbackStateKey);
    }
    return null;
  }

  Future<void> savePlaybackState(Map<String, dynamic> value) =>
      _prefs.setString(_playbackStateKey, jsonEncode(value));

  Future<List<Track>> readPlaybackHistory() async {
    final raw = await _prefs.getString(_playbackHistoryKey);
    if (raw == null || raw.isEmpty) return const <Track>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
          .where((track) => track.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      await _prefs.remove(_playbackHistoryKey);
      return const <Track>[];
    }
  }

  Future<void> savePlaybackHistory(List<Track> history) => _prefs.setString(
    _playbackHistoryKey,
    jsonEncode(history.map((track) => track.toJson()).toList(growable: false)),
  );

  Future<List<String>> readSearchHistory() async {
    final raw = await _prefs.getString(_searchHistoryKey);
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => item.toString()).toList(growable: false);
    } catch (_) {
      await _prefs.remove(_searchHistoryKey);
      return const <String>[];
    }
  }

  Future<void> saveSearchHistory(List<String> history) =>
      _prefs.setString(_searchHistoryKey, jsonEncode(history));

  Future<List<DownloadTask>> readDownloadTasks() async {
    final raw = await _prefs.getString(_downloadTasksKey);
    if (raw == null || raw.isEmpty) return const <DownloadTask>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((item) => DownloadTask.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      await _prefs.remove(_downloadTasksKey);
      return const <DownloadTask>[];
    }
  }

  Future<void> saveDownloadTasks(List<DownloadTask> tasks) => _prefs.setString(
    _downloadTasksKey,
    jsonEncode(tasks.map((task) => task.toJson()).toList(growable: false)),
  );

  Future<List<Map<String, dynamic>>> readWindowsHotkeys() async {
    final raw = await _prefs.getString(_windowsHotkeysKey);
    if (raw == null || raw.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    } catch (_) {
      await _prefs.remove(_windowsHotkeysKey);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> saveWindowsHotkeys(List<Map<String, dynamic>> bindings) =>
      _prefs.setString(_windowsHotkeysKey, jsonEncode(bindings));

  Future<List<int>> readHiddenFolderIds() async {
    final raw = await _prefs.getString(_hiddenFolderIdsKey);
    if (raw == null || raw.isEmpty) return const <int>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((item) {
            if (item is num) return item.toInt();
            return int.tryParse(item.toString());
          })
          .whereType<int>()
          .toList(growable: false);
    } catch (_) {
      await _prefs.remove(_hiddenFolderIdsKey);
      return const <int>[];
    }
  }

  Future<void> saveHiddenFolderIds(List<int> folderIds) =>
      _prefs.setString(_hiddenFolderIdsKey, jsonEncode(folderIds));
}
