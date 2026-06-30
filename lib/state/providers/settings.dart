part of '../providers.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  bool _hydrated = false;

  @override
  ThemeMode build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_load());
    }
    return ThemeMode.dark;
  }

  Future<void> _load() async {
    final value = await ref.read(appLocalStoreProvider).readThemeMode();
    if (value == null) return;
    state = _decode(value);
  }

  void toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  void set(ThemeMode mode) {
    state = mode;
    unawaited(ref.read(appLocalStoreProvider).saveThemeMode(_encode(mode)));
  }

  ThemeMode _decode(String value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  String _encode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class WindowCloseBehaviorNotifier extends Notifier<WindowCloseBehavior> {
  bool _hydrated = false;

  @override
  WindowCloseBehavior build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_load());
    }
    return WindowCloseBehavior.tray;
  }

  Future<void> _load() async {
    final value = await ref
        .read(appLocalStoreProvider)
        .readWindowCloseBehavior();
    if (value == null) return;
    state = _decode(value);
  }

  void set(WindowCloseBehavior behavior) {
    state = behavior;
    unawaited(
      ref.read(appLocalStoreProvider).saveWindowCloseBehavior(behavior.value),
    );
  }

  WindowCloseBehavior _decode(String value) {
    return switch (value) {
      'minimize' => WindowCloseBehavior.minimize,
      'exit' => WindowCloseBehavior.exit,
      _ => WindowCloseBehavior.tray,
    };
  }
}

final windowCloseBehaviorProvider =
    NotifierProvider<WindowCloseBehaviorNotifier, WindowCloseBehavior>(
      WindowCloseBehaviorNotifier.new,
    );

@immutable
class PlaybackSettings {
  const PlaybackSettings({
    this.audioQuality = AudioQualityPreference.auto,
    this.playbackSpeed = 1.0,
    this.lyricsSourcePreference = LyricsSourcePreference.auto,
    this.immersiveDefaultTheme = ImmersiveThemePreference.standard,
    this.historyLimit = 100,
  });

  final AudioQualityPreference audioQuality;
  final double playbackSpeed;
  final LyricsSourcePreference lyricsSourcePreference;
  final ImmersiveThemePreference immersiveDefaultTheme;
  final int historyLimit;

  PlaybackSettings copyWith({
    AudioQualityPreference? audioQuality,
    double? playbackSpeed,
    LyricsSourcePreference? lyricsSourcePreference,
    ImmersiveThemePreference? immersiveDefaultTheme,
    int? historyLimit,
  }) {
    return PlaybackSettings(
      audioQuality: audioQuality ?? this.audioQuality,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      lyricsSourcePreference:
          lyricsSourcePreference ?? this.lyricsSourcePreference,
      immersiveDefaultTheme:
          immersiveDefaultTheme ?? this.immersiveDefaultTheme,
      historyLimit: historyLimit ?? this.historyLimit,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'audioQuality': audioQuality.name,
      'playbackSpeed': playbackSpeed,
      'lyricsSourcePreference': lyricsSourcePreference.name,
      'immersiveDefaultTheme': immersiveDefaultTheme.name,
      'historyLimit': historyLimit,
    };
  }

  factory PlaybackSettings.fromJson(Map<String, dynamic> json) {
    return PlaybackSettings(
      audioQuality: _enumFromName(
        AudioQualityPreference.values,
        json['audioQuality'],
        AudioQualityPreference.auto,
      ),
      playbackSpeed: _clampPlaybackSpeed(json['playbackSpeed']),
      lyricsSourcePreference: _enumFromName(
        LyricsSourcePreference.values,
        json['lyricsSourcePreference'],
        LyricsSourcePreference.auto,
      ),
      immersiveDefaultTheme: _enumFromName(
        ImmersiveThemePreference.values,
        json['immersiveDefaultTheme'],
        ImmersiveThemePreference.standard,
      ),
      historyLimit: _clampHistoryLimit(json['historyLimit']),
    );
  }
}

enum ImmersiveThemePreference {
  standard('普通'),
  vinyl('黑胶'),
  tilt('倾诉'),
  fume('浮名'),
  partita('云阶');

  const ImmersiveThemePreference(this.label);

  final String label;

  String get description => '打开沉浸模式时默认进入$label主题';
}

T _enumFromName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

double _clampPlaybackSpeed(Object? raw) {
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  return (value ?? 1.0).clamp(0.5, 2.0).toDouble();
}

