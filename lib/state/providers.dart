import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/mock_data.dart';
import '../data/models/models.dart';

// ─────────────────────────────────────────────────────────────────────────
// Theme mode
// ─────────────────────────────────────────────────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

  void set(ThemeMode mode) => state = mode;
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ─────────────────────────────────────────────────────────────────────────
// Sidebar collapse (desktop)
// ─────────────────────────────────────────────────────────────────────────

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
        SidebarCollapsedNotifier.new);

/// Whether the desktop "Now Playing" right panel is expanded (design doc §6.4).
class NowPlayingOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final nowPlayingOpenProvider =
    NotifierProvider<NowPlayingOpenNotifier, bool>(NowPlayingOpenNotifier.new);

// ─────────────────────────────────────────────────────────────────────────
// Playback (mock)
// ─────────────────────────────────────────────────────────────────────────

enum PlayRepeatMode { off, all, one }

@immutable
class PlaybackState {
  const PlaybackState({
    this.track,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.shuffle = false,
    this.repeat = PlayRepeatMode.off,
    this.volume = 0.7,
    this.liked = false,
  });

  final Track? track;
  final bool isPlaying;
  final Duration position;
  final bool shuffle;
  final PlayRepeatMode repeat;
  final double volume;
  final bool liked;

  Duration get duration => track?.duration ?? Duration.zero;

  double get progress {
    final total = duration.inMilliseconds;
    if (total == 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  PlaybackState copyWith({
    Track? track,
    bool? isPlaying,
    Duration? position,
    bool? shuffle,
    PlayRepeatMode? repeat,
    double? volume,
    bool? liked,
  }) {
    return PlaybackState(
      track: track ?? this.track,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      volume: volume ?? this.volume,
      liked: liked ?? this.liked,
    );
  }
}

/// Mock playback engine: advances position on a 1s timer so the play bar and
/// progress UI animate. Real audio (just_audio + audio_service) replaces this
/// in M2/M3 behind the same surface.
class PlaybackNotifier extends Notifier<PlaybackState> {
  Timer? _timer;

  @override
  PlaybackState build() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    ref.onDispose(() => _timer?.cancel());
    return PlaybackState(track: MockData.nowPlaying);
  }

  void _tick() {
    if (!state.isPlaying || state.track == null) return;
    final next = state.position + const Duration(seconds: 1);
    if (next >= state.duration) {
      if (state.repeat == PlayRepeatMode.one) {
        state = state.copyWith(position: Duration.zero);
      } else {
        this.next();
      }
    } else {
      state = state.copyWith(position: next);
    }
  }

  void playTrack(Track track) {
    state = state.copyWith(
        track: track, position: Duration.zero, isPlaying: true, liked: false);
  }

  void togglePlay() => state = state.copyWith(isPlaying: !state.isPlaying);

  void seek(Duration position) => state = state.copyWith(position: position);

  void seekFraction(double fraction) => seek(Duration(
      milliseconds:
          (state.duration.inMilliseconds * fraction.clamp(0.0, 1.0)).round()));

  void next() {
    final list = MockData.tracks;
    final i = list.indexWhere((t) => t.id == state.track?.id);
    final nextIndex = state.shuffle
        ? (i + 3) % list.length
        : (i + 1) % list.length;
    state = state.copyWith(
        track: list[nextIndex], position: Duration.zero, liked: false);
  }

  void previous() {
    if (state.position > const Duration(seconds: 3)) {
      seek(Duration.zero);
      return;
    }
    final list = MockData.tracks;
    final i = list.indexWhere((t) => t.id == state.track?.id);
    final prevIndex = (i - 1 + list.length) % list.length;
    state = state.copyWith(
        track: list[prevIndex], position: Duration.zero, liked: false);
  }

  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);

  void cycleRepeat() {
    final order = PlayRepeatMode.values;
    state = state.copyWith(
        repeat: order[(state.repeat.index + 1) % order.length]);
  }

  void setVolume(double v) => state = state.copyWith(volume: v.clamp(0.0, 1.0));

  void toggleLike() => state = state.copyWith(liked: !state.liked);
}

final playbackProvider =
    NotifierProvider<PlaybackNotifier, PlaybackState>(PlaybackNotifier.new);
