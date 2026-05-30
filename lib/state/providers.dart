import 'dart:async';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/bili_cookie_store.dart';
import '../core/network/bili_dio.dart';
import '../core/network/bili_wbi_signer.dart';
import '../data/local/app_local_store.dart';
import '../data/mock/mock_data.dart';
import '../data/models/models.dart';
import '../data/repositories/bili_auth_repository.dart';
import '../data/repositories/bili_music_repository.dart';
import '../data/services/bili_api_service.dart';

const _unset = Object();

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

final mediaPlayerProvider = Provider<mk.Player>((ref) {
  mk.MediaKit.ensureInitialized();
  final player = mk.Player();
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

@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.defaultKeyword,
    this.results = const <Track>[],
    this.hotWords = const <String>[],
    this.suggestions = const <String>[],
    this.history = const <String>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final String query;
  final String? defaultKeyword;
  final List<Track> results;
  final List<String> hotWords;
  final List<String> suggestions;
  final List<String> history;
  final bool isLoading;
  final String? errorMessage;

  SearchState copyWith({
    String? query,
    Object? defaultKeyword = _unset,
    List<Track>? results,
    List<String>? hotWords,
    List<String>? suggestions,
    List<String>? history,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return SearchState(
      query: query ?? this.query,
      defaultKeyword: identical(defaultKeyword, _unset)
          ? this.defaultKeyword
          : defaultKeyword as String?,
      results: results ?? this.results,
      hotWords: hotWords ?? this.hotWords,
      suggestions: suggestions ?? this.suggestions,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
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
      final hotWords = await repository.hotWords();
      state = state.copyWith(
        defaultKeyword: defaultKeyword,
        hotWords: hotWords.take(12).toList(growable: false),
      );
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> search(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      state = state.copyWith(query: '', results: const <Track>[]);
      return;
    }

    state = state.copyWith(query: keyword, isLoading: true, errorMessage: null);

    try {
      final results = await ref
          .read(biliMusicRepositoryProvider)
          .searchTracks(keyword);
      final history = <String>[
        keyword,
        ...state.history.where((item) => item != keyword),
      ].take(20).toList(growable: false);
      await ref.read(appLocalStoreProvider).saveSearchHistory(history);
      state = state.copyWith(
        results: results,
        history: history,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
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
    this.featuredKeyword,
    this.quickPicks = const <String>[],
    this.shelves = const <Shelf>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final Track? featuredTrack;
  final String? featuredKeyword;
  final List<String> quickPicks;
  final List<Shelf> shelves;
  final bool isLoading;
  final String? errorMessage;

  DiscoverState copyWith({
    Object? featuredTrack = _unset,
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
    }
    return const DiscoverState();
  }

  Future<void> _bootstrap() async {
    state = const DiscoverState(isLoading: true);
    try {
      final repository = ref.read(biliMusicRepositoryProvider);
      final local = ref.read(appLocalStoreProvider);
      final recentHistory = await local.readSearchHistory();
      final featuredTrack = await repository.discoverFeaturedTrack();
      final shelves = await repository.discoverShelves();
      final quickPicks = await repository.discoverQuickPicks(
        recentHistory: recentHistory,
      );
      state = state.copyWith(
        featuredTrack: featuredTrack,
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
    this.isLoading = false,
    this.errorMessage,
  });

  final List<BiliFavoriteFolder> folders;
  final int? selectedFolderId;
  final List<Track> selectedFolderTracks;
  final List<Track> recentHistory;
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
    final signedIn = ref.watch(
      authProvider.select((state) => state.isSignedIn),
    );
    if (_lastSignedIn != signedIn) {
      _lastSignedIn = signedIn;
      _bootstrapped = false;
      if (!signedIn) {
        state = const LibraryState();
        return const LibraryState();
      }
    }

    if (!_bootstrapped && signedIn && !_skipNetworkBootstrap) {
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
      final credential = auth.credential;
      final mid = credential?.mid ?? auth.account?.mid;

      final folders = mid == null
          ? const <BiliFavoriteFolder>[]
          : await repository.favoriteFolders(mid);
      final selectedFolderId = folders.isEmpty ? null : folders.first.mediaId;
      final selectedFolderTracks = selectedFolderId == null
          ? const <Track>[]
          : await repository.favoriteFolderTracks(selectedFolderId);
      final recentHistory = await _loadHistory(repository);
      state = state.copyWith(
        folders: folders,
        selectedFolderId: selectedFolderId,
        selectedFolderTracks: selectedFolderTracks,
        recentHistory: recentHistory,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<List<Track>> _loadHistory(BiliMusicRepository repository) async {
    try {
      return await repository.historyTracks();
    } catch (_) {
      return const <Track>[];
    }
  }

  Future<void> selectFolder(int mediaId) async {
    state = state.copyWith(selectedFolderId: mediaId, isLoading: true);
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

  Future<void> refresh() async {
    _bootstrapped = false;
    await _bootstrap();
  }
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

  @override
  DownloadQueueState build() {
    if (!_bootstrapped && !_skipNetworkBootstrap) {
      _bootstrapped = true;
      unawaited(_bootstrap());
    }
    return const DownloadQueueState();
  }

  Future<void> _bootstrap() async {
    state = const DownloadQueueState(isLoading: true);
    try {
      final tasks = await ref.read(appLocalStoreProvider).readDownloadTasks();
      state = state.copyWith(tasks: tasks, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> enqueueTrack(
    Track track, {
    String outputFileType = 'audio',
    String? savePath,
  }) async {
    final task = DownloadTask.fromTrack(
      track,
      outputFileType: outputFileType,
      savePath: savePath,
    );
    final tasks = <DownloadTask>[task, ...state.tasks];
    await _persist(tasks);
    state = state.copyWith(tasks: tasks, errorMessage: null);
  }

  Future<void> pauseTask(String id) async => _updateTask(
    id,
    (task) => task.copyWith(status: DownloadTaskStatus.paused),
  );

  Future<void> resumeTask(String id) async => _updateTask(
    id,
    (task) => task.copyWith(status: DownloadTaskStatus.queued),
  );

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
    final tasks = state.tasks
        .where((task) => task.id != id)
        .toList(growable: false);
    await _persist(tasks);
    state = state.copyWith(tasks: tasks);
  }

  Future<void> clear() async {
    await _persist(const <DownloadTask>[]);
    state = state.copyWith(tasks: const <DownloadTask>[]);
  }

  Future<void> refresh() async {
    _bootstrapped = false;
    await _bootstrap();
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

  PlaybackState copyWith({
    Object? track = _unset,
    List<Track>? queue,
    Object? source = _unset,
    bool? isPlaying,
    Duration? position,
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
}

class PlaybackNotifier extends Notifier<PlaybackState> {
  Timer? _mockTimer;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _random = Random();
  mk.Player? _player;

  @override
  PlaybackState build() {
    _mockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickMock());
    ref.onDispose(() {
      _mockTimer?.cancel();
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
    });

    return PlaybackState(track: MockData.nowPlaying, queue: MockData.tracks);
  }

  mk.Player _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;

    final player = ref.read(mediaPlayerProvider);
    _player = player;

    _subscriptions.addAll([
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
    return player;
  }

  void _tickMock() {
    if (!state.isPlaying || state.track == null || state.source != null) return;
    final nextPosition = state.position + const Duration(seconds: 1);
    if (nextPosition >= state.duration) {
      if (state.repeat == PlayRepeatMode.one) {
        state = state.copyWith(position: Duration.zero);
      } else {
        next();
      }
    } else {
      state = state.copyWith(position: nextPosition);
    }
  }

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final nextQueue = queue ?? state.queue;
    state = state.copyWith(
      track: track,
      queue: nextQueue.isEmpty ? <Track>[track] : nextQueue,
      source: null,
      position: Duration.zero,
      mediaDuration: null,
      isPlaying: true,
      liked: false,
      errorMessage: null,
    );

    if (!_hasResolvableSource(track)) {
      await _player?.stop();
      return;
    }

    try {
      final source = await ref
          .read(biliMusicRepositoryProvider)
          .resolvePlaybackSource(track);
      state = state.copyWith(source: source, errorMessage: null);
      await _ensurePlayer().open(
        mk.Media(
          source.url,
          httpHeaders: const <String, String>{
            'User-Agent': biliUserAgent,
            'Referer': biliReferer,
            'Origin': 'https://www.bilibili.com',
          },
        ),
        play: true,
      );
    } catch (error) {
      state = state.copyWith(isPlaying: false, errorMessage: error.toString());
    }
  }

  Future<void> togglePlay() async {
    if (state.source != null) {
      await _ensurePlayer().playOrPause();
      return;
    }
    state = state.copyWith(isPlaying: !state.isPlaying);
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
    final queue = state.queue.isEmpty ? MockData.tracks : state.queue;
    final currentIndex = queue.indexWhere((item) => item.id == state.track?.id);
    final nextIndex = state.shuffle
        ? _random.nextInt(queue.length)
        : (currentIndex + 1) % queue.length;
    if (state.repeat == PlayRepeatMode.off &&
        currentIndex == queue.length - 1) {
      state = state.copyWith(isPlaying: false, position: state.duration);
      return;
    }
    unawaited(playTrack(queue[nextIndex], queue: queue));
  }

  void previous() {
    if (state.position > const Duration(seconds: 3)) {
      unawaited(seek(Duration.zero));
      return;
    }
    final queue = state.queue.isEmpty ? MockData.tracks : state.queue;
    final currentIndex = queue.indexWhere((item) => item.id == state.track?.id);
    final previousIndex = (currentIndex - 1 + queue.length) % queue.length;
    unawaited(playTrack(queue[previousIndex], queue: queue));
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

  bool _hasResolvableSource(Track track) {
    return track.sourceUrl != null ||
        track.bvid != null ||
        track.aid != null ||
        track.audioId != null;
  }
}

final playbackProvider = NotifierProvider<PlaybackNotifier, PlaybackState>(
  PlaybackNotifier.new,
);
