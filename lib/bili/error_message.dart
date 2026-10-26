/// 把底层异常转成用户能看懂的提示。
///
/// Rust 侧 `ureq` 的错误会带完整请求 URL 和 TLS 细节（例如
/// `received fatal alert: BadRecordMac`），直接展示既占地方也没有指导意义。
String friendlyErrorMessage(Object error) {
  final text = error.toString();
  if (_looksLikeNetworkError(text)) {
    return '网络连接不稳定，请稍后重试';
  }
  return text;
}

bool _looksLikeNetworkError(String text) {
  final lower = text.toLowerCase();
  return _networkHints.any(lower.contains);
}

const _networkHints = <String>[
  'network error',
  'badrecordmac',
  'bad_record_mac',
  'received fatal alert',
  'handshake',
  'unexpected eof',
  'connection failed',
  'connection reset',
  'connection refused',
  'connection closed',
  'socketexception',
  'timed out',
  'timeout',
  'dns failed',
  'proxy failed',
  '连接失败',
  '无法连接',
  '网络异常',
  '请求超时',
];