int _clampHistoryLimit(Object? raw) {
  final value = raw is num ? raw.toInt() : int.tryParse('$raw');
  return (value ?? 100).clamp(20, 500).toInt();
}

String _pathJoin(String left, String right) {
  final separator = Platform.pathSeparator;
  return left.endsWith(separator) ? '$left$right' : '$left$separator$right';
}

Future<Directory> _managedCacheDirectory() async {
  Directory base;
  try {
    base = await getApplicationCacheDirectory().timeout(
      const Duration(seconds: 3),
    );
  } catch (_) {
    base = await getTemporaryDirectory().timeout(const Duration(seconds: 3));
  }
  final directory = Directory(_pathJoin(base.path, 'BiliTune'));
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}

Future<int> _directorySizeBytes(Directory directory) async {
  if (!await directory.exists()) return 0;
  var total = 0;
  final deadline = DateTime.now().add(const Duration(seconds: 12));
  final pending = <Directory>[directory];

  while (pending.isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Cache size scan timed out.');
    }

    final current = pending.removeLast();
    await for (final entity
        in current
            .list(followLinks: false)
            .timeout(const Duration(seconds: 3))) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Cache size scan timed out.');
      }
      try {
        if (entity is File) {
          total += await entity.length().timeout(
            const Duration(milliseconds: 500),
          );
        } else if (entity is Directory) {
          pending.add(entity);
        }
      } catch (_) {}
    }
  }

  return total;
}

Future<void> _deleteDirectoryContents(Directory directory) async {
  if (!await directory.exists()) return;
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  final entries = <FileSystemEntity>[];
  final pending = <Directory>[directory];

  while (pending.isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Cache clear timed out.');
    }

    final current = pending.removeLast();
    await for (final entity
        in current
            .list(followLinks: false)
            .timeout(const Duration(seconds: 3))) {
      entries.add(entity);
      if (entity is Directory) pending.add(entity);
    }
  }

  entries.sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final entity in entries) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Cache clear timed out.');
    }
    try {
      await entity.delete(recursive: true);
    } catch (_) {}
  }
}

final playbackSettingsBootstrapProvider = Provider<PlaybackSettings?>(
  (ref) => null,
);

class PlaybackSettingsNotifier extends Notifier<PlaybackSettings> {
  bool _hydrated = false;

  @override
  PlaybackSettings build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_load());
    }
    return ref.read(playbackSettingsBootstrapProvider) ??
        const PlaybackSettings();
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(appLocalStoreProvider).readPlaybackSettings();
      if (raw != null) state = PlaybackSettings.fromJson(raw);
    } catch (_) {}
  }

  Future<void> setAudioQuality(AudioQualityPreference value) =>
      _update(state.copyWith(audioQuality: value));

  Future<void> setPlaybackSpeed(double value) =>
      _update(state.copyWith(playbackSpeed: _clampPlaybackSpeed(value)));

  Future<void> setLyricsSourcePreference(LyricsSourcePreference value) =>
      _update(state.copyWith(lyricsSourcePreference: value));

  Future<void> setImmersiveDefaultTheme(ImmersiveThemePreference value) =>
      _update(state.copyWith(immersiveDefaultTheme: value));

  Future<void> setHistoryLimit(int value) async {
    final limit = _clampHistoryLimit(value);
    await _update(state.copyWith(historyLimit: limit));
    final local = ref.read(appLocalStoreProvider);
    final history = await local.readPlaybackHistory();
    final trimmed = history.take(limit).toList(growable: false);
    if (trimmed.length != history.length) {
      await local.savePlaybackHistory(trimmed);
    }
  }

  Future<void> _update(PlaybackSettings next) async {
    state = next;
    await ref.read(appLocalStoreProvider).savePlaybackSettings(next.toJson());
  }
}

final playbackSettingsProvider =
    NotifierProvider<PlaybackSettingsNotifier, PlaybackSettings>(
      PlaybackSettingsNotifier.new,
    );

@immutable
class DownloadSettings {
  const DownloadSettings({
    this.directoryPath,
    this.maxConcurrent = 3,
    this.outputFileType = 'audio',
  });

  final String? directoryPath;
  final int maxConcurrent;
  final String outputFileType;

  String get formatLabel => switch (outputFileType) {
    'audio' => '原始音频',
    _ => outputFileType,
  };

