import 'package:flutter/foundation.dart';

const _unset = Object();

/// Whether a piece of content is an audio-area track or a video (mv) track.
/// (design doc §15: BiliTune handles both audio区 and video稿件.)
enum ContentType { audio, video }

enum AudioQualityPreference { auto, lossless, high, medium, low }

extension AudioQualityPreferenceX on AudioQualityPreference {
  String get label => switch (this) {
    AudioQualityPreference.auto => '自动',
    AudioQualityPreference.lossless => '无损',
    AudioQualityPreference.high => '高品质',
    AudioQualityPreference.medium => '中等',
    AudioQualityPreference.low => '低品质',
  };

  String get description => switch (this) {
    AudioQualityPreference.auto => '自动选择最高音质',
    AudioQualityPreference.lossless => 'FLAC / Hi-Res',
    AudioQualityPreference.high => '180-320 kbps',
    AudioQualityPreference.medium => '100-140 kbps',
    AudioQualityPreference.low => '60-80 kbps',
  };
}

enum LyricsSourcePreference {
  auto,
  biliFirst,
  lrclibFirst,
  biliOnly,
  lrclibOnly,
}

extension LyricsSourcePreferenceX on LyricsSourcePreference {
  String get label => switch (this) {
    LyricsSourcePreference.auto => '自动',
    LyricsSourcePreference.biliFirst => 'Bilibili 优先',
    LyricsSourcePreference.lrclibFirst => 'LRCLIB 优先',
    LyricsSourcePreference.biliOnly => '仅 Bilibili',
    LyricsSourcePreference.lrclibOnly => '仅 LRCLIB',
  };

  String get description => switch (this) {
    LyricsSourcePreference.auto => '先用站内歌词，缺失时匹配 LRCLIB',
    LyricsSourcePreference.biliFirst => '优先使用 Bilibili 音频区歌词或字幕',
    LyricsSourcePreference.lrclibFirst => '优先按曲目信息匹配 LRCLIB',
    LyricsSourcePreference.biliOnly => '只显示 Bilibili 返回的歌词或字幕',
    LyricsSourcePreference.lrclibOnly => '只显示 LRCLIB 匹配结果',
  };
}

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
    this.bvid,
    this.aid,
    this.cid,
    this.audioId,
    this.webUrl,
    this.sourceUrl,
    this.sourceExpiresAt,
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
  final String? bvid;
  final int? aid;
  final int? cid;
  final int? audioId;
  final Uri? webUrl;
  final String? sourceUrl;
  final DateTime? sourceExpiresAt;

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    Duration? duration,
    ContentType? type,
    int? gradientSeed,
    String? coverUrl,
    int? playCount,
    String? bvid,
    int? aid,
    int? cid,
    int? audioId,
    Uri? webUrl,
    String? sourceUrl,
    DateTime? sourceExpiresAt,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      duration: duration ?? this.duration,
      type: type ?? this.type,
      gradientSeed: gradientSeed ?? this.gradientSeed,
      coverUrl: coverUrl ?? this.coverUrl,
      playCount: playCount ?? this.playCount,
      bvid: bvid ?? this.bvid,
      aid: aid ?? this.aid,
      cid: cid ?? this.cid,
      audioId: audioId ?? this.audioId,
      webUrl: webUrl ?? this.webUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceExpiresAt: sourceExpiresAt ?? this.sourceExpiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'artist': artist,
      'durationMs': duration.inMilliseconds,
      'type': type.name,
      'gradientSeed': gradientSeed,
      'coverUrl': coverUrl,
      'playCount': playCount,
      'bvid': bvid,
      'aid': aid,
      'cid': cid,
      'audioId': audioId,
      'webUrl': webUrl?.toString(),
      'sourceUrl': sourceUrl,
      'sourceExpiresAt': sourceExpiresAt?.millisecondsSinceEpoch,
    };
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final webUrl = json['webUrl']?.toString();
    final sourceExpiresAt = (json['sourceExpiresAt'] as num?)?.toInt();
    return Track(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      duration: Duration(
        milliseconds:
            (json['durationMs'] as num?)?.toInt() ??
            (json['duration'] as num?)?.toInt() ??
            0,
      ),
      type: (json['type']?.toString() ?? '') == ContentType.video.name
          ? ContentType.video
          : ContentType.audio,
      gradientSeed: (json['gradientSeed'] as num?)?.toInt() ?? 0,
      coverUrl: json['coverUrl']?.toString(),
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      bvid: json['bvid']?.toString(),
      aid: (json['aid'] as num?)?.toInt(),
      cid: (json['cid'] as num?)?.toInt(),
      audioId: (json['audioId'] as num?)?.toInt(),
      webUrl: webUrl == null || webUrl.isEmpty ? null : Uri.tryParse(webUrl),
      sourceUrl: json['sourceUrl']?.toString(),
      sourceExpiresAt: sourceExpiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(sourceExpiresAt),
    );
  }
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
    this.type,
    this.duration,
    this.playCount = 0,
    this.bvid,
    this.aid,
    this.cid,
    this.audioId,
    this.artist,
  });

  final String id;
  final String title;
  final String subtitle;
  final int gradientSeed;
  final CoverShape shape;
  final String? coverUrl;
  final ContentType? type;
  final Duration? duration;
  final int playCount;
  final String? bvid;
  final int? aid;
  final int? cid;
  final int? audioId;
  final String? artist;
}

