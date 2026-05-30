import 'package:dio/dio.dart';

import '../../core/network/bili_api_endpoints.dart';
import '../../core/network/bili_api_exception.dart';
import '../../core/network/bili_cookie_store.dart';
import '../../core/network/bili_wbi_signer.dart';

class BiliApiService {
  BiliApiService(this._dio, this._cookieStore, this._wbiSigner);

  final Dio _dio;
  final BiliCookieStore _cookieStore;
  final BiliWbiSigner _wbiSigner;

  Future<Map<String, dynamic>> nav() async {
    final response = await _dio.getUri(BiliApiEndpoints.nav);
    return _checkedData(response);
  }

  Future<Map<String, dynamic>> searchDefault() async {
    final response = await _get(BiliApiEndpoints.searchDefault, wbi: true);
    return _checkedData(response);
  }

  Future<List<Map<String, dynamic>>> homepageRecommend({
    int freshType = 3,
    int pageSize = 30,
  }) async {
    final response = await _get(
      BiliApiEndpoints.homepageRecommend,
      wbi: true,
      query: <String, dynamic>{'fresh_type': freshType, 'ps': pageSize},
    );
    final data = _checkedData(response);
    return _extractMapList(data['item'] ?? data['items'] ?? data['result']);
  }

  Future<List<Map<String, dynamic>>> popularVideos({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _get(
      BiliApiEndpoints.popular,
      query: <String, dynamic>{'pn': page, 'ps': pageSize},
    );
    final data = _checkedData(response);
    return _extractMapList(data['list'] ?? data['item'] ?? data['items']);
  }

  Future<Object?> hotWords() async {
    final response = await _get(BiliApiEndpoints.hotWords);
    return _json(response)['data'];
  }

  Future<Object?> suggestions(String keyword) async {
    final response = await _get(
      BiliApiEndpoints.suggest,
      query: <String, dynamic>{'term': keyword, 'main_ver': 'v1'},
    );
    return _json(response)['result'] ?? _json(response)['data'];
  }

  Future<List<Map<String, dynamic>>> searchVideos(
    String keyword, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _get(
      BiliApiEndpoints.searchType,
      wbi: true,
      query: <String, dynamic>{
        'keyword': keyword,
        'search_type': 'video',
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = _checkedData(response);
    final result = data['result'];
    if (result is List) {
      return result
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> videoView({String? bvid, int? aid}) async {
    final query = <String, dynamic>{
      ...?(bvid == null ? null : <String, dynamic>{'bvid': bvid}),
      ...?(aid == null ? null : <String, dynamic>{'aid': aid}),
    };
    final response = await _get(BiliApiEndpoints.videoView, query: query);
    return _checkedData(response);
  }

  Future<Map<String, dynamic>> videoPlayUrl({
    required String bvid,
    required int cid,
    int fnval = 4048,
    int fnver = 0,
    int fourk = 1,
  }) async {
    final response = await _get(
      BiliApiEndpoints.videoPlayUrl,
      wbi: true,
      query: <String, dynamic>{
        'bvid': bvid,
        'cid': cid,
        'fnval': fnval,
        'fnver': fnver,
        'fourk': fourk,
      },
    );
    return _checkedData(response);
  }

  Future<Map<String, dynamic>> audioStreamUrl(int songId) async {
    final credential = await _cookieStore.readCredential();
    final response = await _get(
      BiliApiEndpoints.audioStreamUrl,
      query: <String, dynamic>{
        'mid': credential?.mid ?? '',
        'songid': songId,
        'quality': (credential?.vipStatus ?? 0) > 0 ? 3 : 2,
        'privilege': 2,
        'platform': 'web',
      },
    );
    return _checkedData(response);
  }

  Future<Map<String, dynamic>> generateQrLogin() async {
    final response = await _get(BiliApiEndpoints.qrGenerate);
    return _checkedData(response);
  }

  Future<Map<String, dynamic>> pollQrLogin(String qrcodeKey) async {
    final response = await _get(
      BiliApiEndpoints.qrPoll,
      query: <String, dynamic>{
        'qrcode_key': qrcodeKey,
        'source': 'main-fe-header',
      },
    );
    return _checkedData(
      response,
      acceptBusinessCodes: const <int>{0, 86038, 86090, 86101, 86102},
    );
  }

  Future<bool> shouldRefreshCookie(String csrf) async {
    final response = await _get(
      BiliApiEndpoints.cookieInfo,
      query: <String, dynamic>{'csrf': csrf},
    );
    final data = _checkedData(response);
    return data['refresh'] == true;
  }

  Future<List<Map<String, dynamic>>> favoriteFolders({
    required int upMid,
    int type = 2,
    int? rid,
  }) async {
    final query = <String, dynamic>{
      'up_mid': upMid,
      'type': type,
      ...?(rid == null ? null : <String, dynamic>{'rid': rid}),
    };
    final response = await _get(BiliApiEndpoints.favoriteFolders, query: query);
    final data = _checkedData(response);
    return _extractMapList(data['list'] ?? data['items']);
  }

  Future<Map<String, dynamic>> favoriteFolderInfo(int mediaId) async {
    final response = await _get(
      BiliApiEndpoints.favoriteFolderInfo,
      query: <String, dynamic>{'media_id': mediaId},
    );
    return _checkedData(response);
  }

  Future<Map<String, dynamic>> favoriteFolderItems({
    required int mediaId,
    int page = 1,
    int pageSize = 20,
    String order = 'mtime',
    String? keyword,
    int type = 0,
    int tid = 0,
  }) async {
    final response = await _get(
      BiliApiEndpoints.favoriteFolderItems,
      query: <String, dynamic>{
        'media_id': mediaId,
        'pn': page,
        'ps': pageSize,
        'order': order,
        'type': type,
        'tid': tid,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        'platform': 'web',
      },
    );
    return _checkedData(response);
  }

  Future<Map<String, dynamic>> historyCursor({
    String type = 'all',
    int? cursor,
    int? viewAt,
    String? business,
    int? max,
  }) async {
    final response = await _get(
      BiliApiEndpoints.historyCursor,
      query: <String, dynamic>{
        'type': type,
        ...?(cursor == null ? null : <String, dynamic>{'cursor': cursor}),
        ...?(viewAt == null ? null : <String, dynamic>{'view_at': viewAt}),
        ...?((business == null || business.isEmpty)
            ? null
            : <String, dynamic>{'business': business}),
        ...?(max == null ? null : <String, dynamic>{'max': max}),
      },
    );
    return _checkedData(response);
  }

  Future<Response<dynamic>> _get(
    Uri uri, {
    Map<String, dynamic>? query,
    bool wbi = false,
  }) async {
    final merged = <String, dynamic>{...uri.queryParameters, ...?query};
    final params = wbi ? await _wbiSigner.sign(merged) : merged;
    return _dio.getUri(uri.replace(queryParameters: _stringQuery(params)));
  }

  Map<String, dynamic> _checkedData(
    Response response, {
    Set<int> acceptBusinessCodes = const <int>{0},
  }) {
    final body = _json(response);
    final code = (body['code'] as num?)?.toInt();
    if (code != null && !acceptBusinessCodes.contains(code)) {
      throw BiliApiException(
        body['message']?.toString() ?? body['msg']?.toString() ?? 'API failed',
        code: code,
        details: body,
      );
    }
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{'value': data};
  }

  Map<String, dynamic> _json(Response response) {
    if (response.data is Map) return Map<String, dynamic>.from(response.data);
    throw BiliApiException('Unexpected response shape', details: response.data);
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

  List<Map<String, dynamic>> _extractMapList(Object? value) {
    final list = _extractList(value);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Map<String, String> _stringQuery(Map<String, dynamic> params) {
    return params.map((key, value) => MapEntry(key, value.toString()));
  }
}
