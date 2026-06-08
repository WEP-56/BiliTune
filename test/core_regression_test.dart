import 'package:bilitune/core/network/bili_cookie_store.dart';
import 'package:bilitune/data/models/models.dart';
import 'package:bilitune/data/services/github_release_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('Track.copyWith', () {
    test('can clear nullable identity and source fields', () {
      final expiresAt = DateTime(2026, 1, 1);
      final track = Track(
        id: 'track-1',
        title: 'Song',
        artist: 'Artist',
        duration: const Duration(minutes: 3),
        type: ContentType.video,
        gradientSeed: 7,
        coverUrl: 'https://example.com/cover.jpg',
        bvid: 'BV1234567890',
        aid: 1,
        cid: 2,
        audioId: 3,
        webUrl: Uri.parse('https://www.bilibili.com/video/BV1234567890'),
        sourceUrl: 'https://example.com/audio.m4s',
        sourceExpiresAt: expiresAt,
      );

      final cleared = track.copyWith(
        coverUrl: null,
        bvid: null,
        aid: null,
        cid: null,
        audioId: null,
        webUrl: null,
        sourceUrl: null,
        sourceExpiresAt: null,
      );

      expect(cleared.coverUrl, isNull);
      expect(cleared.bvid, isNull);
      expect(cleared.aid, isNull);
      expect(cleared.cid, isNull);
      expect(cleared.audioId, isNull);
      expect(cleared.webUrl, isNull);
      expect(cleared.sourceUrl, isNull);
      expect(cleared.sourceExpiresAt, isNull);
      expect(cleared.title, track.title);
    });
  });

  group('BiliCookieStore', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('saves, reads, and clears credentials', () async {
      final store = BiliCookieStore(SharedPreferencesAsync());

      await store.saveManualCookieHeader(
        'SESSDATA=session; bili_jct=csrf; DedeUserID=123',
      );

      final credential = await store.readCredential();
      expect(credential?.sessdata, 'session');
      expect(credential?.biliJct, 'csrf');
      expect(credential?.mid, 123);
      expect(await store.readCookieHeader(), contains('SESSDATA=session'));

      await store.clearCredential();

      expect(await store.readCredential(), isNull);
      expect(await store.readCookieHeader(), isEmpty);
    });
  });

  group('ReleaseVersion', () {
    test('parses tags with v prefix and build metadata', () {
      expect(ReleaseVersion.parse('v1.2.3+4').toString(), '1.2.3');
      expect(ReleaseVersion.parse('1.2.3-beta').toString(), '1.2.3');
    });

    test('compares remote versions against current app version', () {
      expect(
        isRemoteReleaseNewer(currentVersion: '1.2.3', remoteTag: 'v1.2.4'),
        isTrue,
      );
      expect(
        isRemoteReleaseNewer(currentVersion: '1.2.3', remoteTag: 'v1.2.3'),
        isFalse,
      );
      expect(
        isRemoteReleaseNewer(currentVersion: '1.2.3', remoteTag: 'v1.2.2'),
        isFalse,
      );
    });
  });
}
