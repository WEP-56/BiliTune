part of '../providers.dart';

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
      final musicShelves = await repository.musicShelves();
      final shelves = musicShelves.isNotEmpty
          ? musicShelves
          : await repository.discoverShelves();
      final shelfFeaturedTracks = _tracksFromShelves(musicShelves);
      final musicFeaturedTracks = shelfFeaturedTracks.isNotEmpty
          ? shelfFeaturedTracks
          : await repository.musicFeaturedTracks();
      final fallbackFeaturedTrack = musicFeaturedTracks.isEmpty
          ? await repository.discoverFeaturedTrack()
          : null;
      final featuredTrack = musicFeaturedTracks.isNotEmpty
          ? musicFeaturedTracks.first
          : fallbackFeaturedTrack;
      final featuredKeyword = await repository.discoverFeaturedKeyword();
      final quickPicks = await _quickPicks(
        repository,
        recentHistory: recentHistory,
        featuredKeyword: featuredKeyword,
      );
      state = state.copyWith(
        featuredTrack: featuredTrack,
        featuredTracks: musicFeaturedTracks.isNotEmpty
            ? musicFeaturedTracks
            : [?fallbackFeaturedTrack],
        featuredKeyword: featuredKeyword,
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

  Future<List<String>> _quickPicks(
    BiliMusicRepository repository, {
    required List<String> recentHistory,
    required String? featuredKeyword,
  }) async {
    final picks = <String>[];
    if (featuredKeyword != null && featuredKeyword.isNotEmpty) {
      picks.add(featuredKeyword);
    }

    try {
      picks.addAll(await repository.hotWords());
    } catch (_) {}

    for (final word in recentHistory) {
      final trimmed = word.trim();
      if (trimmed.isEmpty || picks.contains(trimmed)) continue;
      picks.add(trimmed);
    }

    return picks.take(12).toList(growable: false);
  }

  List<Track> _tracksFromShelves(List<Shelf> shelves) {
    if (shelves.isEmpty) return const <Track>[];
    return shelves.first.items
        .where(
          (item) =>
              item.bvid != null ||
              item.aid != null ||
              item.cid != null ||
              item.audioId != null,
        )
        .map(_trackFromCardItem)
        .take(5)
        .toList(growable: false);
  }

  Track _trackFromCardItem(CardItem item) {
    return Track(
      id: item.id,
      title: item.title,
      artist: item.artist ?? item.subtitle,
      duration: item.duration ?? Duration.zero,
      type: item.type ?? ContentType.video,
      gradientSeed: item.gradientSeed,
      coverUrl: item.coverUrl,
      playCount: item.playCount,
      bvid: item.bvid,
      aid: item.aid,
      cid: item.cid,
      audioId: item.audioId,
      webUrl: item.bvid == null
          ? null
          : Uri.parse('https://www.bilibili.com/video/${item.bvid}'),
    );
  }
}

final discoverProvider = NotifierProvider<DiscoverNotifier, DiscoverState>(
  DiscoverNotifier.new,
);