/// A horizontal row of cards on the discover page ("为你推荐", "热门音乐", …).
@immutable
class Shelf {
  const Shelf({required this.title, required this.items});

  final String title;
  final List<CardItem> items;
}

@immutable
class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}

@immutable
class BiliCredential {
  const BiliCredential({
    this.sessdata,
    this.biliJct,
    this.dedeUserId,
    this.acTimeValue,
    this.mid,
    this.vipStatus,
    this.cookieHeader,
  });

  final String? sessdata;
  final String? biliJct;
  final String? dedeUserId;
  final String? acTimeValue;
  final int? mid;
  final int? vipStatus;
  final String? cookieHeader;

  bool get isSignedIn =>
      (sessdata?.isNotEmpty ?? false) || (cookieHeader?.isNotEmpty ?? false);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessdata': sessdata,
    'biliJct': biliJct,
    'dedeUserId': dedeUserId,
    'acTimeValue': acTimeValue,
    'mid': mid,
    'vipStatus': vipStatus,
    'cookieHeader': cookieHeader,
  };

  factory BiliCredential.fromJson(Map<String, dynamic> json) {
    return BiliCredential(
      sessdata: json['sessdata'] as String?,
      biliJct: json['biliJct'] as String?,
      dedeUserId: json['dedeUserId'] as String?,
      acTimeValue: json['acTimeValue'] as String?,
      mid: (json['mid'] as num?)?.toInt(),
      vipStatus: (json['vipStatus'] as num?)?.toInt(),
      cookieHeader: json['cookieHeader'] as String?,
    );
  }

  BiliCredential copyWith({
    String? sessdata,
    String? biliJct,
    String? dedeUserId,
    String? acTimeValue,
    int? mid,
    int? vipStatus,
    String? cookieHeader,
  }) {
    return BiliCredential(
      sessdata: sessdata ?? this.sessdata,
      biliJct: biliJct ?? this.biliJct,
      dedeUserId: dedeUserId ?? this.dedeUserId,
      acTimeValue: acTimeValue ?? this.acTimeValue,
      mid: mid ?? this.mid,
      vipStatus: vipStatus ?? this.vipStatus,
      cookieHeader: cookieHeader ?? this.cookieHeader,
    );
  }
}

@immutable
class BiliAccount {
  const BiliAccount({
    required this.mid,
    required this.name,
    this.avatarUrl,
    this.vipStatus = 0,
  });

  final int mid;
  final String name;
  final String? avatarUrl;
  final int vipStatus;

  bool get isVip => vipStatus > 0;

  factory BiliAccount.fromNavJson(Map<String, dynamic> json) {
    return BiliAccount(
      mid: (json['mid'] as num?)?.toInt() ?? 0,
      name: json['uname']?.toString() ?? '',
      avatarUrl: json['face']?.toString(),
      vipStatus:
          (json['vipStatus'] as num?)?.toInt() ??
          (json['vip'] is Map
              ? ((json['vip'] as Map)['status'] as num?)?.toInt()
              : null) ??
          0,
    );
  }
}

