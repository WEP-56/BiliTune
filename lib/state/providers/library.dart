part of '../providers.dart';

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
