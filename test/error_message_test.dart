import 'package:flutter_test/flutter_test.dart';
import 'package:melune/bili/error_message.dart';

void main() {
  test('TLS transport failures are shown as a friendly network hint', () {
    const raw =
        'https://api.bilibili.com/x/v3/fav/resource/list?media_id=1: '
        'Network Error: Network Error: Error encountered in the status line: '
        'received fatal alert: BadRecordMac';
    expect(friendlyErrorMessage(raw), '网络连接不稳定，请稍后重试');
  });

  test('business errors are kept for the user', () {
    const raw = 'B站接口 /x/v3/fav/resource/list 错误 -400：请求错误';
    expect(friendlyErrorMessage(raw), raw);
  });
}