@immutable
class BiliPlaybackSource {
  const BiliPlaybackSource({
    required this.url,
    this.backupUrls = const <String>[],
    this.qualityId,
    this.label,
    this.codecs,
    this.bandwidth,
    this.mimeType,
    this.expiresAt,
    this.isLossless = false,
  });

  final String url;
  final List<String> backupUrls;
  final int? qualityId;
  final String? label;
  final String? codecs;
  final int? bandwidth;
  final String? mimeType;
  final DateTime? expiresAt;
  final bool isLossless;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      'backupUrls': backupUrls,
      'qualityId': qualityId,
      'label': label,
      'codecs': codecs,
      'bandwidth': bandwidth,
      'mimeType': mimeType,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'isLossless': isLossless,
    };
  }

  factory BiliPlaybackSource.fromJson(Map<String, dynamic> json) {
    final expiresAt = (json['expiresAt'] as num?)?.toInt();
    return BiliPlaybackSource(
      url: json['url']?.toString() ?? '',
      backupUrls:
          (json['backupUrls'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      qualityId: (json['qualityId'] as num?)?.toInt(),
      label: json['label']?.toString(),
      codecs: json['codecs']?.toString(),
      bandwidth: (json['bandwidth'] as num?)?.toInt(),
      mimeType: json['mimeType']?.toString(),
      expiresAt: expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAt),
      isLossless: json['isLossless'] == true,
    );
  }
}

@immutable
class BiliFavoriteFolder {
  const BiliFavoriteFolder({
    required this.mediaId,
    required this.fid,
    required this.mid,
    required this.title,
    required this.mediaCount,
    required this.gradientSeed,
    this.attr = 0,
    this.favState = 0,
    this.isPublic = true,
    this.coverUrl,
    this.intro,
  });

  final int mediaId;
  final int fid;
  final int mid;
  final String title;
  final int mediaCount;
  final int gradientSeed;
  final int attr;
  final int favState;
  final bool isPublic;
  final String? coverUrl;
  final String? intro;

  String get subtitle => '$mediaCount 首';

  CardItem toCardItem() {
    return CardItem(
      id: mediaId.toString(),
      title: title,
      subtitle: subtitle,
      gradientSeed: gradientSeed,
      coverUrl: coverUrl,
    );
  }
}

enum DownloadTaskStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

extension DownloadTaskStatusX on DownloadTaskStatus {
  String get nameValue => switch (this) {
    DownloadTaskStatus.queued => 'queued',
    DownloadTaskStatus.downloading => 'downloading',
    DownloadTaskStatus.paused => 'paused',
    DownloadTaskStatus.completed => 'completed',
    DownloadTaskStatus.failed => 'failed',
    DownloadTaskStatus.cancelled => 'cancelled',
  };
}

DownloadTaskStatus _downloadTaskStatusFromName(String value) {
  return switch (value) {
    'downloading' => DownloadTaskStatus.downloading,
    'paused' => DownloadTaskStatus.paused,
    'completed' => DownloadTaskStatus.completed,
    'failed' => DownloadTaskStatus.failed,
    'cancelled' => DownloadTaskStatus.cancelled,
    _ => DownloadTaskStatus.queued,
  };
}

