import '../../core/network/bili_cookie_store.dart';
import '../models/models.dart';
import '../services/bili_api_service.dart';

enum QrLoginStatus { waiting, scanned, confirmed, expired, failed }

class QrLoginSession {
  const QrLoginSession({required this.url, required this.qrcodeKey});

  final String url;
  final String qrcodeKey;
}

class QrLoginPollResult {
  const QrLoginPollResult({
    required this.status,
    this.message,
    this.credential,
  });

  final QrLoginStatus status;
  final String? message;
  final BiliCredential? credential;
}

class BiliAuthRepository {
  BiliAuthRepository(this._api, this._cookieStore);

  final BiliApiService _api;
  final BiliCookieStore _cookieStore;

  Future<BiliCredential?> restoreSession() => _cookieStore.readCredential();

  Future<BiliAccount?> currentAccount() async {
    final data = await _api.nav();
    if (data['isLogin'] != true) return null;
    final account = BiliAccount.fromNavJson(data);
    final credential = await _cookieStore.readCredential();
    if (credential != null) {
      await _cookieStore.saveCredential(
        credential.copyWith(
          mid: account.mid == 0 ? credential.mid : account.mid,
          vipStatus: account.vipStatus,
        ),
      );
    }
    return account;
  }

  Future<void> saveManualCookie(String cookieHeader) =>
      _cookieStore.saveManualCookieHeader(cookieHeader);

  Future<void> logout() => _cookieStore.clearCredential();

  Future<QrLoginSession> createQrLoginSession() async {
    final data = await _api.generateQrLogin();
    return QrLoginSession(
      url: data['url']?.toString() ?? '',
      qrcodeKey: data['qrcode_key']?.toString() ?? '',
    );
  }

  Future<QrLoginPollResult> pollQrLogin(QrLoginSession session) async {
    final data = await _api.pollQrLogin(session.qrcodeKey);
    final code = (data['code'] as num?)?.toInt();
    final message = data['message']?.toString();

    if (code == 0) {
      final credential = await _restoreAfterLogin(data);
      return QrLoginPollResult(
        status: QrLoginStatus.confirmed,
        message: message,
        credential: credential,
      );
    }

    if (code == 86038) {
      return QrLoginPollResult(status: QrLoginStatus.expired, message: message);
    }
    if (code == 86090 || code == 86102) {
      return QrLoginPollResult(status: QrLoginStatus.scanned, message: message);
    }
    if (code == 86101 || code == null) {
      return QrLoginPollResult(status: QrLoginStatus.waiting, message: message);
    }
    return QrLoginPollResult(status: QrLoginStatus.failed, message: message);
  }

  Future<BiliCredential?> _restoreAfterLogin(Map<String, dynamic> data) async {
    var credential = await _cookieStore.readCredential();
    final url = data['url']?.toString();
    if ((credential?.isSignedIn ?? false) || url == null || url.isEmpty) {
      return credential;
    }

    final cookies = _cookiesFromLoginUrl(url);
    if (cookies.isEmpty) return credential;
    await _cookieStore.saveManualCookieHeader(cookies);
    credential = await _cookieStore.readCredential();
    return credential;
  }

  String _cookiesFromLoginUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return '';
    final params = uri.queryParameters;
    final cookies = <String, String>{
      if (params['SESSDATA'] != null) 'SESSDATA': params['SESSDATA']!,
      if (params['bili_jct'] != null) 'bili_jct': params['bili_jct']!,
      if (params['DedeUserID'] != null) 'DedeUserID': params['DedeUserID']!,
      if (params['ac_time_value'] != null)
        'ac_time_value': params['ac_time_value']!,
    };
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}
