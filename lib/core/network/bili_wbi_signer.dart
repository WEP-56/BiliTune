import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'bili_api_endpoints.dart';

class BiliWbiSigner {
  BiliWbiSigner(this._dio);

  final Dio _dio;

  _WbiKeys? _cachedKeys;
  DateTime? _cachedAt;

  Future<Map<String, dynamic>> sign(Map<String, dynamic> params) async {
    final keys = await _getKeys();
    if (keys == null) return params;

    final next = <String, dynamic>{
      ...params,
      'wts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    final mixinKey = _mixinKey('${keys.imgKey}${keys.subKey}');
    final filtered = RegExp(r"[!'()*]");

    final query = next.keys.toList()..sort();
    final encoded = query
        .map((key) {
          final value = next[key].toString().replaceAll(filtered, '');
          return '${Uri.encodeQueryComponent(key)}='
              '${Uri.encodeQueryComponent(value)}';
        })
        .join('&');

    final digest = md5.convert('$encoded$mixinKey'.codeUnits).toString();
    return <String, dynamic>{...next, 'w_rid': digest};
  }

  Future<_WbiKeys?> _getKeys() async {
    final now = DateTime.now();
    if (_cachedKeys != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < const Duration(hours: 12)) {
      return _cachedKeys;
    }

    try {
      final response = await _dio.getUri(BiliApiEndpoints.nav);
      final data = _map(response.data)['data'];
      final wbiImg = _map(data)['wbi_img'];
      final imgUrl = _map(wbiImg)['img_url']?.toString();
      final subUrl = _map(wbiImg)['sub_url']?.toString();
      if (imgUrl == null || subUrl == null) return null;

      final keys = _WbiKeys(_fileStem(imgUrl), _fileStem(subUrl));
      if (keys.imgKey.isEmpty || keys.subKey.isEmpty) return null;
      _cachedKeys = keys;
      _cachedAt = now;
      return keys;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  String _fileStem(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final name = path.substring(path.lastIndexOf('/') + 1);
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  String _mixinKey(String source) {
    return _mixinKeyTable
        .where((index) => index < source.length)
        .map((index) => source[index])
        .join()
        .let((value) => value.length <= 32 ? value : value.substring(0, 32));
  }
}

class _WbiKeys {
  const _WbiKeys(this.imgKey, this.subKey);

  final String imgKey;
  final String subKey;
}

const _mixinKeyTable = <int>[
  46,
  47,
  18,
  2,
  53,
  8,
  23,
  32,
  15,
  50,
  10,
  31,
  58,
  3,
  45,
  35,
  27,
  43,
  5,
  49,
  33,
  9,
  42,
  19,
  29,
  28,
  14,
  39,
  12,
  38,
  41,
  13,
  37,
  48,
  7,
  16,
  24,
  55,
  40,
  61,
  26,
  17,
  0,
  1,
  60,
  51,
  30,
  4,
  22,
  25,
  54,
  21,
  56,
  59,
  6,
  63,
  57,
  62,
  11,
  36,
  20,
  34,
  44,
  52,
];

extension _StringLet on String {
  T let<T>(T Function(String value) block) => block(this);
}