  DownloadSettings copyWith({
    Object? directoryPath = _unset,
    int? maxConcurrent,
    String? outputFileType,
  }) {
    return DownloadSettings(
      directoryPath: identical(directoryPath, _unset)
          ? this.directoryPath
          : directoryPath as String?,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      outputFileType: outputFileType ?? this.outputFileType,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'directoryPath': directoryPath,
      'maxConcurrent': maxConcurrent,
      'outputFileType': outputFileType,
    };
  }

  factory DownloadSettings.fromJson(Map<String, dynamic> json) {
    final rawPath = json['directoryPath']?.toString();
    return DownloadSettings(
      directoryPath: rawPath == null || rawPath.trim().isEmpty
          ? null
          : rawPath.trim(),
      maxConcurrent: _clampConcurrentDownloads(json['maxConcurrent']),
      outputFileType: json['outputFileType']?.toString() == 'audio'
          ? 'audio'
          : 'audio',
    );
  }
}

int _clampConcurrentDownloads(Object? raw) {
  final value = raw is num ? raw.toInt() : int.tryParse('$raw');
  return (value ?? 3).clamp(1, 5).toInt();
}

final downloadSettingsBootstrapProvider = Provider<DownloadSettings?>(
  (ref) => null,
);

class DownloadSettingsNotifier extends Notifier<DownloadSettings> {
  bool _hydrated = false;

  @override
  DownloadSettings build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_load());
    }
    return ref.read(downloadSettingsBootstrapProvider) ??
        const DownloadSettings();
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(appLocalStoreProvider).readDownloadSettings();
      if (raw != null) state = DownloadSettings.fromJson(raw);
    } catch (_) {}
  }

  Future<void> setDirectoryPath(String? path) async {
    final normalized = path?.trim();
    await _update(
      state.copyWith(
        directoryPath: normalized == null || normalized.isEmpty
            ? null
            : normalized,
      ),
    );
  }

  Future<void> setMaxConcurrent(int value) =>
      _update(state.copyWith(maxConcurrent: _clampConcurrentDownloads(value)));

  Future<void> setOutputFileType(String value) => _update(
    state.copyWith(outputFileType: value == 'audio' ? 'audio' : 'audio'),
  );

  Future<void> _update(DownloadSettings next) async {
    state = next;
    await ref.read(appLocalStoreProvider).saveDownloadSettings(next.toJson());
  }
}

final downloadSettingsProvider =
    NotifierProvider<DownloadSettingsNotifier, DownloadSettings>(
      DownloadSettingsNotifier.new,
    );

Future<Directory> _defaultDownloadDirectory() async {
  if (Platform.isAndroid) {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final directory = Directory(_pathJoin(base.path, 'BiliTune'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  final base =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final directory = Directory(_pathJoin(base.path, 'BiliTune'));
  if (!await directory.exists()) await directory.create(recursive: true);
  return directory;
}

final downloadDirectoryProvider = FutureProvider<String>((ref) async {
  final settings = ref.watch(downloadSettingsProvider);
  final customPath = settings.directoryPath;
  if (customPath != null && customPath.trim().isNotEmpty) {
    return customPath;
  }
  return (await _defaultDownloadDirectory()).path;
});

@immutable
class CacheState {
  const CacheState({
    this.sizeBytes = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  final int sizeBytes;
  final bool isLoading;
  final String? errorMessage;

  String get label => isLoading
      ? '统计中...'
      : errorMessage != null
      ? '读取失败'
      : Format.bytes(sizeBytes);

  CacheState copyWith({
    int? sizeBytes,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return CacheState(
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class CacheNotifier extends Notifier<CacheState> {
  bool _bootstrapped = false;
  Future<void>? _activeRefresh;

  @override
  CacheState build() {
    if (!_bootstrapped) {
      _bootstrapped = true;
      unawaited(Future<void>.microtask(refresh));
    }
    return const CacheState(isLoading: true);
  }

  Future<void> refresh() async {
    final activeRefresh = _activeRefresh;
    if (activeRefresh != null) return activeRefresh;

    final refresh = _refresh();
    _activeRefresh = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_activeRefresh, refresh)) {
        _activeRefresh = null;
      }
    }
  }

  Future<void> _refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final directory = await _managedCacheDirectory();
      final sizeBytes = await _directorySizeBytes(directory);
      state = CacheState(sizeBytes: sizeBytes, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> clear() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final directory = await _managedCacheDirectory();
      await _deleteDirectoryContents(directory);
      await refresh();
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }
}

final cacheProvider = NotifierProvider<CacheNotifier, CacheState>(
  CacheNotifier.new,
);
