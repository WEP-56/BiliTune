import 'dart:async';
import 'dart:math';
import 'dart:io' show Directory, File, Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/bili_cookie_store.dart';
import '../core/network/bili_dio.dart';
import '../core/network/bili_wbi_signer.dart';
import '../core/platform/system_media_controls.dart';
import '../core/platform/windows_hotkeys.dart';
import '../core/platform/windows_startup.dart';
import '../core/utils/format.dart';
import '../data/local/app_local_store.dart';
import '../data/models/models.dart';
import '../data/repositories/bili_auth_repository.dart';
import '../data/repositories/bili_music_repository.dart';
import '../data/services/bili_api_service.dart';

const _unset = Object();
const int libraryDownloadsPlaylistId = -1;

enum WindowCloseBehavior { minimize, tray, exit }

extension WindowCloseBehaviorX on WindowCloseBehavior {
  String get label => switch (this) {
    WindowCloseBehavior.minimize => '最小化',
    WindowCloseBehavior.tray => '到托盘',
    WindowCloseBehavior.exit => '退出',
  };

  String get value => switch (this) {
    WindowCloseBehavior.minimize => 'minimize',
    WindowCloseBehavior.tray => 'tray',
    WindowCloseBehavior.exit => 'exit',
  };
}

final sharedPreferencesAsyncProvider = Provider<SharedPreferencesAsync>(
  (ref) => SharedPreferencesAsync(),
);

final appLocalStoreProvider = Provider<AppLocalStore>(
  (ref) => AppLocalStore(ref.watch(sharedPreferencesAsyncProvider)),
);

final biliCookieStoreProvider = Provider<BiliCookieStore>(
  (ref) => BiliCookieStore(ref.watch(sharedPreferencesAsyncProvider)),
);

final biliDioProvider = Provider<Dio>(
  (ref) => BiliDioFactory.create(ref.watch(biliCookieStoreProvider)),
);

final biliWbiSignerProvider = Provider<BiliWbiSigner>(
  (ref) => BiliWbiSigner(ref.watch(biliDioProvider)),
);

final biliApiServiceProvider = Provider<BiliApiService>(
  (ref) => BiliApiService(
    ref.watch(biliDioProvider),
    ref.watch(biliCookieStoreProvider),
    ref.watch(biliWbiSignerProvider),
  ),
);

final biliAuthRepositoryProvider = Provider<BiliAuthRepository>(
  (ref) => BiliAuthRepository(
    ref.watch(biliApiServiceProvider),
    ref.watch(biliCookieStoreProvider),
  ),
);

final biliMusicRepositoryProvider = Provider<BiliMusicRepository>(
  (ref) => BiliMusicRepository(ref.watch(biliApiServiceProvider)),
);

bool get _skipNetworkBootstrap =>
    Platform.environment['FLUTTER_TEST'] == 'true';

const _playerBufferSize = 128 * 1024 * 1024;
const _streamingMpvProperties = <String, String>{
  'cache': 'yes',
  'cache-on-disk': 'yes',
  'demuxer-max-bytes': '$_playerBufferSize',
  'demuxer-max-back-bytes': '$_playerBufferSize',
  'demuxer-readahead-secs': '60',
  'cache-pause': 'yes',
  'cache-pause-wait': '3',
  'cache-pause-initial': 'yes',
};
const _biliPlaybackHeaders = <String, String>{
  'User-Agent': biliUserAgent,
  'Referer': biliReferer,
  'Origin': 'https://www.bilibili.com',
};

final mediaPlayerProvider = Provider<mk.Player>((ref) {
  mk.MediaKit.ensureInitialized();
  final player = mk.Player(
    configuration: const mk.PlayerConfiguration(
      title: 'BiliTune',
      bufferSize: _playerBufferSize,
    ),
  );
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

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
    this.loudnessNormalization = false,
    this.lyricsSourcePreference = LyricsSourcePreference.auto,
    this.historyLimit = 100,
  });

  final AudioQualityPreference audioQuality;
  final double playbackSpeed;
  final bool loudnessNormalization;
  final LyricsSourcePreference lyricsSourcePreference;
  final int historyLimit;

  PlaybackSettings copyWith({
    AudioQualityPreference? audioQuality,
    double? playbackSpeed,
    bool? loudnessNormalization,
    LyricsSourcePreference? lyricsSourcePreference,
    int? historyLimit,
  }) {
    return PlaybackSettings(
      audioQuality: audioQuality ?? this.audioQuality,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      loudnessNormalization:
          loudnessNormalization ?? this.loudnessNormalization,
      lyricsSourcePreference:
          lyricsSourcePreference ?? this.lyricsSourcePreference,
      historyLimit: historyLimit ?? this.historyLimit,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'audioQuality': audioQuality.name,
      'playbackSpeed': playbackSpeed,
      'loudnessNormalization': loudnessNormalization,
      'lyricsSourcePreference': lyricsSourcePreference.name,
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
      loudnessNormalization: json['loudnessNormalization'] == true,
      lyricsSourcePreference: _enumFromName(
        LyricsSourcePreference.values,
        json['lyricsSourcePreference'],
        LyricsSourcePreference.auto,
      ),
      historyLimit: _clampHistoryLimit(json['historyLimit']),
    );
  }
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
    base = await getApplicationCacheDirectory();
  } catch (_) {
    base = await getTemporaryDirectory();
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
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File) {
      try {
        total += await entity.length();
      } catch (_) {}
    }
  }
  return total;
}

