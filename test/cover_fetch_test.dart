import 'package:flutter_test/flutter_test.dart';
import 'package:melune/player/cover_fetch.dart';

void main() {
  test('normalizeCoverUrl upgrades protocol-relative and http to https', () {
    expect(
      normalizeCoverUrl('//i0.hdslb.com/bfs/archive/a.jpg'),
      'https://i0.hdslb.com/bfs/archive/a.jpg',
    );
    expect(
      normalizeCoverUrl('http://i0.hdslb.com/bfs/archive/a.jpg'),
      'https://i0.hdslb.com/bfs/archive/a.jpg',
    );
    expect(
      normalizeCoverUrl('https://i0.hdslb.com/bfs/archive/a.jpg'),
      'https://i0.hdslb.com/bfs/archive/a.jpg',
    );
  });
}
