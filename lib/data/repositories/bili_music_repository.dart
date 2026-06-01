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
    final words = list
        .map((item) {
          final map = _asMap(item);
          return map['keyword']?.toString() ??
              map['show_name']?.toString() ??
              map['name']?.toString() ??
              map['word']?.toString() ??
              item?.toString();
        })
        .whereType<String>()
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isNotEmpty) return words;

    final map = _asMap(payload);
    return map.values
        .map((item) => item?.toString())
        .whereType<String>()
        .where((word) => word.isNotEmpty)
        .take(12)
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
    final tracks = await musicFeaturedTracks(limit: 1);
    if (tracks.isNotEmpty) return tracks.first;
    return null;
  }

  Future<List<Track>> musicFeaturedTracks({int limit = 5}) async {
    if (limit <= 0) return const <Track>[];

    final tracks = <Track>[];
    final seen = <String>{};

    void addTrack(Track track) {
      final key = _trackKey(track);
      if (seen.add(key)) tracks.add(track);
    }

    for (final zone in _musicRankingZones) {
      try {
        final items = await _api.rankingVideos(rid: zone.rid, type: zone.type);
        for (final item in items.take(3)) {
          addTrack(_trackFromRankingVideo(item));
          if (tracks.length >= limit) return tracks;
        }
      } catch (_) {}
    }

    try {
      final items = await _api.rankingVideos(rid: _musicRootRid);
      for (final item in items) {
        addTrack(_trackFromRankingVideo(item));
        if (tracks.length >= limit) return tracks;
      }
    } catch (_) {}

    try {
      final items = await _api.popularVideos(pageSize: limit);
      for (final item in items.where(_isMusicSearchItem)) {
        addTrack(_trackFromSearchVideo(item));
        if (tracks.length >= limit) return tracks;
      }
    } catch (_) {}

    try {
      final items = await _api.homepageRecommend(pageSize: limit);
      for (final item in items) {
        addTrack(_trackFromHomeFeed(item));
        if (tracks.length >= limit) return tracks;
      }
    } catch (_) {}

    return tracks;
  }

  Future<List<Shelf>> musicShelves() async {
    final shelves = <Shelf>[];

    for (final zone in _musicRankingZones) {
      if (shelves.length >= _maxMusicShelfCount) break;
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
          continue;
        }
      } catch (_) {}

      if (zone.searchKeyword == null || shelves.length >= _maxMusicShelfCount) {
        continue;
      }

      try {
        final items = await _api.searchVideos(
          zone.searchKeyword!,
          pageSize: 8,
          tid: zone.searchTid,
        );
        final cards = items
            .map(_cardFromPopularVideo)
            .take(8)
            .toList(growable: false);
        if (cards.isNotEmpty) {
          shelves.add(Shelf(title: zone.title, items: cards));
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
    await _api.dealFavoriteResource(
      aid: aid,
      addMediaIds: [mediaId],
      delMediaIds: const <int>[],
    );
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

  Future<List<LyricLine>> trackLyrics(
    Track track, {
    LyricsSourcePreference sourcePreference = LyricsSourcePreference.auto,
  }) async {
    switch (sourcePreference) {
      case LyricsSourcePreference.biliOnly:
        return _biliLyrics(track);
      case LyricsSourcePreference.lrclibOnly:
        return _lrclibLyrics(track);
      case LyricsSourcePreference.lrclibFirst:
        final lrclib = await _lrclibLyrics(track);
        if (lrclib.isNotEmpty) return lrclib;
        return _biliLyrics(track);
      case LyricsSourcePreference.biliFirst:
      case LyricsSourcePreference.auto:
        final bili = await _biliLyrics(track);
        if (bili.isNotEmpty) return bili;
        return _lrclibLyrics(track);
    }
  }

  Future<List<Track>> relatedTracks(Track track, {int limit = 12}) async {
    final title = _searchableTitle(track.title);
    final keyword = [
      if (title.isNotEmpty) title,
      if (track.artist.isNotEmpty) track.artist,
    ].join(' ').trim();
    if (keyword.isEmpty) return const <Track>[];

    final results = await searchMusicTracks(keyword, pageSize: limit + 4);
    final currentKey = _trackKey(track);
    return results
        .where((item) => _trackKey(item) != currentKey)
        .take(limit)
        .toList(growable: false);
  }

  Future<Track> trackFromBvid(String bvid) async {
    final data = await _api.videoView(bvid: bvid);
    return _trackFromVideoView(data);
  }

  Future<Track> trackFromAid(int aid) async {
    final data = await _api.videoView(aid: aid);
    return _trackFromVideoView(data);
  }

  Future<BiliPlaybackSource> resolvePlaybackSource(
    Track track, {
    AudioQualityPreference quality = AudioQualityPreference.auto,
  }) async {
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
    final audio = _extractList(dash['audio']).map(_asMap).toList();
    final source = _resolveVideoDashSource(
      dash: dash,
      audio: audio,
      quality: quality,
    );
    if (source != null) return source;

    throw StateError('No playable DASH audio stream returned by Bilibili.');
  }

  Future<List<LyricLine>> _biliLyrics(Track track) async {
    if (track.type == ContentType.audio && track.audioId != null) {
      final audioLyrics = await _audioAreaLyrics(track.audioId!);
      if (audioLyrics.isNotEmpty) return audioLyrics;
    }

    final context = await _lyricVideoContext(track);
    if (context == null) return const <LyricLine>[];
    return _videoSubtitleLyrics(context.playerData);
  }

  Future<List<LyricLine>> _lrclibLyrics(Track track) async {
    final context = await _lyricVideoContext(track);
    final metadata = await _lyricMetadata(track, context: context);
    final candidates = _lyricQueries(metadata, track);
    for (final candidate in candidates) {
      final items = await _api.lrclibLyrics(
        trackName: candidate.title,
        artistName: candidate.artist,
        durationSeconds: candidate.duration.inSeconds > 0
            ? candidate.duration.inSeconds
            : null,
      );
      final parsed = _lyricsFromLrclib(items);
      if (parsed.isNotEmpty) return parsed;
    }
    return const <LyricLine>[];
  }

  BiliPlaybackSource? _resolveVideoDashSource({
    required Map<String, dynamic> dash,
    required List<Map<String, dynamic>> audio,
    required AudioQualityPreference quality,
  }) {
    final flacSource = _sourceFromDashAudio(
      _asMap(_asMap(dash['flac'])['audio']),
      label: 'FLAC',
      lossless: true,
    );
    final dolby = _extractList(_asMap(dash['dolby'])['audio']);
    final dolbySource = dolby.isEmpty
        ? null
        : _sourceFromDashAudio(_asMap(dolby.first), label: 'Dolby');
    final specialFirst =
        quality == AudioQualityPreference.auto ||
        quality == AudioQualityPreference.lossless;

    if (specialFirst) {
      if (flacSource != null) return flacSource;
      if (dolbySource != null) return dolbySource;
    }

    for (final item in _orderedDashAudio(audio, quality)) {
      final source = _sourceFromDashAudio(item, label: _qualityLabel(item));
      if (source != null) return source;
    }

    if (!specialFirst) {
      if (flacSource != null) return flacSource;
      if (dolbySource != null) return dolbySource;
    }

    return null;
  }

  List<Map<String, dynamic>> _orderedDashAudio(
    List<Map<String, dynamic>> audio,
    AudioQualityPreference quality,
  ) {
    final sorted = audio.toList(growable: false)
      ..sort((a, b) => _qualityRank(a).compareTo(_qualityRank(b)));
    if (quality == AudioQualityPreference.auto ||
        quality == AudioQualityPreference.lossless) {
      return sorted.reversed.toList(growable: false);
    }

    final preferredIds = switch (quality) {
      AudioQualityPreference.high => const <int>[
        30280,
        30232,
        30260,
        30259,
        30216,
        30257,
      ],
      AudioQualityPreference.medium => const <int>[
        30232,
        30260,
        30259,
        30280,
        30216,
        30257,
      ],
      AudioQualityPreference.low => const <int>[
        30216,
        30257,
        30259,
        30260,
        30232,
        30280,
      ],
      _ => const <int>[],
    };

    final seen = <int>{};
    final ordered = <Map<String, dynamic>>[];
    for (final id in preferredIds) {
      for (final item in sorted.reversed) {
        if (_asInt(item['id']) == id && seen.add(id)) {
          ordered.add(item);
          break;
        }
      }
    }
    for (final item in sorted.reversed) {
      final id = _asInt(item['id']);
      if (id == null || seen.add(id)) ordered.add(item);
    }
    return ordered;
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

  Future<_LyricVideoContext?> _lyricVideoContext(Track track) async {
    var candidate = track;
    if ((candidate.bvid != null || candidate.aid != null) &&
        candidate.cid == null) {
      try {
        candidate = await _hydrateVideoTrack(track);
      } catch (_) {}
    }

    final bvid = candidate.bvid;
    final aid = candidate.aid;
    final cid = candidate.cid;
    if ((bvid == null && aid == null) || cid == null) {
      return null;
    }

    try {
      final data = await _api.playerV2(bvid: bvid, aid: aid, cid: cid);
      return _LyricVideoContext(track: candidate, playerData: data);
    } catch (_) {
      return null;
    }
  }

  Future<List<LyricLine>> _videoSubtitleLyrics(
    Map<String, dynamic> playerData,
  ) async {
    final subtitleBlock = _asMap(playerData['subtitle']);
    final subtitles = _extractList(subtitleBlock['subtitles']);
    if (subtitles.isEmpty) return const <LyricLine>[];

    final preferred = subtitles.map(_asMap).toList(growable: false)
      ..sort((a, b) => _subtitleRank(a).compareTo(_subtitleRank(b)));

    for (final item in preferred) {
      final subtitleUrl =
          item['subtitle_url']?.toString() ??
          item['subtitle_url_v2']?.toString();
      if (subtitleUrl == null || subtitleUrl.isEmpty) continue;
      try {
        final data = await _api.subtitleJson(subtitleUrl);
        final lines = _lyricsFromBiliSubtitle(_extractList(data['body']));
        if (lines.isNotEmpty) return lines;
      } catch (_) {}
    }

    return const <LyricLine>[];
  }

  Future<List<LyricLine>> _audioAreaLyrics(int audioId) async {
    try {
      final info = await _api.audioSongInfo(audioId);
      final lyricUrl = info['lyric']?.toString();
      if (lyricUrl == null || lyricUrl.isEmpty) return const <LyricLine>[];
      final raw = await _api.rawText(lyricUrl);
      final parsed = _parseLrc(raw);
      if (parsed.isNotEmpty) return parsed;
      return _parsePlainLyrics(raw);
    } catch (_) {
      return const <LyricLine>[];
    }
  }

  Future<_LyricMetadata> _lyricMetadata(
    Track track, {
    _LyricVideoContext? context,
  }) async {
    final candidate = context?.track ?? track;
    final playerData = context?.playerData;
    if (playerData != null) {
      final bgmInfo = _asMap(playerData['bgm_info'] ?? playerData['bgminfo']);
      final bgmTitle =
          bgmInfo['title']?.toString() ??
          bgmInfo['name']?.toString() ??
          bgmInfo['song_name']?.toString();
      final bgmArtist =
          bgmInfo['author']?.toString() ??
          bgmInfo['artist']?.toString() ??
          bgmInfo['singer']?.toString();
      if (bgmTitle != null && bgmTitle.trim().isNotEmpty) {
        return _LyricMetadata(
          title: _searchableTitle(bgmTitle),
          artist: _cleanArtist(bgmArtist ?? candidate.artist),
          duration: candidate.duration,
        );
      }
    }

    return _LyricMetadata(
      title: _searchableTitle(candidate.title),
      artist: _cleanArtist(candidate.artist),
      duration: candidate.duration,
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
      final key = _trackKey(track);
      if (seen.add(key)) merged.add(track);
    }
    return merged;
  }

  String _trackKey(Track track) =>
      track.bvid ??
      track.aid?.toString() ??
      track.audioId?.toString() ??
      track.id;

  List<LyricLine> _lyricsFromLrclib(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const <LyricLine>[];
    final item = items.firstWhere(
      (item) => (item['syncedLyrics']?.toString().trim().isNotEmpty ?? false),
      orElse: () => items.first,
    );
    final synced = item['syncedLyrics']?.toString();
    if (synced != null && synced.trim().isNotEmpty) {
      final parsed = _parseLrc(synced);
      if (parsed.isNotEmpty) return parsed;
    }

    final plain = item['plainLyrics']?.toString();
    if (plain == null || plain.trim().isEmpty) return const <LyricLine>[];
    return plain
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => LyricLine(time: Duration.zero, text: line))
        .toList(growable: false);
  }

  List<LyricLine> _parsePlainLyrics(String raw) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((line) => _cleanLyricText(line))
        .where((line) => line.isNotEmpty)
        .map((line) => LyricLine(time: Duration.zero, text: line))
        .toList(growable: false);
  }

  List<LyricLine> _lyricsFromBiliSubtitle(List<Object?> items) {
    if (items.isEmpty) return const <LyricLine>[];
    final lines = <LyricLine>[];
    for (final item in items) {
      final map = _asMap(item);
      final text = _cleanLyricText(map['content']?.toString() ?? '');
      if (text.isEmpty) continue;
      final from = _asDouble(map['from']) ?? 0;
      lines.add(
        LyricLine(
          time: Duration(milliseconds: (from * 1000).round()),
          text: text,
        ),
      );
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  List<_LyricQuery> _lyricQueries(_LyricMetadata metadata, Track track) {
    final queries = <_LyricQuery>[];
    final titleCandidates =
        <String>[
              metadata.title,
              _searchableTitle(track.title),
              _fallbackSearchTitle(track.title),
            ]
            .map((title) => title.trim())
            .where((title) => title.isNotEmpty)
            .toList(growable: false);

    final artistCandidates = <String?>[
      metadata.artist,
      _cleanArtist(track.artist),
      null,
    ];

    for (final title in titleCandidates) {
      for (final artist in artistCandidates) {
        final query = _LyricQuery(
          title: title,
          artist: artist,
          duration: metadata.duration,
        );
        if (!queries.contains(query)) {
          queries.add(query);
        }
      }
    }
    return queries;
  }

  List<LyricLine> _parseLrc(String raw) {
    final lines = <LyricLine>[];
    final pattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      final matches = pattern.allMatches(rawLine).toList();
      if (matches.isEmpty) continue;
      final text = rawLine.replaceAll(pattern, '').trim();
      if (text.isEmpty) continue;
      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fraction = match.group(3) ?? '0';
        final milliseconds = switch (fraction.length) {
          1 => (int.tryParse(fraction) ?? 0) * 100,
          2 => (int.tryParse(fraction) ?? 0) * 10,
          _ => int.tryParse(fraction.padRight(3, '0').substring(0, 3)) ?? 0,
        };
        lines.add(
          LyricLine(
            time: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            ),
            text: text,
          ),
        );
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  int _subtitleRank(Map<String, dynamic> item) {
    final lan = item['lan']?.toString().toLowerCase() ?? '';
    final lanDoc = item['lan_doc']?.toString().toLowerCase() ?? '';
    final aiStatus = _asInt(item['ai_status']) ?? 0;
    if (lan.contains('zh') || lanDoc.contains('中文')) return 0;
    if (aiStatus > 0) return 1;
    return 2;
  }

  String _fallbackSearchTitle(String value) {
    return _stripHtml(value)
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'【[^】]*】'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'（[^）]*）'), ' ')
        .replaceAll(RegExp(r'\s*[-–—|/／·•~].*$'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _searchableTitle(String value) {
    return _stripHtml(value)
        .replaceAll(RegExp(r'【[^】]*】'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _cleanArtist(String? value) {
    final cleaned = value
        ?.replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[,/&、].*'), '')
        .trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  String _cleanLyricText(String value) {
    return value
        .replaceAll(RegExp(r'^[♪♫♬♩\s]+'), '')
        .replaceAll(RegExp(r'[♪♫♬♩\s]+$'), '')
        .replaceAll(RegExp(r'\uFEFF'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
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
const _musicRankRid = 1003;
const _maxMusicShelfCount = 6;

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

const _musicRankingZones = <_MusicZone>[
  _MusicZone('全站音乐榜', _musicRankRid),
  _MusicZone('音乐区总榜', _musicRootRid),
  _MusicZone('原创音乐', 28, searchKeyword: '原创音乐'),
  _MusicZone('翻唱', 31, searchKeyword: '翻唱'),
  _MusicZone('VOCALOID·UTAU', 30, searchKeyword: 'VOCALOID UTAU'),
  _MusicZone('演奏', 59, searchKeyword: '演奏'),
  _MusicZone('MV', 193, searchKeyword: 'MV'),
  _MusicZone('音乐现场', 29, searchKeyword: '音乐现场'),
  _MusicZone('乐评盘点', 243),
  _MusicZone('音乐教学', 244),
  _MusicZone('AI音乐', 265),
  _MusicZone('音乐综合', 130),
];

class _MusicZone {
  const _MusicZone(this.title, this.rid, {this.searchKeyword}) : type = 'all';

  final String title;
  final int rid;
  final String type;
  final String? searchKeyword;

  int get searchTid => rid == _musicRankRid ? _musicRootRid : rid;
}

class _LyricMetadata {
  const _LyricMetadata({
    required this.title,
    required this.artist,
    required this.duration,
  });

  final String title;
  final String? artist;
  final Duration duration;
}

class _LyricVideoContext {
  const _LyricVideoContext({required this.track, required this.playerData});

  final Track track;
  final Map<String, dynamic> playerData;
}

class _LyricQuery {
  const _LyricQuery({
    required this.title,
    required this.artist,
    required this.duration,
  });

  final String title;
  final String? artist;
  final Duration duration;

  @override
  bool operator ==(Object other) {
    return other is _LyricQuery &&
        other.title == title &&
        other.artist == artist &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(title, artist, duration);
}