@immutable
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.title,
    required this.artist,
    required this.type,
    required this.gradientSeed,
    required this.createdAt,
    this.coverUrl,
    this.bvid,
    this.aid,
    this.cid,
    this.audioId,
    this.outputFileType = 'audio',
    this.audioCodecs,
    this.audioBandwidth,
    this.videoResolution,
    this.videoFrameRate,
    this.savePath,
    this.totalBytes,
    this.downloadedBytes = 0,
    this.status = DownloadTaskStatus.queued,
    this.errorMessage,
  });

  final String id;
  final String title;
  final String artist;
  final ContentType type;
  final int gradientSeed;
  final DateTime createdAt;
  final String? coverUrl;
  final String? bvid;
  final int? aid;
  final int? cid;
  final int? audioId;
  final String outputFileType;
  final String? audioCodecs;
  final int? audioBandwidth;
  final String? videoResolution;
  final String? videoFrameRate;
  final String? savePath;
  final int? totalBytes;
  final int downloadedBytes;
  final DownloadTaskStatus status;
  final String? errorMessage;

  double get progress {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return status == DownloadTaskStatus.completed ? 1 : 0;
    }
    return (downloadedBytes / total).clamp(0.0, 1.0);
  }

  bool get isDone => status == DownloadTaskStatus.completed;

  DownloadTask copyWith({
    String? id,
    String? title,
    String? artist,
    ContentType? type,
    int? gradientSeed,
    DateTime? createdAt,
    Object? coverUrl = _unset,
    Object? bvid = _unset,
    Object? aid = _unset,
    Object? cid = _unset,
    Object? audioId = _unset,
    String? outputFileType,
    Object? audioCodecs = _unset,
    Object? audioBandwidth = _unset,
    Object? videoResolution = _unset,
    Object? videoFrameRate = _unset,
    Object? savePath = _unset,
    Object? totalBytes = _unset,
    int? downloadedBytes,
    DownloadTaskStatus? status,
    Object? errorMessage = _unset,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      type: type ?? this.type,
      gradientSeed: gradientSeed ?? this.gradientSeed,
      createdAt: createdAt ?? this.createdAt,
      coverUrl: identical(coverUrl, _unset)
          ? this.coverUrl
          : coverUrl as String?,
      bvid: identical(bvid, _unset) ? this.bvid : bvid as String?,
      aid: identical(aid, _unset) ? this.aid : aid as int?,
      cid: identical(cid, _unset) ? this.cid : cid as int?,
      audioId: identical(audioId, _unset) ? this.audioId : audioId as int?,
      outputFileType: outputFileType ?? this.outputFileType,
      audioCodecs: identical(audioCodecs, _unset)
          ? this.audioCodecs
          : audioCodecs as String?,
      audioBandwidth: identical(audioBandwidth, _unset)
          ? this.audioBandwidth
          : audioBandwidth as int?,
      videoResolution: identical(videoResolution, _unset)
          ? this.videoResolution
          : videoResolution as String?,
      videoFrameRate: identical(videoFrameRate, _unset)
          ? this.videoFrameRate
          : videoFrameRate as String?,
      savePath: identical(savePath, _unset)
          ? this.savePath
          : savePath as String?,
      totalBytes: identical(totalBytes, _unset)
          ? this.totalBytes
          : totalBytes as int?,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'artist': artist,
      'type': type.name,
      'gradientSeed': gradientSeed,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'coverUrl': coverUrl,
      'bvid': bvid,
      'aid': aid,
      'cid': cid,
      'audioId': audioId,
      'outputFileType': outputFileType,
      'audioCodecs': audioCodecs,
      'audioBandwidth': audioBandwidth,
      'videoResolution': videoResolution,
      'videoFrameRate': videoFrameRate,
      'savePath': savePath,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'status': status.nameValue,
      'errorMessage': errorMessage,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      type: (json['type']?.toString() ?? '') == ContentType.video.name
          ? ContentType.video
          : ContentType.audio,
      gradientSeed: (json['gradientSeed'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
      coverUrl: json['coverUrl']?.toString(),
      bvid: json['bvid']?.toString(),
      aid: (json['aid'] as num?)?.toInt(),
      cid: (json['cid'] as num?)?.toInt(),
      audioId: (json['audioId'] as num?)?.toInt(),
      outputFileType: json['outputFileType']?.toString() ?? 'audio',
      audioCodecs: json['audioCodecs']?.toString(),
      audioBandwidth: (json['audioBandwidth'] as num?)?.toInt(),
      videoResolution: json['videoResolution']?.toString(),
      videoFrameRate: json['videoFrameRate']?.toString(),
      savePath: json['savePath']?.toString(),
      totalBytes: (json['totalBytes'] as num?)?.toInt(),
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      status: _downloadTaskStatusFromName(json['status']?.toString() ?? ''),
      errorMessage: json['errorMessage']?.toString(),
    );
  }

  static DownloadTask fromTrack(
    Track track, {
    String outputFileType = 'audio',
    String? savePath,
  }) {
    return DownloadTask(
      id: '${track.id}-${DateTime.now().millisecondsSinceEpoch}',
      title: track.title,
      artist: track.artist,
      type: track.type,
      gradientSeed: track.gradientSeed,
      createdAt: DateTime.now(),
      coverUrl: track.coverUrl,
      bvid: track.bvid,
      aid: track.aid,
      cid: track.cid,
      audioId: track.audioId,
      outputFileType: outputFileType,
      totalBytes: null,
      savePath: savePath,
    );
  }
}
