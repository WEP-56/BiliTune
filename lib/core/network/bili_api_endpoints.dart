class BiliApiEndpoints {
  const BiliApiEndpoints._();

  static const apiHost = 'api.bilibili.com';
  static const passportHost = 'passport.bilibili.com';
  static const searchHost = 's.search.bilibili.com';

  static Uri api(String path, [Map<String, dynamic>? query]) =>
      Uri.https(apiHost, path, _stringQuery(query));

  static Uri passport(String path, [Map<String, dynamic>? query]) =>
      Uri.https(passportHost, path, _stringQuery(query));

  static Uri search(String path, [Map<String, dynamic>? query]) =>
      Uri.https(searchHost, path, _stringQuery(query));

  static Map<String, String>? _stringQuery(Map<String, dynamic>? query) {
    if (query == null) return null;
    return query.map((key, value) => MapEntry(key, value.toString()));
  }

  static final nav = api('/x/web-interface/nav');
  static final homepageRecommend = api(
    '/x/web-interface/wbi/index/top/feed/rcmd',
  );
  static final searchDefault = api('/x/web-interface/wbi/search/default');
  static final searchType = api('/x/web-interface/wbi/search/type');
  static final popular = api('/x/web-interface/popular');
  static final videoView = api('/x/web-interface/view');
  static final videoPlayUrl = api('/x/player/wbi/playurl');
  static final audioStreamUrl = api('/audio/music-service-c/url');
  static final favoriteFolders = api('/x/v3/fav/folder/created/list-all');
  static final favoriteFolderInfo = api('/x/v3/fav/folder/info');
  static final favoriteFolderItems = api('/x/v3/fav/resource/list');
  static final historyCursor = api('/x/web-interface/history/cursor');

  static final hotWords = search('/main/hotword');
  static final suggest = search('/main/suggest');

  static final qrGenerate = passport(
    '/x/passport-login/web/qrcode/generate',
    const <String, String>{'source': 'main-fe-header'},
  );
  static final qrPoll = passport('/x/passport-login/web/qrcode/poll');
  static final cookieInfo = passport('/x/passport-login/web/cookie/info');
  static final cookieRefresh = passport('/x/passport-login/web/cookie/refresh');
}
