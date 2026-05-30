class BiliApiException implements Exception {
  const BiliApiException(this.message, {this.code, this.details});

  final String message;
  final int? code;
  final Object? details;

  @override
  String toString() {
    final prefix = code == null
        ? 'BiliApiException'
        : 'BiliApiException($code)';
    return '$prefix: $message';
  }
}
