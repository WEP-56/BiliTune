import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/models.dart';

class BiliCookieStore {
  BiliCookieStore(this._prefs);

  static const _credentialKey = 'bili_credential';

  final SharedPreferencesAsync _prefs;
  BiliCredential? _cachedCredential;
  bool _credentialLoaded = false;

  Future<BiliCredential?> readCredential() async {
    if (_credentialLoaded) return _cachedCredential;

    final raw = await _prefs.getString(_credentialKey);
    if (raw == null || raw.isEmpty) {
      _credentialLoaded = true;
      _cachedCredential = null;
      return null;
    }

    try {
      final json = jsonDecode(raw) as Map;
      _cachedCredential = BiliCredential.fromJson(
        Map<String, dynamic>.from(json),
      );
      _credentialLoaded = true;
      return _cachedCredential;
    } catch (_) {
      await clearCredential();
      return null;
    }
  }

  Future<String> readCookieHeader() async {
    final credential = await readCredential();
    return credential?.cookieHeader ?? _headerFromCredential(credential) ?? '';
  }

  Future<void> saveCredential(BiliCredential credential) async {
    _cachedCredential = credential;
    _credentialLoaded = true;
    await _prefs.setString(_credentialKey, jsonEncode(credential.toJson()));
  }

  Future<void> saveManualCookieHeader(String cookieHeader) async {
    final parsed = _parseCookieHeader(cookieHeader);
    await saveCredential(_credentialFromCookieMap(parsed, cookieHeader));
  }

  Future<void> saveFromSetCookieHeaders(List<String> headers) async {
    if (headers.isEmpty) return;

    final current = await readCredential();
    final currentMap = _parseCookieHeader(current?.cookieHeader ?? '');
    final nextMap = <String, String>{...currentMap};

    for (final header in headers) {
      final cookie = _parseSetCookie(header);
      if (cookie == null) continue;
      nextMap[cookie.$1] = cookie.$2;
    }

    if (nextMap.isEmpty) return;
    await saveCredential(
      _credentialFromCookieMap(nextMap, _serialize(nextMap)),
    );
  }

  Future<void> clearCredential() {
    _cachedCredential = null;
    _credentialLoaded = true;
    return _prefs.remove(_credentialKey);
  }

  BiliCredential _credentialFromCookieMap(
    Map<String, String> cookies,
    String cookieHeader,
  ) {
    int? parseInt(String? value) => value == null ? null : int.tryParse(value);

    return BiliCredential(
      sessdata: cookies['SESSDATA'],
      biliJct: cookies['bili_jct'],
      dedeUserId: cookies['DedeUserID'],
      acTimeValue: cookies['ac_time_value'],
      mid: parseInt(cookies['DedeUserID']),
      cookieHeader: cookieHeader,
    );
  }

  String? _headerFromCredential(BiliCredential? credential) {
    if (credential == null) return null;
    final cookies = <String, String>{
      if (credential.sessdata?.isNotEmpty ?? false)
        'SESSDATA': credential.sessdata!,
      if (credential.biliJct?.isNotEmpty ?? false)
        'bili_jct': credential.biliJct!,
      if (credential.dedeUserId?.isNotEmpty ?? false)
        'DedeUserID': credential.dedeUserId!,
      if (credential.acTimeValue?.isNotEmpty ?? false)
        'ac_time_value': credential.acTimeValue!,
    };
    if (cookies.isEmpty) return null;
    return _serialize(cookies);
  }

  Map<String, String> _parseCookieHeader(String header) {
    final cookies = <String, String>{};
    for (final part in header.split(';')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final name = part.substring(0, index).trim();
      final value = part.substring(index + 1).trim();
      if (name.isNotEmpty) cookies[name] = value;
    }
    return cookies;
  }

  (String, String)? _parseSetCookie(String header) {
    final first = header.split(';').first;
    final index = first.indexOf('=');
    if (index <= 0) return null;
    final name = first.substring(0, index).trim();
    final value = first.substring(index + 1).trim();
    if (name.isEmpty) return null;
    return (name, value);
  }

  String _serialize(Map<String, String> cookies) =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
}
