import 'package:flutter/foundation.dart';

/// Whether a piece of content is an audio-area track or a video (mv) track.
/// (design doc §15: BiliTune handles both audio区 and video稿件.)
enum ContentType { audio, video }

/// Cover shape encodes type at a glance (design doc §5): rounded-square for
/// content (album/playlist/track), circle for a creator (UP主).
enum CoverShape { square, circle }

/// A Bilibili creator (the analogue of an "artist").
@immutable
class UpUser {
  const UpUser({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;
}

/// A playable track — either an audio-area song or the audio of a video.
@immutable
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.type,
    required this.gradientSeed,
    this.coverUrl,
    this.playCount = 0,
  });

  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final ContentType type;

  /// Seed for the deterministic gradient placeholder used until a real cover
  /// URL is wired in (M4).
  final int gradientSeed;
  final String? coverUrl;
  final int playCount;
}

/// A card on a shelf: album, playlist, or creator. [shape] drives the cover.
@immutable
class CardItem {
  const CardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.gradientSeed,
    this.shape = CoverShape.square,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final int gradientSeed;
  final CoverShape shape;
  final String? coverUrl;
}

/// A horizontal row of cards on the discover page ("为你推荐", "热门音乐", …).
@immutable
class Shelf {
  const Shelf({required this.title, required this.items});

  final String title;
  final List<CardItem> items;
}