Future<void> _deleteDirectoryContents(Directory directory) async {
  if (!await directory.exists()) return;
  final entries = await directory
      .list(recursive: true, followLinks: false)
      .toList();
  entries.sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final entity in entries) {
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

  Future<void> setLoudnessNormalization(bool value) =>
      _update(state.copyWith(loudnessNormalization: value));

  Future<void> setLyricsSourcePreference(LyricsSourcePreference value) =>
      _update(state.copyWith(lyricsSourcePreference: value));

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

  @override
  CacheState build() {
    if (!_bootstrapped) {
      _bootstrapped = true;
      unawaited(refresh());
    }
    return const CacheState(isLoading: true);
  }

  Future<void> refresh() async {
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

@immutable
class WindowsStartupState {
  const WindowsStartupState({
    this.enabled = false,
    this.isLoading = false,
    this.errorMessage,
  });

  final bool enabled;
  final bool isLoading;
  final String? errorMessage;

  WindowsStartupState copyWith({
    bool? enabled,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return WindowsStartupState(
      enabled: enabled ?? this.enabled,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class WindowsStartupNotifier extends Notifier<WindowsStartupState> {
  bool _bootstrapped = false;

  @override
  WindowsStartupState build() {
    if (!Platform.isWindows) {
      return const WindowsStartupState(enabled: false, isLoading: false);
    }
    if (!_bootstrapped) {
      _bootstrapped = true;
      unawaited(_load());
    }
    return const WindowsStartupState(isLoading: true);
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final enabled = await WindowsStartupManager.isEnabled();
      state = WindowsStartupState(enabled: enabled, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await WindowsStartupManager.setEnabled(value);
      state = WindowsStartupState(enabled: value, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }
}

final windowsStartupProvider =
    NotifierProvider<WindowsStartupNotifier, WindowsStartupState>(
      WindowsStartupNotifier.new,
    );

final playbackBootstrapProvider = Provider<PlaybackState?>((ref) => null);

final windowsHotkeyBootstrapProvider = Provider<List<WindowsHotkeyBinding>>(
  (ref) => const <WindowsHotkeyBinding>[],
);

class WindowsHotkeyNotifier extends Notifier<List<WindowsHotkeyBinding>> {
  bool _hydrated = false;

  @override
  List<WindowsHotkeyBinding> build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_load());
    }
    return ref.read(windowsHotkeyBootstrapProvider);
  }

  Future<void> setBinding(WindowsHotkeyBinding binding) async {
    if (!binding.isSet) {
      await clearBinding(binding.action);
      return;
    }

    final next = <WindowsHotkeyBinding>[
      for (final existing in state)
        if (existing.action != binding.action &&
            existing.signature != binding.signature)
          existing,
      binding,
    ];
    state = next;
    await _persist(next);
  }

  Future<void> clearBinding(WindowsHotkeyAction action) async {
    final next = state
        .where((binding) => binding.action != action)
        .toList(growable: false);
    state = next;
    await _persist(next);
  }

  Future<void> clearAll() async {
    state = const <WindowsHotkeyBinding>[];
    await _persist(state);
  }

  Future<void> _persist(List<WindowsHotkeyBinding> bindings) {
    return ref
        .read(appLocalStoreProvider)
        .saveWindowsHotkeys(
          bindings.map((binding) => binding.toJson()).toList(growable: false),
        );
  }

  Future<void> _load() async {
    try {
      final bindings = await ref
          .read(appLocalStoreProvider)
          .readWindowsHotkeys();
      final parsed = bindings
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
      if (state.isEmpty && parsed.isNotEmpty) {
        state = parsed;
      }
    } catch (_) {}
  }
}

final windowsHotkeysProvider =
    NotifierProvider<WindowsHotkeyNotifier, List<WindowsHotkeyBinding>>(
      WindowsHotkeyNotifier.new,
    );

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
      SidebarCollapsedNotifier.new,
    );

class NowPlayingOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final nowPlayingOpenProvider = NotifierProvider<NowPlayingOpenNotifier, bool>(
  NowPlayingOpenNotifier.new,
);

@immutable
class AuthState {
  const AuthState({
    this.credential,
    this.account,
    this.qrSession,
    this.qrStatus,
    this.isLoading = false,
    this.errorMessage,
  });

  final BiliCredential? credential;
  final BiliAccount? account;
  final QrLoginSession? qrSession;
  final QrLoginStatus? qrStatus;
  final bool isLoading;
  final String? errorMessage;

  bool get isSignedIn => credential?.isSignedIn ?? false;

  AuthState copyWith({
    Object? credential = _unset,
    Object? account = _unset,
    Object? qrSession = _unset,
    Object? qrStatus = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AuthState(
      credential: identical(credential, _unset)
          ? this.credential
          : credential as BiliCredential?,
      account: identical(account, _unset)
          ? this.account
          : account as BiliAccount?,
      qrSession: identical(qrSession, _unset)
          ? this.qrSession
          : qrSession as QrLoginSession?,
      qrStatus: identical(qrStatus, _unset)
          ? this.qrStatus
          : qrStatus as QrLoginStatus?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  bool _hydrated = false;

  @override
  AuthState build() {
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_restore());
    }
    return const AuthState();
  }

  Future<void> _restore() async {
    final repository = ref.read(biliAuthRepositoryProvider);
    final credential = await repository.restoreSession();
    state = state.copyWith(credential: credential);
    if (credential?.isSignedIn ?? false) {
      await refreshAccount();
    }
  }

  Future<void> refreshAccount() async {
    try {
      final account = await ref
          .read(biliAuthRepositoryProvider)
          .currentAccount();
      final credential = await ref
          .read(biliAuthRepositoryProvider)
          .restoreSession();
      state = state.copyWith(
        account: account,
        credential: credential ?? state.credential,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> createQrLoginSession() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await ref
          .read(biliAuthRepositoryProvider)
          .createQrLoginSession();
      state = state.copyWith(
        qrSession: session,
        qrStatus: QrLoginStatus.waiting,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> pollQrLogin() async {
    final session = state.qrSession;
    if (session == null) return;

    try {
      final result = await ref
          .read(biliAuthRepositoryProvider)
          .pollQrLogin(session);
      state = state.copyWith(
        qrStatus: result.status,
        credential: result.credential ?? state.credential,
        errorMessage: result.status == QrLoginStatus.failed
            ? (result.message ?? 'QR login failed')
            : null,
      );
      if (result.status == QrLoginStatus.confirmed) {
        await refreshAccount();
      }
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> saveManualCookie(String cookieHeader) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repository = ref.read(biliAuthRepositoryProvider);
      await repository.saveManualCookie(cookieHeader);
      final account = await repository.currentAccount();
      if (account == null) {
        await repository.logout();
        throw StateError('Cookie 无效或已过期');
      }
      final credential = await repository.restoreSession();
      state = state.copyWith(
        credential: credential,
        account: account,
        isLoading: false,
        qrSession: null,
        qrStatus: null,
      );
    } catch (error) {
      state = state.copyWith(
        credential: null,
        account: null,
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> logout() async {
    await ref.read(biliAuthRepositoryProvider).logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

enum SearchMode { music, all }

@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.mode = SearchMode.music,
    this.defaultKeyword,
    this.results = const <Track>[],
    this.hotWords = const <String>[],
    this.suggestions = const <String>[],
    this.history = const <String>[],
    this.page = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final String query;
  final SearchMode mode;
  final String? defaultKeyword;
  final List<Track> results;
  final List<String> hotWords;
  final List<String> suggestions;
  final List<String> history;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  SearchState copyWith({
    String? query,
    SearchMode? mode,
    Object? defaultKeyword = _unset,
    List<Track>? results,
    List<String>? hotWords,
    List<String>? suggestions,
    List<String>? history,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? errorMessage = _unset,
  }) {
    return SearchState(
      query: query ?? this.query,
      mode: mode ?? this.mode,
      defaultKeyword: identical(defaultKeyword, _unset)
          ? this.defaultKeyword
          : defaultKeyword as String?,
      results: results ?? this.results,
      hotWords: hotWords ?? this.hotWords,
      suggestions: suggestions ?? this.suggestions,
      history: history ?? this.history,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  bool _bootstrapped = false;

  @override
  SearchState build() {
    if (!_bootstrapped && !_skipNetworkBootstrap) {
      _bootstrapped = true;
      unawaited(_bootstrap());
    }
    return const SearchState();
  }

  Future<void> _bootstrap() async {
    final local = ref.read(appLocalStoreProvider);
    final repository = ref.read(biliMusicRepositoryProvider);

    final history = await local.readSearchHistory();
    state = state.copyWith(history: history);

    try {
      final defaultKeyword = await repository.defaultSearchKeyword();
      state = state.copyWith(defaultKeyword: defaultKeyword);
    } catch (_) {
      state = state.copyWith(defaultKeyword: null);
    }

    try {
      final hotWords = await repository.hotWords();
      state = state.copyWith(
        hotWords: hotWords.take(12).toList(growable: false),
      );
    } catch (_) {
      state = state.copyWith(hotWords: const <String>[]);
    }
  }

  Future<void> search(String query, {SearchMode? mode}) async {
    final keyword = query.trim();
    final nextMode = mode ?? state.mode;
    if (keyword.isEmpty) {
      state = state.copyWith(
        query: '',
        mode: nextMode,
        results: const <Track>[],
        page: 0,
        hasMore: false,
      );
      return;
    }

    state = state.copyWith(
      query: keyword,
      mode: nextMode,
      isLoading: true,
      isLoadingMore: false,
      errorMessage: null,
    );

    try {
      final repository = ref.read(biliMusicRepositoryProvider);
      final results = switch (nextMode) {
        SearchMode.music => await repository.searchMusicTracks(keyword),
        SearchMode.all => await repository.searchTracks(keyword),
      };
      final history = <String>[
        keyword,
        ...state.history.where((item) => item != keyword),
      ].take(20).toList(growable: false);
      await ref.read(appLocalStoreProvider).saveSearchHistory(history);
      state = state.copyWith(
        results: results,
        history: history,
        page: 1,
        hasMore: results.length >= 20,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> loadMore() async {
    final keyword = state.query.trim();
    if (keyword.isEmpty ||
        state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }

    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true, errorMessage: null);

    try {
      final repository = ref.read(biliMusicRepositoryProvider);
      final nextResults = switch (state.mode) {
        SearchMode.music => await repository.searchMusicTracks(
          keyword,
          page: nextPage,
        ),
        SearchMode.all => await repository.searchTracks(
          keyword,
          page: nextPage,
        ),
      };
      final merged = _mergeTracks([...state.results, ...nextResults]);
      state = state.copyWith(
        results: merged,
        page: nextPage,
        hasMore: nextResults.length >= 20,
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: error.toString(),
      );
    }
  }

  List<Track> _mergeTracks(Iterable<Track> tracks) {
    final seen = <String>{};
    final merged = <Track>[];
    for (final track in tracks) {
      final key = track.bvid ?? track.aid?.toString() ?? track.id;
      if (seen.add(key)) merged.add(track);
    }
    return merged;
  }

  Future<void> loadSuggestions(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      state = state.copyWith(suggestions: const <String>[]);
      return;
    }

    try {
      final suggestions = await ref
          .read(biliMusicRepositoryProvider)
          .suggestions(keyword);
      state = state.copyWith(
        suggestions: suggestions.take(8).toList(growable: false),
      );
    } catch (_) {
      state = state.copyWith(suggestions: const <String>[]);
    }
  }

  Future<void> removeHistory(String keyword) async {
    final history = state.history
        .where((item) => item != keyword)
        .toList(growable: false);
    await ref.read(appLocalStoreProvider).saveSearchHistory(history);
    state = state.copyWith(history: history);
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

@immutable
class DiscoverState {
  const DiscoverState({
    this.featuredTrack,
    this.featuredTracks = const <Track>[],
    this.featuredKeyword,
    this.quickPicks = const <String>[],
    this.shelves = const <Shelf>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final Track? featuredTrack;
  final List<Track> featuredTracks;
  final String? featuredKeyword;
  final List<String> quickPicks;
  final List<Shelf> shelves;
  final bool isLoading;
  final String? errorMessage;

  DiscoverState copyWith({
    Object? featuredTrack = _unset,
    List<Track>? featuredTracks,
    Object? featuredKeyword = _unset,
    List<String>? quickPicks,
    List<Shelf>? shelves,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return DiscoverState(
      featuredTrack: identical(featuredTrack, _unset)
          ? this.featuredTrack
          : featuredTrack as Track?,
      featuredTracks: featuredTracks ?? this.featuredTracks,
      featuredKeyword: identical(featuredKeyword, _unset)
          ? this.featuredKeyword
          : featuredKeyword as String?,
      quickPicks: quickPicks ?? this.quickPicks,
      shelves: shelves ?? this.shelves,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class DiscoverNotifier extends Notifier<DiscoverState> {
  bool _bootstrapped = false;

  @override
  DiscoverState build() {
    if (!_bootstrapped && !_skipNetworkBootstrap) {
      _bootstrapped = true;
      unawaited(_bootstrap());
      return const DiscoverState(isLoading: true);
    }
    return const DiscoverState();
  }

  Future<void> _bootstrap() async {
    state = const DiscoverState(isLoading: true);
    try {
      final repository = ref.read(biliMusicRepositoryProvider);
      final local = ref.read(appLocalStoreProvider);
      final recentHistory = await local.readSearchHistory();
      final musicFeaturedTracks = await repository.musicFeaturedTracks();
      final fallbackFeaturedTrack = musicFeaturedTracks.isEmpty
          ? await repository.discoverFeaturedTrack()
          : null;
      final featuredTrack = musicFeaturedTracks.isNotEmpty
          ? musicFeaturedTracks.first
          : fallbackFeaturedTrack;
      final musicShelves = await repository.musicShelves();
      final shelves = musicShelves.isNotEmpty
          ? musicShelves
          : await repository.discoverShelves();
      final quickPicks = await repository.discoverQuickPicks(
        recentHistory: recentHistory,
      );
      state = state.copyWith(
        featuredTrack: featuredTrack,
        featuredTracks: musicFeaturedTracks.isNotEmpty
            ? musicFeaturedTracks
            : [?fallbackFeaturedTrack],
        featuredKeyword: await repository.discoverFeaturedKeyword(),
        quickPicks: quickPicks,
        shelves: shelves,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> refresh() async {
    _bootstrapped = false;
    await _bootstrap();
  }
}

final discoverProvider = NotifierProvider<DiscoverNotifier, DiscoverState>(
  DiscoverNotifier.new,
);

@immutable
class LibraryState {
  const LibraryState({
    this.folders = const <BiliFavoriteFolder>[],
    this.selectedFolderId,
    this.selectedFolderTracks = const <Track>[],
    this.recentHistory = const <Track>[],
    this.trackKeyword = '',
    this.isLoading = false,
    this.errorMessage,
  });

  final List<BiliFavoriteFolder> folders;
  final int? selectedFolderId;
  final List<Track> selectedFolderTracks;
  final List<Track> recentHistory;
  final String trackKeyword;
  final bool isLoading;
  final String? errorMessage;

  BiliFavoriteFolder? get selectedFolder =>
      folders.cast<BiliFavoriteFolder?>().firstWhere(
        (folder) => folder?.mediaId == selectedFolderId,
        orElse: () => null,
      );

  LibraryState copyWith({
    List<BiliFavoriteFolder>? folders,
    Object? selectedFolderId = _unset,
    List<Track>? selectedFolderTracks,
    List<Track>? recentHistory,
    String? trackKeyword,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return LibraryState(
      folders: folders ?? this.folders,
      selectedFolderId: identical(selectedFolderId, _unset)
          ? this.selectedFolderId
          : selectedFolderId as int?,
      selectedFolderTracks: selectedFolderTracks ?? this.selectedFolderTracks,
      recentHistory: recentHistory ?? this.recentHistory,
      trackKeyword: trackKeyword ?? this.trackKeyword,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  bool _bootstrapped = false;
  bool? _lastSignedIn;

  @override
  LibraryState build() {
    ref.listen<PlaybackSettings>(playbackSettingsProvider, (previous, next) {
      if (previous?.historyLimit != next.historyLimit) {
        unawaited(_trimPlaybackHistory(next.historyLimit));
      }
    });
    final signedIn = ref.watch(
      authProvider.select((state) => state.isSignedIn),
    );
    if (_lastSignedIn != signedIn) {
      _lastSignedIn = signedIn;
      _bootstrapped = false;
    }

    if (!_bootstrapped && !_skipNetworkBootstrap) {
      _bootstrapped = true;
      unawaited(_bootstrap());
    }

    return const LibraryState();
  }

  Future<void> _bootstrap() async {
    state = const LibraryState(isLoading: true);
    try {
      final auth = ref.read(authProvider);
      final repository = ref.read(biliMusicRepositoryProvider);
      final local = ref.read(appLocalStoreProvider);
      final credential = auth.credential;
      final mid = credential?.mid ?? auth.account?.mid;
      final hiddenFolderIds = (await local.readHiddenFolderIds()).toSet();

      final syncedFolders = mid == null
          ? const <BiliFavoriteFolder>[]
          : await repository.favoriteFolders(mid);
      final folders = syncedFolders
          .where((folder) => !hiddenFolderIds.contains(folder.mediaId))
          .toList(growable: false);
      final recentHistory = await local.readPlaybackHistory();
      final limit = ref.read(playbackSettingsProvider).historyLimit;
      final trimmedHistory = recentHistory.take(limit).toList(growable: false);
      if (trimmedHistory.length != recentHistory.length) {
        await local.savePlaybackHistory(trimmedHistory);
      }
      state = state.copyWith(
        folders: folders,
        selectedFolderId: null,
        selectedFolderTracks: const <Track>[],
        recentHistory: trimmedHistory,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> _trimPlaybackHistory(int limit) async {
    final local = ref.read(appLocalStoreProvider);
    final history = await local.readPlaybackHistory();
    final trimmed = history.take(limit).toList(growable: false);
    if (trimmed.length != history.length) {
      await local.savePlaybackHistory(trimmed);
    }
    if (state.recentHistory.length != trimmed.length) {
      state = state.copyWith(recentHistory: trimmed);
    } else if (trimmed.isNotEmpty &&
        state.recentHistory.isNotEmpty &&
        state.recentHistory.first.id == trimmed.first.id) {
      state = state.copyWith(recentHistory: trimmed);
    }
  }

  Future<void> selectFolder(int mediaId) async {
    if (mediaId == libraryDownloadsPlaylistId) {
      selectDownloads();
      return;
    }
    state = state.copyWith(
      selectedFolderId: mediaId,
      trackKeyword: '',
      isLoading: true,
    );
    try {
      final tracks = await ref
          .read(biliMusicRepositoryProvider)
          .favoriteFolderTracks(mediaId);
      state = state.copyWith(
        selectedFolderTracks: tracks,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void selectRecent() {
    state = state.copyWith(
      selectedFolderId: null,
      selectedFolderTracks: const <Track>[],
      trackKeyword: '',
      errorMessage: null,
    );
  }

  void selectDownloads() {
    state = state.copyWith(
      selectedFolderId: libraryDownloadsPlaylistId,
      selectedFolderTracks: const <Track>[],
      trackKeyword: '',
      errorMessage: null,
    );
  }

  Future<void> searchSelectedTracks(String keyword) async {
    final trimmed = keyword.trim();
    final mediaId = state.selectedFolderId;

    if (mediaId == null || mediaId == libraryDownloadsPlaylistId) {
      state = state.copyWith(trackKeyword: trimmed, errorMessage: null);
      return;
    }

    state = state.copyWith(
      trackKeyword: trimmed,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final tracks = await ref
          .read(biliMusicRepositoryProvider)
          .favoriteFolderTracks(
            mediaId,
            keyword: trimmed.isEmpty ? null : trimmed,
          );
      state = state.copyWith(selectedFolderTracks: tracks, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> refresh() async {
    _bootstrapped = false;
    await _bootstrap();
  }

  Future<void> createFavoriteFolder({
    required String title,
    String intro = '',
    bool isPrivate = false,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await ref
          .read(biliMusicRepositoryProvider)
          .createFavoriteFolder(
            title: trimmed,
            intro: intro.trim(),
            isPrivate: isPrivate,
          );
      await _bootstrap();
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> addTrackToFavoriteFolder(Track track, int mediaId) async {
    state = state.copyWith(errorMessage: null);
    try {
      await ref
          .read(biliMusicRepositoryProvider)
          .addTrackToFavoriteFolder(track: track, mediaId: mediaId);
      if (state.selectedFolderId == mediaId) {
        final tracks = await ref
            .read(biliMusicRepositoryProvider)
            .favoriteFolderTracks(mediaId);
        state = state.copyWith(selectedFolderTracks: tracks);
      }
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> removeTrackFromFavoriteFolder(Track track, int mediaId) async {
    state = state.copyWith(errorMessage: null);
    try {
      await ref
          .read(biliMusicRepositoryProvider)
          .removeTrackFromFavoriteFolder(track: track, mediaId: mediaId);
      if (state.selectedFolderId == mediaId) {
        final tracks = await ref
            .read(biliMusicRepositoryProvider)
            .favoriteFolderTracks(mediaId);
        state = state.copyWith(selectedFolderTracks: tracks);
      }
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> recordPlayback(Track track) async {
    final local = ref.read(appLocalStoreProvider);
    final history = await local.readPlaybackHistory();
    final limit = ref.read(playbackSettingsProvider).historyLimit;
    final next = <Track>[
      track,
      ...history.where((item) => _trackKey(item) != _trackKey(track)),
    ].take(limit).toList(growable: false);
    await local.savePlaybackHistory(next);
    state = state.copyWith(recentHistory: next);
  }

  Future<void> refreshLocalHistory() async {
    final history = await ref.read(appLocalStoreProvider).readPlaybackHistory();
    final limit = ref.read(playbackSettingsProvider).historyLimit;
    final trimmed = history.take(limit).toList(growable: false);
    state = state.copyWith(recentHistory: trimmed);
  }

  Future<void> hideFavoriteFolder(int mediaId) async {
    final local = ref.read(appLocalStoreProvider);
    final hidden = (await local.readHiddenFolderIds()).toSet()..add(mediaId);
    await local.saveHiddenFolderIds(hidden.toList(growable: false)..sort());
    final nextFolders = state.folders
        .where((folder) => folder.mediaId != mediaId)
        .toList(growable: false);
    state = state.copyWith(
      folders: nextFolders,
      selectedFolderId: state.selectedFolderId == mediaId
          ? null
          : state.selectedFolderId,
      selectedFolderTracks: state.selectedFolderId == mediaId
          ? const <Track>[]
          : state.selectedFolderTracks,
      trackKeyword: state.selectedFolderId == mediaId ? '' : state.trackKeyword,
      errorMessage: null,
    );
  }

  Future<void> unhideFavoriteFolder(int mediaId) async {
    final local = ref.read(appLocalStoreProvider);
    final hidden = (await local.readHiddenFolderIds()).toSet()..remove(mediaId);
    await local.saveHiddenFolderIds(hidden.toList(growable: false)..sort());
    await _bootstrap();
  }

  String _trackKey(Track track) =>
      track.bvid ??
      track.aid?.toString() ??
      track.audioId?.toString() ??
      track.id;
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);

@immutable
class DownloadQueueState {
  const DownloadQueueState({
    this.tasks = const <DownloadTask>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<DownloadTask> tasks;
  final bool isLoading;
  final String? errorMessage;

  int get completedCount =>
      tasks.where((task) => task.status == DownloadTaskStatus.completed).length;

  List<DownloadTask> get completedTasks => tasks
      .where(
        (task) =>
            task.status == DownloadTaskStatus.completed &&
            task.savePath != null &&
            task.savePath!.isNotEmpty,
      )
      .toList(growable: false);

  List<Track> get downloadedTracks => completedTasks
      .map(
        (task) => Track(
          id: 'download-${task.id}',
          title: task.title,
          artist: task.artist,
          duration: Duration.zero,
          type: task.type,
          gradientSeed: task.gradientSeed,
          coverUrl: task.coverUrl,
          playCount: task.downloadedBytes,
          bvid: task.bvid,
          aid: task.aid,
          cid: task.cid,
          audioId: task.audioId,
          sourceUrl: Uri.file(task.savePath!).toString(),
        ),
      )
      .toList(growable: false);

  int get activeCount => tasks
      .where((task) => task.status == DownloadTaskStatus.downloading)
      .length;

  double get storageProgress {
    final total = tasks.fold<int>(
      0,
      (sum, task) => sum + (task.totalBytes ?? 0),
    );
    if (total <= 0) return 0;
    final downloaded = tasks.fold<int>(
      0,
      (sum, task) => sum + task.downloadedBytes,
    );
    return (downloaded / total).clamp(0.0, 1.0);
  }

  DownloadQueueState copyWith({
    List<DownloadTask>? tasks,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return DownloadQueueState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class DownloadQueueNotifier extends Notifier<DownloadQueueState> {
  bool _bootstrapped = false;
  bool _scheduling = false;
  final _cancelTokens = <String, CancelToken>{};
  final _lastProgressPersistAt = <String, DateTime>{};

  @override
  DownloadQueueState build() {
    ref.listen<DownloadSettings>(downloadSettingsProvider, (previous, next) {
      if (previous?.maxConcurrent != next.maxConcurrent) {
        unawaited(_scheduleDownloads());
      }
    });
    if (!_bootstrapped && !_skipNetworkBootstrap) {
      _bootstrapped = true;
      unawaited(_bootstrap());
    }
    return const DownloadQueueState();
  }

  Future<void> _bootstrap() async {
    state = const DownloadQueueState(isLoading: true);
    try {
      final loaded = await ref.read(appLocalStoreProvider).readDownloadTasks();
      final tasks = loaded
          .map(
            (task) => task.status == DownloadTaskStatus.downloading
                ? task.copyWith(status: DownloadTaskStatus.paused)
                : task,
          )
          .toList(growable: false);
      if (tasks.length == loaded.length) await _persist(tasks);
      state = state.copyWith(tasks: tasks, isLoading: false);
      unawaited(_scheduleDownloads());
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> enqueueTrack(
    Track track, {
    String outputFileType = 'audio',
    String? savePath,
  }) async {
    final settings = ref.read(downloadSettingsProvider);
    final task = DownloadTask.fromTrack(
      track,
      outputFileType: outputFileType == 'audio'
          ? settings.outputFileType
          : outputFileType,
      savePath: savePath,
    );
    final tasks = <DownloadTask>[task, ...state.tasks];
    await _persist(tasks);
    state = state.copyWith(tasks: tasks, errorMessage: null);
    await _scheduleDownloads();
  }

  Future<void> pauseTask(String id) async {
    final token = _cancelTokens.remove(id);
    if (token != null && !token.isCancelled) {
      token.cancel('paused');
      return;
    }
    await _updateTask(
      id,
      (task) => task.copyWith(status: DownloadTaskStatus.paused),
    );
    await _scheduleDownloads();
  }

  Future<void> resumeTask(String id) async {
    await _updateTask(
      id,
      (task) => task.copyWith(status: DownloadTaskStatus.queued),
    );
    await _scheduleDownloads();
  }

  Future<void> completeTask(String id) async => _updateTask(
    id,
    (task) => task.copyWith(
      status: DownloadTaskStatus.completed,
      downloadedBytes: task.totalBytes ?? task.downloadedBytes,
    ),
  );

  Future<void> failTask(String id, String message) async => _updateTask(
    id,
    (task) =>
        task.copyWith(status: DownloadTaskStatus.failed, errorMessage: message),
  );

  Future<void> removeTask(String id) async {
    final token = _cancelTokens.remove(id);
    if (token != null && !token.isCancelled) {
      token.cancel('removed');
    }
    final tasks = state.tasks
        .where((task) => task.id != id)
        .toList(growable: false);
    await _persist(tasks);
    state = state.copyWith(tasks: tasks);
    await _scheduleDownloads();
  }

  Future<void> clear() async {
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) token.cancel('cleared');
    }
    _cancelTokens.clear();
    await _persist(const <DownloadTask>[]);
    state = state.copyWith(tasks: const <DownloadTask>[]);
  }

  Future<void> refresh() async {
    _bootstrapped = false;
    await _bootstrap();
  }

  Future<void> _scheduleDownloads() async {
    if (_scheduling) return;
    _scheduling = true;
    try {
      final limit = ref.read(downloadSettingsProvider).maxConcurrent;
      while (state.activeCount < limit) {
        final task = _nextQueuedTask();
        if (task == null) return;
        await _updateTask(
          task.id,
          (task) => task.copyWith(
            status: DownloadTaskStatus.downloading,
            errorMessage: null,
          ),
        );
        unawaited(_startDownload(task.id));
      }
    } finally {
      _scheduling = false;
    }
  }

  Future<void> _updateTask(
    String id,
    DownloadTask Function(DownloadTask task) update,
  ) async {
    final tasks = state.tasks
        .map((task) => task.id == id ? update(task) : task)
        .toList(growable: false);
    await _persist(tasks);
    state = state.copyWith(tasks: tasks, errorMessage: null);
  }

  Future<void> _startDownload(String id) async {
    final task = _taskById(id);
    if (task == null ||
        task.status == DownloadTaskStatus.completed ||
        task.status == DownloadTaskStatus.paused ||
        task.status == DownloadTaskStatus.cancelled) {
      return;
    }
    if (_cancelTokens.containsKey(id)) return;

    final token = CancelToken();
    _cancelTokens[id] = token;

    try {
      final source = await ref
          .read(biliMusicRepositoryProvider)
          .resolvePlaybackSource(_trackFromTask(task));
      final directory = await _downloadDirectory();
      final savePath =
          task.savePath ?? _joinPath(directory.path, _fileName(task, source));

      await _updateTask(
        id,
        (task) => task.copyWith(
          savePath: savePath,
          audioCodecs: _audioCodecs(source),
          audioBandwidth: source.bandwidth,
        ),
      );

      await ref
          .read(biliDioProvider)
          .download(
            source.url,
            savePath,
            cancelToken: token,
            options: Options(
              headers: const <String, String>{
                'User-Agent': biliUserAgent,
                'Referer': biliReferer,
                'Origin': 'https://www.bilibili.com',
              },
              receiveTimeout: const Duration(minutes: 5),
            ),
            onReceiveProgress: (received, total) {
              _setProgress(id, received, total > 0 ? total : null);
            },
          );

      final bytes = await File(savePath).length();
      await _updateTask(
        id,
        (task) => task.copyWith(
          status: DownloadTaskStatus.completed,
          downloadedBytes: bytes,
          totalBytes: bytes,
          errorMessage: null,
        ),
      );
    } catch (error) {
      if ((error is DioException && CancelToken.isCancel(error)) ||
          token.isCancelled) {
        await _updateTask(
          id,
          (task) => task.copyWith(status: DownloadTaskStatus.paused),
        );
      } else {
        await failTask(id, error.toString());
      }
    } finally {
      _cancelTokens.remove(id);
      _lastProgressPersistAt.remove(id);
      unawaited(_scheduleDownloads());
    }
  }

  void _setProgress(String id, int received, int? total) {
    final tasks = state.tasks
        .map(
          (task) => task.id == id
              ? task.copyWith(downloadedBytes: received, totalBytes: total)
              : task,
        )
        .toList(growable: false);
    state = state.copyWith(tasks: tasks, errorMessage: null);

    final now = DateTime.now();
    final last = _lastProgressPersistAt[id];
    if (last == null ||
        now.difference(last) > const Duration(milliseconds: 700)) {
      _lastProgressPersistAt[id] = now;
      unawaited(_persist(tasks));
    }
  }

  DownloadTask? _taskById(String id) {
    for (final task in state.tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  DownloadTask? _nextQueuedTask() {
    for (final task in state.tasks.reversed) {
      if (task.status == DownloadTaskStatus.queued) return task;
    }
    return null;
  }

  Track _trackFromTask(DownloadTask task) {
    return Track(
      id:
          task.bvid ??
          task.aid?.toString() ??
          task.audioId?.toString() ??
          task.id,
      title: task.title,
      artist: task.artist,
      duration: Duration.zero,
      type: task.type,
      gradientSeed: task.gradientSeed,
      coverUrl: task.coverUrl,
      bvid: task.bvid,
      aid: task.aid,
      cid: task.cid,
      audioId: task.audioId,
    );
  }

  Future<Directory> _downloadDirectory() async {
    final settings = ref.read(downloadSettingsProvider);
    final customPath = settings.directoryPath;
    final directory = customPath == null || customPath.trim().isEmpty
        ? await _defaultDownloadDirectory()
        : Directory(customPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _joinPath(String left, String right) {
    final separator = Platform.pathSeparator;
    return left.endsWith(separator) ? '$left$right' : '$left$separator$right';
  }

  String _fileName(DownloadTask task, BiliPlaybackSource source) {
    final title = _sanitizeFileName(task.title).trim();
    final artist = _sanitizeFileName(task.artist).trim();
    final prefix = artist.isEmpty ? title : '$artist - $title';
    final safePrefix = prefix.isEmpty ? task.id : prefix;
    final suffix = task.id.length <= 8
        ? _sanitizeFileName(task.id)
        : _sanitizeFileName(task.id.substring(task.id.length - 8));
    return '${safePrefix.substring(0, min(safePrefix.length, 96))}-$suffix.${_extension(source)}';
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }

  String _extension(BiliPlaybackSource source) {
    final codecs = source.codecs?.toLowerCase() ?? '';
    final mimeType = source.mimeType?.toLowerCase() ?? '';
    if (source.isLossless || codecs.contains('flac')) return 'flac';
    if (mimeType.contains('mp4') || codecs.contains('mp4a')) return 'm4a';
    return 'm4s';
  }

  String? _audioCodecs(BiliPlaybackSource source) {
    if (source.isLossless) return 'flac';
    return source.codecs;
  }

  Future<void> _persist(List<DownloadTask> tasks) async {
    await ref.read(appLocalStoreProvider).saveDownloadTasks(tasks);
  }
}

final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, DownloadQueueState>(
      DownloadQueueNotifier.new,
    );

enum PlayRepeatMode { off, all, one }

@immutable
class PlaybackState {
  const PlaybackState({
    this.track,
    this.queue = const <Track>[],
    this.source,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.bufferAhead = Duration.zero,
    this.isBuffering = false,
    this.bufferingPercentage = 0,
    this.mediaDuration,
    this.shuffle = false,
    this.repeat = PlayRepeatMode.off,
    this.volume = 0.7,
    this.liked = false,
    this.errorMessage,
  });

  final Track? track;
  final List<Track> queue;
  final BiliPlaybackSource? source;
  final bool isPlaying;
  final Duration position;
  final Duration bufferAhead;
  final bool isBuffering;
  final double bufferingPercentage;
  final Duration? mediaDuration;
  final bool shuffle;
  final PlayRepeatMode repeat;
  final double volume;
  final bool liked;
  final String? errorMessage;

  Duration get duration => mediaDuration ?? track?.duration ?? Duration.zero;

  double get progress {
    final total = duration.inMilliseconds;
    if (total == 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double get bufferProgress {
    final total = duration.inMilliseconds;
    if (total == 0) return 0;
    final buffered = position + bufferAhead;
    return (buffered.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration get bufferedPosition => position + bufferAhead;

  PlaybackState copyWith({
    Object? track = _unset,
    List<Track>? queue,
    Object? source = _unset,
    bool? isPlaying,
    Duration? position,
    Duration? bufferAhead,
    bool? isBuffering,
    double? bufferingPercentage,
    Object? mediaDuration = _unset,
    bool? shuffle,
    PlayRepeatMode? repeat,
    double? volume,
    bool? liked,
    Object? errorMessage = _unset,
  }) {
    return PlaybackState(
      track: identical(track, _unset) ? this.track : track as Track?,
      queue: queue ?? this.queue,
      source: identical(source, _unset)
          ? this.source
          : source as BiliPlaybackSource?,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      bufferAhead: bufferAhead ?? this.bufferAhead,
      isBuffering: isBuffering ?? this.isBuffering,
      bufferingPercentage: bufferingPercentage ?? this.bufferingPercentage,
      mediaDuration: identical(mediaDuration, _unset)
          ? this.mediaDuration
          : mediaDuration as Duration?,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      volume: volume ?? this.volume,
      liked: liked ?? this.liked,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'track': track?.toJson(),
      'queue': queue.map((track) => track.toJson()).toList(growable: false),
      'source': source?.toJson(),
      'isPlaying': isPlaying,
      'positionMs': position.inMilliseconds,
      'bufferAheadMs': bufferAhead.inMilliseconds,
      'isBuffering': isBuffering,
      'bufferingPercentage': bufferingPercentage,
      'mediaDurationMs': mediaDuration?.inMilliseconds,
      'shuffle': shuffle,
      'repeat': repeat.name,
      'volume': volume,
      'liked': liked,
      'errorMessage': errorMessage,
    };
  }

  factory PlaybackState.fromJson(Map<String, dynamic> json) {
    final track = json['track'] is Map
        ? Track.fromJson(Map<String, dynamic>.from(json['track'] as Map))
        : null;
    final queue =
        (json['queue'] as List?)
            ?.whereType<Map>()
            .map((item) => Track.fromJson(Map<String, dynamic>.from(item)))
            .where((track) => track.id.isNotEmpty)
            .toList(growable: false) ??
        const <Track>[];
    final repeatName = json['repeat']?.toString();
    final repeat = PlayRepeatMode.values.firstWhere(
      (mode) => mode.name == repeatName,
      orElse: () => PlayRepeatMode.off,
    );
    final mediaDurationMs = (json['mediaDurationMs'] as num?)?.toInt();
    return PlaybackState(
      track: track,
      queue: queue,
      source: null,
      isPlaying: json['isPlaying'] == true,
      position: Duration(
        milliseconds: (json['positionMs'] as num?)?.toInt() ?? 0,
      ),
      bufferAhead: Duration(
        milliseconds: (json['bufferAheadMs'] as num?)?.toInt() ?? 0,
      ),
      isBuffering: json['isBuffering'] == true,
      bufferingPercentage:
          (json['bufferingPercentage'] as num?)?.toDouble() ?? 0,
      mediaDuration: mediaDurationMs == null
          ? null
          : Duration(milliseconds: mediaDurationMs),
      shuffle: json['shuffle'] == true,
      repeat: repeat,
      volume: ((json['volume'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0),
      liked: json['liked'] == true,
      errorMessage: json['errorMessage']?.toString(),
    );
  }
}

class PlaybackNotifier extends Notifier<PlaybackState> {
  Timer? _bufferingFallbackTimer;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _random = Random();
  mk.Player? _player;
  Future<void>? _playerConfiguration;
  bool _handledBootstrap = false;

  @override
  PlaybackState build() {
    final initial =
        ref.read(playbackBootstrapProvider) ?? const PlaybackState();
    ref.listen<PlaybackSettings>(playbackSettingsProvider, (previous, next) {
      if (previous?.playbackSpeed != next.playbackSpeed ||
          previous?.loudnessNormalization != next.loudnessNormalization) {
        unawaited(_applyPlaybackSettings(next));
      }
    });
    listenSelf((_, next) {
      _syncSystemMedia(next);
      unawaited(_persistPlaybackState(next));
    });
    SystemMediaControls.instance.bind(
      onTogglePlay: togglePlay,
      onNext: () async => next(),
      onPrevious: () async => previous(),
      onSeek: seek,
    );

    ref.onDispose(() {
      _bufferingFallbackTimer?.cancel();
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
    });

    if (!_handledBootstrap) {
      _handledBootstrap = true;
      unawaited(Future<void>.microtask(() => _syncSystemMedia(initial)));
      if (initial.isPlaying && initial.track != null) {
        unawaited(_resumePlaybackState(initial));
      }
    }
    return initial;
  }

  Future<void> _persistPlaybackState(PlaybackState playback) async {
    if (_skipNetworkBootstrap) return;
    try {
      await ref
          .read(appLocalStoreProvider)
          .savePlaybackState(playback.toJson());
    } catch (_) {}
  }

  Future<void> saveNow() => _persistPlaybackState(state);

  mk.Player _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;

    final player = ref.read(mediaPlayerProvider);
    _player = player;

    _subscriptions.addAll([
      player.stream.buffering.listen((buffering) {
        state = state.copyWith(isBuffering: buffering);
        if (buffering) {
          _bufferingFallbackTimer?.cancel();
          final source = state.source;
          if (source != null && source.backupUrls.isNotEmpty) {
            _bufferingFallbackTimer = Timer(
              const Duration(seconds: 8),
              () => _tryBackupSource(),
            );
          }
        } else {
          _bufferingFallbackTimer?.cancel();
          _bufferingFallbackTimer = null;
        }
      }),
      player.stream.buffer.listen((bufferAhead) {
        state = state.copyWith(bufferAhead: bufferAhead);
      }),
      player.stream.bufferingPercentage.listen((bufferingPercentage) {
        state = state.copyWith(bufferingPercentage: bufferingPercentage);
      }),
      player.stream.position.listen((position) {
        if (state.source != null) {
          state = state.copyWith(position: position);
        }
      }),
      player.stream.duration.listen((duration) {
        if (duration > Duration.zero) {
          state = state.copyWith(mediaDuration: duration);
        }
      }),
      player.stream.playing.listen((playing) {
        if (state.source != null) {
          state = state.copyWith(isPlaying: playing);
        }
      }),
      player.stream.volume.listen((volume) {
        state = state.copyWith(volume: (volume / 100).clamp(0.0, 1.0));
      }),
      player.stream.error.listen((message) {
        if (message.isEmpty) return;
        state = state.copyWith(
          isPlaying: false,
          isBuffering: false,
          errorMessage: message,
        );
        _bufferingFallbackTimer?.cancel();
        _bufferingFallbackTimer = null;
      }),
      player.stream.completed.listen((completed) {
        if (!completed) return;
        if (state.repeat == PlayRepeatMode.one) {
          unawaited(player.seek(Duration.zero));
          unawaited(player.play());
        } else {
          next();
        }
      }),
    ]);

    _playerConfiguration ??= _configurePlayer(player);
    unawaited(_playerConfiguration);
    return player;
  }

  Future<void> _configurePlayer(mk.Player player) async {
    final platform = player.platform;
    if (platform is! mk.NativePlayer) return;
    for (final entry in _streamingMpvProperties.entries) {
      try {
        await platform.setProperty(entry.key, entry.value);
      } catch (_) {}
    }
    try {
      final cacheDirectory = await _managedCacheDirectory();
      await platform.setProperty('cache-dir', cacheDirectory.path);
    } catch (_) {}
  }

  Future<void> _applyPlaybackSettings(PlaybackSettings settings) async {
    final player = _player;
    if (player == null) return;
    try {
      await player.setRate(settings.playbackSpeed);
    } catch (_) {}
    await _applyLoudnessNormalization(settings.loudnessNormalization);
  }

  Future<void> _applyLoudnessNormalization(bool enabled) async {
    final player = _player;
    if (player == null) return;
    final platform = player.platform;
    if (platform is! mk.NativePlayer) return;
    try {
      await platform.setProperty(
        'af',
        enabled ? 'lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]' : '',
      );
    } catch (_) {}
  }

  Future<void> _tryBackupSource() async {
    final source = state.source;
    if (source == null || source.backupUrls.isEmpty) return;
    final player = _player;
    if (player == null) return;

    final current = source.url;
    final resumeAt = state.position;
    final candidate = source.backupUrls.firstWhere(
      (url) => url != current,
      orElse: () => source.backupUrls.first,
    );
    if (candidate == current) return;

    try {
      await player.open(
        mk.Media(candidate, httpHeaders: _biliPlaybackHeaders),
        play: true,
      );
      if (resumeAt > Duration.zero) {
        await player.seek(resumeAt);
      }
      state = state.copyWith(
        source: _sourceWithUrl(source, candidate),
        isBuffering: false,
      );
    } catch (error) {
      debugPrint('BiliTune backup stream retry failed: $error');
    }
  }

  Future<BiliPlaybackSource> _openPlaybackSource(
    BiliPlaybackSource source,
  ) async {
    final player = _ensurePlayer();
    await _playerConfiguration;

    final urls = <String>[
      source.url,
      ...source.backupUrls,
    ].where((url) => url.isNotEmpty).toSet();
    Object? lastError;
    for (final url in urls) {
      try {
        await player.open(
          mk.Media(
            url,
            httpHeaders: url.startsWith('file:') ? null : _biliPlaybackHeaders,
          ),
          play: true,
        );
        await _applyPlaybackSettings(ref.read(playbackSettingsProvider));
        return _sourceWithUrl(source, url);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('No playable stream URL returned.');
  }

  BiliPlaybackSource _sourceWithUrl(BiliPlaybackSource source, String url) {
    final backupUrls = <String>[source.url, ...source.backupUrls]
        .where((item) => item.isNotEmpty && item != url)
        .toSet()
        .toList(growable: false);
    return BiliPlaybackSource(
      url: url,
      backupUrls: backupUrls,
      qualityId: source.qualityId,
      label: source.label,
      codecs: source.codecs,
      bandwidth: source.bandwidth,
      mimeType: source.mimeType,
      expiresAt: source.expiresAt,
      isLossless: source.isLossless,
    );
  }

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final nextQueue = queue ?? state.queue;
    state = state.copyWith(
      track: track,
      queue: nextQueue.isEmpty ? <Track>[track] : nextQueue,
      source: null,
      position: Duration.zero,
      bufferAhead: Duration.zero,
      isBuffering: false,
      bufferingPercentage: 0,
      mediaDuration: null,
      isPlaying: true,
      liked: false,
      errorMessage: null,
    );
    unawaited(ref.read(libraryProvider.notifier).recordPlayback(track));

    if (!_hasResolvableSource(track)) {
      await _player?.stop();
      state = state.copyWith(isPlaying: false, errorMessage: '当前内容没有可播放源');
      return;
    }

    try {
      final source = await ref
          .read(biliMusicRepositoryProvider)
          .resolvePlaybackSource(
            track,
            quality: ref.read(playbackSettingsProvider).audioQuality,
          );
      final openedSource = await _openPlaybackSource(source);
      state = state.copyWith(source: openedSource, errorMessage: null);
    } catch (error) {
      state = state.copyWith(isPlaying: false, errorMessage: error.toString());
    }
  }

  Future<void> togglePlay() async {
    if (state.source != null) {
      await _ensurePlayer().playOrPause();
      return;
    }
    if (state.track == null) return;
    if (state.isPlaying) {
      state = state.copyWith(isPlaying: false);
      return;
    }
    await _resumePlaybackState(state.copyWith(isPlaying: true));
  }

  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    if (state.source != null) {
      await _ensurePlayer().seek(position);
    }
  }

  void seekFraction(double fraction) {
    final next = Duration(
      milliseconds: (state.duration.inMilliseconds * fraction.clamp(0.0, 1.0))
          .round(),
    );
    unawaited(seek(next));
  }

  void next() {
    final queue = state.queue;
    if (queue.isEmpty) return;
    final currentIndex = queue.indexWhere((item) => item.id == state.track?.id);
    if (currentIndex < 0) {
      unawaited(playTrack(queue.first, queue: queue));
      return;
    }
    final nextIndex = state.shuffle
        ? _randomQueueIndex(queue.length, currentIndex)
        : (currentIndex + 1) % queue.length;
    if (state.repeat == PlayRepeatMode.off &&
        currentIndex == queue.length - 1) {
      state = state.copyWith(isPlaying: false, position: state.duration);
      return;
    }
    unawaited(playTrack(queue[nextIndex], queue: queue));
  }

  void previous() {
    final queue = state.queue;
    if (queue.isEmpty) return;
    final currentIndex = queue.indexWhere((item) => item.id == state.track?.id);
    if (currentIndex < 0) {
      unawaited(playTrack(queue.first, queue: queue));
      return;
    }
    if (state.position > const Duration(seconds: 3)) {
      unawaited(seek(Duration.zero));
      return;
    }
    final previousIndex = (currentIndex - 1 + queue.length) % queue.length;
    unawaited(playTrack(queue[previousIndex], queue: queue));
  }

  Future<void> _resumePlaybackState(PlaybackState snapshot) async {
    final track = snapshot.track;
    if (track == null) return;
    final position = snapshot.position;
    final volume = snapshot.volume;
    final shuffle = snapshot.shuffle;
    final repeat = snapshot.repeat;
    final liked = snapshot.liked;
    final queue = snapshot.queue.isEmpty ? <Track>[track] : snapshot.queue;

    await playTrack(track, queue: queue);
    await _applyPlaybackSettings(ref.read(playbackSettingsProvider));
    setVolume(volume);
    if (position > Duration.zero) {
      await seek(position);
    }
    state = state.copyWith(shuffle: shuffle, repeat: repeat, liked: liked);
  }

  int _randomQueueIndex(int length, int currentIndex) {
    if (length <= 1) return 0;
    var nextIndex = _random.nextInt(length);
    if (nextIndex == currentIndex) {
      nextIndex = (nextIndex + 1) % length;
    }
    return nextIndex;
  }

  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);

  void cycleRepeat() {
    final order = PlayRepeatMode.values;
    state = state.copyWith(
      repeat: order[(state.repeat.index + 1) % order.length],
    );
  }

  void setVolume(double value) {
    final volume = value.clamp(0.0, 1.0);
    state = state.copyWith(volume: volume);
    if (state.source != null) {
      unawaited(_ensurePlayer().setVolume(volume * 100));
    }
  }

  void toggleLike() => state = state.copyWith(liked: !state.liked);

  void setLiked(bool value) => state = state.copyWith(liked: value);

  bool _hasResolvableSource(Track track) {
    return track.sourceUrl != null ||
        track.bvid != null ||
        track.aid != null ||
        track.audioId != null;
  }

  void _syncSystemMedia(PlaybackState playback) {
    SystemMediaControls.instance.sync(
      track: playback.track,
      queue: playback.queue,
      isPlaying: playback.isPlaying,
      isBuffering: playback.isBuffering,
      position: playback.position,
      duration: playback.duration,
      bufferedPosition: playback.bufferedPosition,
      shuffle: playback.shuffle,
      repeatMode: playback.repeat.name,
      errorMessage: playback.errorMessage,
    );
  }
}

final playbackProvider = NotifierProvider<PlaybackNotifier, PlaybackState>(
  PlaybackNotifier.new,
);

final nowPlayingLyricsProvider = FutureProvider<List<LyricLine>>((ref) async {
  if (_skipNetworkBootstrap) return const <LyricLine>[];
  final track = ref.watch(playbackProvider.select((state) => state.track));
  final sourcePreference = ref.watch(
    playbackSettingsProvider.select((state) => state.lyricsSourcePreference),
  );
  if (track == null) return const <LyricLine>[];
  return ref
      .read(biliMusicRepositoryProvider)
      .trackLyrics(track, sourcePreference: sourcePreference);
});

final nowPlayingRelatedProvider = FutureProvider<List<Track>>((ref) async {
  if (_skipNetworkBootstrap) return const <Track>[];
  final track = ref.watch(playbackProvider.select((state) => state.track));
  if (track == null) return const <Track>[];
  return ref.read(biliMusicRepositoryProvider).relatedTracks(track);
});
