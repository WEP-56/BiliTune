import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart' as audio;

import '../../data/models/models.dart';

class SystemMediaControls extends audio.BaseAudioHandler {
  SystemMediaControls._();

  static final instance = SystemMediaControls._();

  bool _initialized = false;
  Future<void> Function()? _onTogglePlay;
  Future<void> Function()? _onNext;
  Future<void> Function()? _onPrevious;
  Future<void> Function(Duration position)? _onSeek;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;
    await audio.AudioService.init(
      builder: () => this,
      config: const audio.AudioServiceConfig(
        androidNotificationChannelId: 'com.wep56.bilitune.playback',
        androidNotificationChannelName: 'BiliTune 播放',
        androidNotificationChannelDescription: 'BiliTune 后台播放控制',
        androidNotificationIcon: 'drawable/ic_stat_bilitune',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        preloadArtwork: true,
      ),
    );
    _initialized = true;
  }

  void bind({
    required Future<void> Function() onTogglePlay,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
    required Future<void> Function(Duration position) onSeek,
  }) {
    _onTogglePlay = onTogglePlay;
    _onNext = onNext;
    _onPrevious = onPrevious;
    _onSeek = onSeek;
  }

  void sync({
    required Track? track,
    required List<Track> queue,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required bool shuffle,
    required String repeatMode,
    String? errorMessage,
  }) {
    if (!_initialized) return;

    final mediaItems = queue.map(_toMediaItem).toList(growable: false);
    this.queue.add(mediaItems);
    mediaItem.add(track == null ? null : _toMediaItem(track));

    final queueIndex = track == null
        ? -1
        : queue.indexWhere((item) => item.id == track.id);

    playbackState.add(
      audio.PlaybackState(
        controls: [
          audio.MediaControl.skipToPrevious,
          isPlaying ? audio.MediaControl.pause : audio.MediaControl.play,
          audio.MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {audio.MediaAction.seek},
        processingState: errorMessage == null
            ? audio.AudioProcessingState.ready
            : audio.AudioProcessingState.error,
        playing: isPlaying,
        updatePosition: position,
        bufferedPosition: duration,
        speed: 1,
        queueIndex: queueIndex < 0 ? null : queueIndex,
        shuffleMode: shuffle
            ? audio.AudioServiceShuffleMode.all
            : audio.AudioServiceShuffleMode.none,
        repeatMode: switch (repeatMode) {
          'one' => audio.AudioServiceRepeatMode.one,
          'all' => audio.AudioServiceRepeatMode.all,
          _ => audio.AudioServiceRepeatMode.none,
        },
        errorMessage: errorMessage,
      ),
    );
  }

  audio.MediaItem _toMediaItem(Track track) {
    return audio.MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      duration: track.duration > Duration.zero ? track.duration : null,
      artUri: track.coverUrl == null ? null : Uri.tryParse(track.coverUrl!),
      extras: <String, Object?>{
        'bvid': track.bvid,
        'aid': track.aid,
        'cid': track.cid,
        'audioId': track.audioId,
      },
    );
  }

  @override
  Future<void> play() => _onTogglePlay?.call() ?? Future.value();

  @override
  Future<void> pause() => _onTogglePlay?.call() ?? Future.value();

  @override
  Future<void> skipToNext() => _onNext?.call() ?? Future.value();

  @override
  Future<void> skipToPrevious() => _onPrevious?.call() ?? Future.value();

  @override
  Future<void> seek(Duration position) =>
      _onSeek?.call(position) ?? Future.value();
}
