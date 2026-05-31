import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class AppLocalStore {
  AppLocalStore(this._prefs);

  static const _themeModeKey = 'settings.theme_mode';
  static const _windowCloseBehaviorKey = 'settings.window_close_behavior';
  static const _searchHistoryKey = 'search.history';
  static const _downloadTasksKey = 'downloads.tasks';

  final SharedPreferencesAsync _prefs;

  Future<String?> readThemeMode() => _prefs.getString(_themeModeKey);

  Future<void> saveThemeMode(String value) =>
      _prefs.setString(_themeModeKey, value);

  Future<String?> readWindowCloseBehavior() =>
      _prefs.getString(_windowCloseBehaviorKey);

  Future<void> saveWindowCloseBehavior(String value) =>
      _prefs.setString(_windowCloseBehaviorKey, value);

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
}
