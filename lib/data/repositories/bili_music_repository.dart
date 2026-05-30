import '../../core/utils/format.dart';
import '../models/models.dart';
import '../services/bili_api_service.dart';

class BiliMusicRepository {
  BiliMusicRepository(this._api);

  final BiliApiService _api;

  Future<String?> defaultSearchKeyword() async {
    final data = await _api.searchDefault();
    return data['show_name']?.toString() ?? data['name']?.toString();
  }

  Future<List<String>> hotWords() async {
    final payload = await _api.hotWords();
    final list = _extractList(payload);
    return list
        .map((item) {
          final map = _asMap(item);
          return map['keyword']?.toString() ??
              map['show_name']?.toString() ??
              map['name']?.toString();
        })
        .whereType<String>()
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> suggestions(String keyword) async {
    if (keyword.trim().isEmpty) return const <String>[];
    final payload = await _api.suggestions(keyword.trim());
    final list = _extractList(payload);
    return list
        .map((item) {
          final map = _asMap(item);
          return map['value']?.toString() ??
              map['term']?.toString() ??
              map['name']?.toString();
        })
        .whereType<String>()
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
  }

  Future<String?> discoverFeaturedKeyword() async {
    try {
      return await defaultSearchKeyword();
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> discoverQuickPicks({
    List<String> recentHistory = const <String>[],
  }) async {
    final picks = <String>[];
    final featured = await discoverFeaturedKeyword();
    if (featured != null && featured.isNotEmpty) {
      picks.add(featured);
    }

    try {
      picks.addAll(await hotWords());
    } catch (_) {}

    for (final word in recentHistory) {
      final trimmed = word.trim();
      if (trimmed.isEmpty || picks.contains(trimmed)) continue;
      picks.add(trimmed);
    }

    return picks.take(12).toList(growable: false);
  }

  Future<Track?> discoverFeaturedTrack() async {
    try {
      final items = await _api.homepageRecommend(pageSize: 1);
      if (items.isNotEmpty) return _trackFromHomeFeed(items.first);
    } catch (_) {}

    try {
      final items = await _api.popularVideos(pageSize: 1);
      if (items.isNotEmpty) return _trackFromSearchVideo(items.first);
    } catch (_) {}

    return null;
  }

  Future<List<Shelf>> discoverShelves() async {
    final shelves = <Shelf>[];

    try {
      final recommend = await _api.homepageRecommend(pageSize: 12);
      if (recommend.isNotEmpty) {
        shelves.add(
          Shelf(
            title: '为你推荐',
            items: recommend
                .map(_cardFromHomeFeed)
                .take(8)
                .toList(growable: false),
          ),
        );
      }
    } catch (_) {}

    try {
      final popular = await _api.popularVideos(pageSize: 12);
      if (popular.isNotEmpty) {
        shelves.add(
          Shelf(
            title: '热门视频',
            items: popular
                .map(_cardFromPopularVideo)
                .take(8)
                .toList(growable: false),
          ),
        );
      }
    } catch (_) {}

    return shelves;
  }

  Future<Track?> musicFeaturedTrack() async {
    for (final zone in _musicZones) {
      try {
        final items = await _api.rankingVideos(rid: zone.rid, type: zone.type);
        if (items.isNotEmpty) return _trackFromRankingVideo(items.first);
      } catch (_) {}
    }

    try {
      final items = await _api.rankingVideos(rid: _musicRootRid);
      if (items.isNotEmpty) return _trackFromRankingVideo(items.first);
    } catch (_) {}

    return null;
  }

  Future<List<Shelf>> musicShelves() async {
    final shelves = <Shelf>[];

    for (final zone in _musicZones) {
      try {
        final items = await _api.rankingVideos(rid: zone.rid, type: zone.type);
        if (items.isNotEmpty) {
          shelves.add(
            Shelf(
              title: zone.title,
              items: items
                  .map(_cardFromRankingVideo)
                  .take(8)
                  .toList(growable: false),
            ),
          );
        }
      } catch (_) {}
    }

    if (shelves.isEmpty) {
      try {
        final items = await _api.rankingVideos(rid: _musicRootRid);
        if (items.isNotEmpty) {
          shelves.add(
            Shelf(
              title: '音乐区排行',
              items: items
                  .map(_cardFromRankingVideo)
                  .take(8)
                  .toList(growable: false),
            ),
          );
        }
      } catch (_) {}
    }

    return shelves;
  }

  Future<List<BiliFavoriteFolder>> favoriteFolders(int upMid) async {
    final items = await _api.favoriteFolders(upMid: upMid, type: 2);
    return items.map(_folderFromJson).toList(growable: false);
  }

  Future<void> createFavoriteFolder({
    required String title,
    String intro = '',
    bool isPrivate = false,
  }) async {
    await _api.createFavoriteFolder(
      title: title,
      intro: intro,
      privacy: isPrivate ? 1 : 0,
    );
  }

  Future<void> addTrackToFavoriteFolder({
    required Track track,
    required int mediaId,
  }) async {
    final aid = track.aid ?? (await _hydrateVideoTrack(track)).aid;
    if (aid == null) {
      throw StateError('当前内容没有可收藏的 av 号。');
    }
    await _api.dealFavoriteResource(aid: aid, addMediaIds: [mediaId], delMediaIds: const <int>[]);
  }

  Future<void> removeTrackFromFavoriteFolder({
    required Track track,
    required int mediaId,
  }) async {
    final aid = track.aid ?? (await _hydrateVideoTrack(track)).aid;
    if (aid == null) {
      throw StateError('当前内容没有可移除的 av 号。');
    }
    await _api.deleteFavoriteResources(mediaId: mediaId, aids: [aid]);
  }

  Future<List<Track>> favoriteFolderTracks(
    int mediaId, {
    int page = 1,
    int pageSize = 20,
    String order = 'mtime',
    String? keyword,
  }) async {
    final data = await _api.favoriteFolderItems(
      mediaId: mediaId,
      page: page,
      pageSize: pageSize,
      order: order,
      keyword: keyword,
    );
    final items = _extractList(data['medias'] ?? data['list'] ?? data['items']);
    return items
        .whereType<Map>()
        .map((item) => _trackFromFavMedia(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<Track>> historyTracks({
    String type = 'all',
    int? cursor,
    int? viewAt,
    String? business,
    int? max,
  }) async {
    final data = await _api.historyCursor(
      type: type,
      cursor: cursor,
      viewAt: viewAt,
      business: business,
      max: max,
    );
    final items = _extractList(data['list'] ?? data['items'] ?? data['result']);
    return items
        .whereType<Map>()
        .map((item) => _trackFromHistory(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<Track>> searchTracks(
    String input, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final keyword = input.trim();
    if (keyword.isEmpty) return const <Track>[];

    final directBvid = _extractBvid(keyword);
    if (directBvid != null) {
      return <Track>[await trackFromBvid(directBvid)];
    }

    final directAid = _extractAid(keyword);
    if (directAid != null) {
      return <Track>[await trackFromAid(directAid)];
    }

    final items = await _api.searchVideos(
      keyword,
      page: page,
      pageSize: pageSize,
    );
    return items.map(_trackFromSearchVideo).toList(growable: false);
  }

  Future<List<Track>> searchMusicTracks(
    String input, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final keyword = input.trim();
    if (keyword.isEmpty) return const <Track>[];

    final directBvid = _extractBvid(keyword);
    if (directBvid != null) {
      return <Track>[await trackFromBvid(directBvid)];
    }

    final directAid = _extractAid(keyword);
    if (directAid != null) {
      return <Track>[await trackFromAid(directAid)];
    }

    final zoneItems = await _api.searchVideos(
      keyword,
      page: page,
      pageSize: pageSize,
      tid: _musicRootRid,
    );
    final genericItems = zoneItems.length >= pageSize
        ? const <Map<String, dynamic>>[]
        : await _api.searchVideos(keyword, page: page, pageSize: pageSize);

    final tracks = _mergeTracks([
      ...zoneItems.map(_trackFromSearchVideo),
      ...genericItems.where(_isMusicSearchItem).map(_trackFromSearchVideo),
      if (zoneItems.isEmpty) ...genericItems.map(_trackFromSearchVideo),
    ]);

    return tracks.take(pageSize).toList(growable: false);
  }

  Future<Track> trackFromBvid(String bvid) async {
    final data = await _api.videoView(bvid: bvid);
    return _trackFromVideoView(data);
  }

  Future<Track> trackFromAid(int aid) async {
    final data = await _api.videoView(aid: aid);
    return _trackFromVideoView(data);
  }

  Future<BiliPlaybackSource> resolvePlaybackSource(Track track) async {
    if (track.sourceUrl != null &&
        !(track.sourceExpiresAt != null &&
            DateTime.now().isAfter(track.sourceExpiresAt!))) {
      return BiliPlaybackSource(
        url: track.sourceUrl!,
        expiresAt: track.sourceExpiresAt,
      );
    }

    if (track.type == ContentType.audio && track.audioId != null) {
      return _resolveAudioAreaSource(track.audioId!);
    }

    final withCid = track.cid == null ? await _hydrateVideoTrack(track) : track;
    final bvid = withCid.bvid;
    final cid = withCid.cid;
    if (bvid == null || cid == null) {
      throw StateError('Track has no Bilibili bvid/cid playback identity.');
    }

    final data = await _api.videoPlayUrl(bvid: bvid, cid: cid);
    final dash = _asMap(data['dash']);
    final flac = _asMap(_asMap(dash['flac'])['audio']);
    final flacSource = _sourceFromDashAudio(
      flac,
      label: 'FLAC',
      lossless: true,
    );
    if (flacSource != null) return flacSource;

    final dolby = _extractList(_asMap(dash['dolby'])['audio']);
    if (dolby.isNotEmpty) {
      final source = _sourceFromDashAudio(_asMap(dolby.first), label: 'Dolby');
      if (source != null) return source;
    }

    final audio = _extractList(dash['audio']).map(_asMap).toList();
    audio.sort((a, b) => _qualityRank(a).compareTo(_qualityRank(b)));
    for (final item in audio.reversed) {
      final source = _sourceFromDashAudio(item, label: _qualityLabel(item));
      if (source != null) return source;
    }

    throw StateError('No playable DASH audio stream returned by Bilibili.');
  }

  Future<Track> _hydrateVideoTrack(Track track) async {
    if (track.bvid == null && track.aid == null) return track;
    final data = await _api.videoView(bvid: track.bvid, aid: track.aid);
    final hydrated = _trackFromVideoView(data);
    return hydrated.copyWith(
      id: track.id,
      title: track.title,
      artist: track.artist,
      coverUrl: track.coverUrl ?? hydrated.coverUrl,
      playCount: track.playCount,
    );
  }

  Future<BiliPlaybackSource> _resolveAudioAreaSource(int audioId) async {
    final data = await _api.audioStreamUrl(audioId);
    final urls = _extractList(data['cdns'])
        .map((item) => item.toString())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) {
      throw StateError('No playable audio-area stream returned by Bilibili.');
    }

    final timeout = _asInt(data['timeout']);
    final type = _asInt(data['type']);
    return BiliPlaybackSource(
      url: urls.first,
      backupUrls: urls.skip(1).toList(growable: false),
      qualityId: type,
      label: type == 3 ? 'FLAC' : null,
      expiresAt: timeout == null
          ? null
          : DateTime.now().add(Duration(seconds: timeout)),
      isLossless: type == 3,
    );
  }

  BiliPlaybackSource? _sourceFromDashAudio(
    Map<String, dynamic> item, {
    String? label,
    bool lossless = false,
  }) {
    final backupUrls = <String>[
      ..._extractList(item['backupUrl']).map((e) => e.toString()),
      ..._extractList(item['backup_url']).map((e) => e.toString()),
    ].where((url) => url.isNotEmpty).toList(growable: false);

    final url =
        item['baseUrl']?.toString() ??
        item['base_url']?.toString() ??
        (backupUrls.isEmpty ? null : backupUrls.first);
    if (url == null || url.isEmpty) return null;

    return BiliPlaybackSource(
      url: url,
      backupUrls: backupUrls,
      qualityId: _asInt(item['id']),
      label: label,
      codecs: item['codecs']?.toString(),
      bandwidth: _asInt(item['bandwidth']),
      mimeType: item['mimeType']?.toString() ?? item['mime_type']?.toString(),
      expiresAt: _deadlineFromUrl(url),
      isLossless: lossless,
    );
  }

  Track _trackFromSearchVideo(Map<String, dynamic> item) {
    final bvid = item['bvid']?.toString();
    final aid = _asInt(item['aid']);
    final id = bvid ?? (aid == null ? item.hashCode.toString() : 'av$aid');
    return Track(
      id: id,
      title: _stripHtml(item['title']?.toString() ?? ''),
      artist: item['author']?.toString() ?? item['up_name']?.toString() ?? '',
      duration: _parseDuration(item['duration']),
      type: ContentType.video,
      gradientSeed: id.hashCode.abs(),
      coverUrl: _normalizeImageUrl(item['pic']?.toString()),
      playCount: _asInt(item['play']) ?? 0,
      bvid: bvid,
      aid: aid,
      webUrl: bvid == null
          ? null
          : Uri.parse('https://www.bilibili.com/video/$bvid'),
    );
  }

  Track _trackFromHomeFeed(Map<String, dynamic> item) {
    final bvid =
        item['bvid']?.toString() ??
        item['bv_id']?.toString() ??
        item['bvid_str']?.toString();
    final aid = _asInt(item['aid']) ?? _asInt(item['id']);
    final id = bvid ?? (aid == null ? item.hashCode.toString() : 'av$aid');
    final owner = _asMap(item['owner']);
    final subtitle =
        owner['name']?.toString() ??
        item['author']?.toString() ??
        item['owner_name']?.toString() ??
        '';
    return Track(
      id: id,
      title: _stripHtml(item['title']?.toString() ?? ''),
      artist: subtitle,
      duration: _parseDuration(item['duration']),
      type: ContentType.video,
      gradientSeed: id.hashCode.abs(),
      coverUrl: _normalizeImageUrl(
        item['pic']?.toString() ?? item['cover']?.toString(),
      ),
      playCount:
          _asInt(item['play']) ?? _asInt(_asMap(item['stat'])['view']) ?? 0,
      bvid: bvid,
      aid: aid,
      cid: _asInt(item['cid']),
      webUrl: bvid == null
          ? null
          : Uri.parse('https://www.bilibili.com/video/$bvid'),
    );
  }

  Track _trackFromVideoView(Map<String, dynamic> data) {
    final bvid = data['bvid']?.toString();
    final aid = _asInt(data['aid']);
    final pages = _extractList(data['pages']);
    final firstPage = pages.isEmpty ? <String, dynamic>{} : _asMap(pages.first);
    final cid = _asInt(data['cid']) ?? _asInt(firstPage['cid']);
    final id = bvid ?? (aid == null ? data.hashCode.toString() : 'av$aid');
    final owner = _asMap(data['owner']);
    return Track(
      id: id,
      title: data['title']?.toString() ?? '',
      artist: owner['name']?.toString() ?? '',
      duration: _parseDuration(data['duration']),
      type: ContentType.video,
      gradientSeed: id.hashCode.abs(),
      coverUrl: _normalizeImageUrl(data['pic']?.toString()),
      playCount: _asInt(_asMap(data['stat'])['view']) ?? 0,
      bvid: bvid,
      aid: aid,
      cid: cid,
      webUrl: bvid == null
          ? null
          : Uri.parse('https://www.bilibili.com/video/$bvid'),
    );
  }

  Track _trackFromFavMedia(Map<String, dynamic> item) {
    final bvid = item['bvid']?.toString() ?? item['bv_id']?.toString();
    final aid = _asInt(item['id']);
    final id = bvid ?? (aid == null ? item.hashCode.toString() : 'av$aid');
    final owner = _asMap(item['upper']);
    return Track(
      id: id,
      title: _stripHtml(item['title']?.toString() ?? ''),
      artist:
          owner['name']?.toString() ??
          item['author']?.toString() ??
          item['upper_name']?.toString() ??
          '',
      duration: Duration(seconds: _asInt(item['duration']) ?? 0),
      type: _favoriteType(item['type']),
      gradientSeed: id.hashCode.abs(),
      coverUrl: _normalizeImageUrl(item['cover']?.toString()),
      playCount:
          _asInt(_asMap(item['cnt_info'])['play']) ??
          _asInt(_asMap(item['cnt_info'])['collect']) ??
          0,
      bvid: bvid,
      aid: aid,
      webUrl: bvid == null
          ? null
          : Uri.parse('https://www.bilibili.com/video/$bvid'),
    );
  }

  Track _trackFromHistory(Map<String, dynamic> item) {
    final bvid = item['bvid']?.toString();
    final aid =
        _asInt(item['aid']) ?? _asInt(item['oid']) ?? _asInt(item['id']);
    final id = bvid ?? (aid == null ? item.hashCode.toString() : 'av$aid');
    final owner = _asMap(item['owner']);
    final author =
        item['author_name']?.toString() ??
        owner['name']?.toString() ??
        item['owner_name']?.toString() ??
        '';
    return Track(
      id: id,
      title: _stripHtml(
        item['title']?.toString() ?? item['long_title']?.toString() ?? '',
      ),
      artist: author,
      duration: Duration(seconds: _asInt(item['duration']) ?? 0),
      type: _historyContentType(item),
      gradientSeed: id.hashCode.abs(),
      coverUrl: _normalizeImageUrl(
        item['cover']?.toString() ?? item['pic']?.toString(),
      ),
      playCount: _asInt(_asMap(item['stat'])['view']) ?? 0,
      bvid: bvid,
      aid: aid,
      cid: _asInt(item['cid']),
      webUrl: bvid == null
          ? null
          : Uri.parse('https://www.bilibili.com/video/$bvid'),
    );
  }

  CardItem _cardFromHomeFeed(Map<String, dynamic> item) {
    final track = _trackFromHomeFeed(item);
    return CardItem(
      id: track.id,
      title: track.title,
      subtitle: track.artist.isNotEmpty
          ? track.artist
          : (track.playCount > 0 ? Format.count(track.playCount) : ''),
      gradientSeed: track.gradientSeed,
      coverUrl: track.coverUrl,
      type: track.type,
      duration: track.duration,
      playCount: track.playCount,
      bvid: track.bvid,
      aid: track.aid,
      cid: track.cid,
      artist: track.artist,
    );
  }

  CardItem _cardFromPopularVideo(Map<String, dynamic> item) {
    final track = _trackFromSearchVideo(item);
    return CardItem(
      id: track.id,
      title: track.title,
      subtitle: track.artist.isNotEmpty
          ? track.artist
          : (track.playCount > 0 ? Format.count(track.playCount) : ''),
      gradientSeed: track.gradientSeed,
      coverUrl: track.coverUrl,
      type: track.type,
      duration: track.duration,
      playCount: track.playCount,
      bvid: track.bvid,
      aid: track.aid,
      cid: track.cid,
      artist: track.artist,
    );
  }

  CardItem _cardFromRankingVideo(Map<String, dynamic> item) {
    final track = _trackFromRankingVideo(item);
    return CardItem(
      id: track.id,
      title: track.title,
      subtitle: track.artist.isNotEmpty
          ? track.artist
          : (track.playCount > 0 ? Format.count(track.playCount) : ''),
      gradientSeed: track.gradientSeed,
      coverUrl: track.coverUrl,
      type: track.type,
      duration: track.duration,
      playCount: track.playCount,
      bvid: track.bvid,
      aid: track.aid,
      cid: track.cid,
      artist: track.artist,
    );
  }

  BiliFavoriteFolder _folderFromJson(Map<String, dynamic> item) {
    final mediaId = _asInt(item['id']) ?? _asInt(item['fid']) ?? 0;
    final fid = _asInt(item['fid']) ?? mediaId;
    final mid = _asInt(item['mid']) ?? 0;
    return BiliFavoriteFolder(
      mediaId: mediaId,
      fid: fid,
      mid: mid,
      title: item['title']?.toString() ?? '',
      mediaCount: _asInt(item['media_count']) ?? 0,
      gradientSeed: mediaId.abs(),
      attr: _asInt(item['attr']) ?? 0,
      favState: _asInt(item['fav_state']) ?? 0,
      isPublic: (_asInt(item['attr']) ?? 0) == 0,
      coverUrl: _normalizeImageUrl(item['cover']?.toString()),
      intro: item['intro']?.toString(),
    );
  }

  ContentType _favoriteType(Object? raw) {
    final value = _asInt(raw);
    return switch (value) {
      12 => ContentType.audio,
      _ => ContentType.video,
    };
  }

  ContentType _historyContentType(Map<String, dynamic> item) {
    final business = item['business']?.toString();
    if (business == 'audio') return ContentType.audio;
    if (item['type']?.toString() == 'audio') return ContentType.audio;
    return ContentType.video;
  }

  Track _trackFromRankingVideo(Map<String, dynamic> item) {
    final bvid = item['bvid']?.toString();
    final aid = _asInt(item['aid']);
    final id = bvid ?? (aid == null ? item.hashCode.toString() : 'av$aid');
    final owner = _asMap(item['owner']);
    return Track(
      id: id,
      title: _stripHtml(item['title']?.toString() ?? ''),
      artist:
          owner['name']?.toString() ??
          item['author']?.toString() ??
          item['up_name']?.toString() ??
          '',
      duration: _parseDuration(item['duration']),
      type: ContentType.video,
      gradientSeed: id.hashCode.abs(),
      coverUrl: _normalizeImageUrl(item['pic']?.toString()),
      playCount: _asInt(item['play']) ?? 0,
      bvid: bvid,
      aid: aid,
      cid: _asInt(item['cid']),
      webUrl: bvid == null
          ? null
          : Uri.parse('https://www.bilibili.com/video/$bvid'),
    );
  }

  String? _extractBvid(String input) =>
      RegExp(r'BV[0-9A-Za-z]{10}').firstMatch(input)?.group(0);

  int? _extractAid(String input) {
    final match = RegExp(
      r'(?:^|[^\w])av(\d+)',
      caseSensitive: false,
    ).firstMatch(input);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _stripHtml(String value) =>
      value.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&amp;', '&');

  bool _isMusicSearchItem(Map<String, dynamic> item) {
    final tid =
        _asInt(item['typeid']) ?? _asInt(item['tid']) ?? _asInt(item['tids']);
    if (tid != null && _musicSearchTypeIds.contains(tid)) return true;

    final text = [
      item['typename'],
      item['type'],
      item['tag'],
      item['title'],
    ].whereType<Object>().join(' ').toLowerCase();
    return _musicSearchKeywords.any(text.contains);
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

  String? _normalizeImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  Duration _parseDuration(Object? raw) {
    if (raw is num) return Duration(seconds: raw.toInt());
    final text = raw?.toString() ?? '';
    final parts = text.split(':').map((e) => int.tryParse(e) ?? 0).toList();
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    }
    if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    }
    return Duration.zero;
  }

  DateTime? _deadlineFromUrl(String url) {
    final value = Uri.tryParse(url)?.queryParameters['deadline'];
    final seconds = value == null ? null : int.tryParse(value);
    return seconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  int _qualityRank(Map<String, dynamic> item) {
    final id = _asInt(item['id']);
    final index = id == null ? -1 : _audioQualitySort.indexOf(id);
    return index == -1 ? 0 : index;
  }

  String? _qualityLabel(Map<String, dynamic> item) {
    final id = _asInt(item['id']);
    return switch (id) {
      30251 => 'Hi-Res',
      30250 => 'Dolby',
      30280 => '320K',
      30232 => '128K',
      30216 => '64K',
      _ => id == null ? null : '$id',
    };
  }

  int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    if (text.endsWith('万')) {
      final number = double.tryParse(text.substring(0, text.length - 1));
      return number == null ? null : (number * 10000).round();
    }
    return int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  List<Object?> _extractList(Object? value) {
    if (value is List) return value;
    if (value is Map) {
      for (final key in const ['list', 'result', 'items', 'item']) {
        final nested = value[key];
        if (nested is List) return nested;
      }
    }
    return const <Object?>[];
  }
}

const _audioQualitySort = <int>[
  30257,
  30216,
  30259,
  30260,
  30232,
  30280,
  30250,
  30251,
];

const _musicRootRid = 3;

const _musicSearchTypeIds = <int>{
  3,
  28,
  31,
  30,
  59,
  193,
  29,
  130,
  243,
  244,
  265,
  266,
  267,
  1003,
};

const _musicSearchKeywords = <String>{
  'music',
  'mv',
  'vocaloid',
  'utau',
  'cover',
  '原创音乐',
  '翻唱',
  '演奏',
  '音乐',
  '音乐现场',
};

const _musicZones = <_MusicZone>[
  _MusicZone('原创音乐', 28),
  _MusicZone('翻唱', 31),
  _MusicZone('VOCALOID·UTAU', 30),
  _MusicZone('演奏', 59),
  _MusicZone('MV', 193),
  _MusicZone('音乐现场', 29),
];

class _MusicZone {
  const _MusicZone(this.title, this.rid) : type = 'all';

  final String title;
  final int rid;
  final String type;
}
