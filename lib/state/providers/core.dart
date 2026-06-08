part of '../providers.dart';

const _unset = Object();
const int libraryDownloadsPlaylistId = -1;

enum WindowCloseBehavior { minimize, tray, exit }

extension WindowCloseBehaviorX on WindowCloseBehavior {
  String get label => switch (this) {
    WindowCloseBehavior.minimize => '最小化',
    WindowCloseBehavior.tray => '到托盘',
    WindowCloseBehavior.exit => '退出',
  };

  String get value => switch (this) {
    WindowCloseBehavior.minimize => 'minimize',
    WindowCloseBehavior.tray => 'tray',
    WindowCloseBehavior.exit => 'exit',
  };
}

final sharedPreferencesAsyncProvider = Provider<SharedPreferencesAsync>(
  (ref) => SharedPreferencesAsync(),
);

final appLocalStoreProvider = Provider<AppLocalStore>(
  (ref) => AppLocalStore(ref.watch(sharedPreferencesAsyncProvider)),
);

final biliCookieStoreProvider = Provider<BiliCookieStore>(
  (ref) => BiliCookieStore(ref.watch(sharedPreferencesAsyncProvider)),
);

final biliDioProvider = Provider<Dio>(
  (ref) => BiliDioFactory.create(ref.watch(biliCookieStoreProvider)),
);

final biliWbiSignerProvider = Provider<BiliWbiSigner>(
  (ref) => BiliWbiSigner(ref.watch(biliDioProvider)),
);

final biliApiServiceProvider = Provider<BiliApiService>(
  (ref) => BiliApiService(
    ref.watch(biliDioProvider),
    ref.watch(biliCookieStoreProvider),
    ref.watch(biliWbiSignerProvider),
  ),
);

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

final githubUpdateServiceProvider = Provider<GithubUpdateService>(
  (ref) => GithubUpdateService(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        headers: const <String, dynamic>{
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'BiliTune',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      ),
    ),
  ),
);

final biliAuthRepositoryProvider = Provider<BiliAuthRepository>(
  (ref) => BiliAuthRepository(
    ref.watch(biliApiServiceProvider),
    ref.watch(biliCookieStoreProvider),
  ),
);

final biliMusicRepositoryProvider = Provider<BiliMusicRepository>(
  (ref) => BiliMusicRepository(ref.watch(biliApiServiceProvider)),
);

bool get _skipNetworkBootstrap =>
    Platform.environment['FLUTTER_TEST'] == 'true';

const _playerBufferSize = 128 * 1024 * 1024;
const _streamingMpvProperties = <String, String>{
  'cache': 'yes',
  'cache-on-disk': 'yes',
  'demuxer-max-bytes': '$_playerBufferSize',
  'demuxer-max-back-bytes': '$_playerBufferSize',
  'demuxer-readahead-secs': '60',
  'cache-pause': 'yes',
  'cache-pause-wait': '3',
  'cache-pause-initial': 'yes',
};
const _biliPlaybackHeaders = <String, String>{
  'User-Agent': biliUserAgent,
  'Referer': biliReferer,
  'Origin': 'https://www.bilibili.com',
};
const _playbackPersistInterval = Duration(seconds: 4);
const _systemMediaSyncInterval = Duration(seconds: 1);

final mediaPlayerProvider = Provider<mk.Player>((ref) {
  mk.MediaKit.ensureInitialized();
  final player = mk.Player(
    configuration: const mk.PlayerConfiguration(
      title: 'BiliTune',
      bufferSize: _playerBufferSize,
    ),
  );
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});
