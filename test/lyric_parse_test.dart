import 'package:flutter_test/flutter_test.dart';
import 'package:melune/lyrics/lrc.dart';

void main() {
  test('parses stacked timestamps and translation', () {
    const raw = '''
[ti:demo]
[00:12.50]第一句
[00:16.00][00:32.00]副歌
[01:02.08]结尾
''';
    const trans = '''
[00:12.50]first
[00:16.00]chorus
''';
    final lines = parseTimedLyrics(raw, translation: trans);
    expect(lines, hasLength(4));
    expect(lines.first.content, '第一句\nfirst');
    expect(lines.first.from, const Duration(seconds: 12, milliseconds: 500));
    expect(lines[1].from, const Duration(seconds: 16));
    expect(lines[1].to, const Duration(seconds: 32));
    expect(lines[2].content, '副歌');
    expect(lines.last.from, const Duration(minutes: 1, seconds: 2, milliseconds: 80));
  });

  test('scores an exact title higher than a remix', () {
    const want = '夜航';
    final exact = lyricMatchScore(
      wantTitle: want,
      wantArtist: '陈绮贞',
      wantDurationSec: 240,
      gotTitle: '夜航',
      gotArtist: '陈绮贞',
      gotDurationSec: 241,
    );
    final remix = lyricMatchScore(
      wantTitle: want,
      wantArtist: '陈绮贞',
      wantDurationSec: 240,
      gotTitle: '夜航 remix',
      gotArtist: '路人',
      gotDurationSec: 360,
    );
    expect(exact, greaterThan(remix));
    expect(exact, greaterThan(0.8));
  });
}
