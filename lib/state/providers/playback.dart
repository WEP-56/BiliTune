part of '../providers.dart';

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
  Timer? _playbackPersistTimer;
  Timer? _systemMediaSyncTimer;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _random = Random();
  mk.Player? _player;
  Future<void>? _playerConfiguration;
  DateTime? _lastPlaybackPersistAt;
  DateTime? _lastSystemMediaSyncAt;
  bool _handledBootstrap = false;

  @override
  PlaybackState build() {
    final initial =
        ref.read(playbackBootstrapProvider) ?? const PlaybackState();
    ref.listen<PlaybackSettings>(playbackSettingsProvider, (previous, next) {
      if (previous?.playbackSpeed != next.playbackSpeed) {
        unawaited(_applyPlaybackSettings(next));
      }
    });
    listenSelf((previous, next) {
      _syncSystemMediaThrottled(previous, next);
      _persistPlaybackStateThrottled(previous, next);
    });
    SystemMediaControls.instance.bind(
      onTogglePlay: togglePlay,
      onNext: () async => next(),
      onPrevious: () async => previous(),
      onSeek: seek,
    );

    ref.onDispose(() {
      _bufferingFallbackTimer?.cancel();
      _playbackPersistTimer?.cancel();
      _systemMediaSyncTimer?.cancel();
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
    });

    if (!_handledBootstrap) {
      _handledBootstrap = true;
      unawaited(Future<void>.microtask(() => _syncSystemMediaNow(initial)));
      if (initial.isPlaying && initial.track != null) {
        unawaited(Future<void>.microtask(() => _resumePlaybackState(initial)));
      }
    }
    return initial;
  }

  void _persistPlaybackStateThrottled(
    PlaybackState? previous,
    PlaybackState playback,
  ) {
    if (_skipNetworkBootstrap) return;

    if (_shouldPersistPlaybackImmediately(previous, playback)) {
      _playbackPersistTimer?.cancel();
      _playbackPersistTimer = null;
      unawaited(_persistPlaybackStateNow(playback));
      return;
    }

    final now = DateTime.now();
    final last = _lastPlaybackPersistAt;
    if (last == null || now.difference(last) >= _playbackPersistInterval) {
      unawaited(_persistPlaybackStateNow(playback));
      return;
    }

    _playbackPersistTimer ??= Timer(
      _playbackPersistInterval - now.difference(last),
      () {
        _playbackPersistTimer = null;
        unawaited(_persistPlaybackStateNow(state));
      },
    );
  }

  bool _shouldPersistPlaybackImmediately(
    PlaybackState? previous,
    PlaybackState playback,
  ) {
    if (previous == null) return true;
    return previous.track?.id != playback.track?.id ||
        previous.source?.url != playback.source?.url ||
        _queueKey(previous.queue) != _queueKey(playback.queue) ||
        previous.isPlaying != playback.isPlaying ||
        previous.shuffle != playback.shuffle ||
        previous.repeat != playback.repeat ||
        previous.volume != playback.volume ||
        previous.liked != playback.liked ||
        previous.errorMessage != playback.errorMessage;
  }

  Future<void> _persistPlaybackStateNow(PlaybackState playback) async {
    if (_skipNetworkBootstrap) return;
    _lastPlaybackPersistAt = DateTime.now();
    try {
      await ref
          .read(appLocalStoreProvider)
          .savePlaybackState(playback.toJson());
    } catch (_) {}
  }

  Future<void> saveNow() {
    _playbackPersistTimer?.cancel();
    _playbackPersistTimer = null;
    return _persistPlaybackStateNow(state);
  }

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
    try {
      await platform.setProperty('af', '');
    } catch (_) {}
  }

  Future<void> _applyPlaybackSettings(PlaybackSettings settings) async {
    final player = _player;
    if (player == null) return;
    try {
      await player.setRate(settings.playbackSpeed);
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

  void _syncSystemMediaThrottled(
    PlaybackState? previous,
    PlaybackState playback,
  ) {
    if (_shouldSyncSystemMediaImmediately(previous, playback)) {
      _systemMediaSyncTimer?.cancel();
      _systemMediaSyncTimer = null;
      _syncSystemMediaNow(playback);
      return;
    }

    final now = DateTime.now();
    final last = _lastSystemMediaSyncAt;
    if (last == null || now.difference(last) >= _systemMediaSyncInterval) {
      _syncSystemMediaNow(playback);
      return;
    }

    _systemMediaSyncTimer ??= Timer(
      _systemMediaSyncInterval - now.difference(last),
      () {
        _systemMediaSyncTimer = null;
        _syncSystemMediaNow(state);
      },
    );
  }

  bool _shouldSyncSystemMediaImmediately(
    PlaybackState? previous,
    PlaybackState playback,
  ) {
    if (previous == null) return true;
    return previous.track?.id != playback.track?.id ||
        _queueKey(previous.queue) != _queueKey(playback.queue) ||
        previous.isPlaying != playback.isPlaying ||
        previous.isBuffering != playback.isBuffering ||
        previous.mediaDuration != playback.mediaDuration ||
        previous.shuffle != playback.shuffle ||
        previous.repeat != playback.repeat ||
        previous.errorMessage != playback.errorMessage;
  }

  void _syncSystemMediaNow(PlaybackState playback) {
    _lastSystemMediaSyncAt = DateTime.now();
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

  String _queueKey(List<Track> queue) =>
      queue.map((track) => track.id).join('\u001f');
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
