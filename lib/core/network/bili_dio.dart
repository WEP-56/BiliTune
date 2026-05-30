import 'package:dio/dio.dart';

import 'bili_cookie_store.dart';

const biliUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36';

const biliReferer = 'https://www.bilibili.com/';

class BiliDioFactory {
  const BiliDioFactory._();

  static Dio create(BiliCookieStore cookieStore) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: const <String, Object>{
          'User-Agent': biliUserAgent,
          'Referer': biliReferer,
          'Origin': 'https://www.bilibili.com',
          'Accept': 'application/json, text/plain, */*',
        },
      ),
    );
    dio.interceptors.add(_BiliCookieInterceptor(cookieStore));
    return dio;
  }
}

class _BiliCookieInterceptor extends Interceptor {
  _BiliCookieInterceptor(this._cookieStore);

  final BiliCookieStore _cookieStore;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final cookie = await _cookieStore.readCookieHeader();
    if (cookie.isNotEmpty && !options.headers.containsKey('Cookie')) {
      options.headers['Cookie'] = cookie;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final cookies = response.headers.map['set-cookie'] ?? const <String>[];
    if (cookies.isNotEmpty) {
      await _cookieStore.saveFromSetCookieHeaders(cookies);
    }
    handler.next(response);
  }
}
