import 'package:flutter_test/flutter_test.dart';
import 'package:melune/player/cover_cache.dart';

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

  test('sizedCoverUrl adds a compact hdslb suffix when missing', () {
    expect(
      sizedCoverUrl('http://i0.hdslb.com/bfs/archive/a.jpg'),
      'https://i0.hdslb.com/bfs/archive/a.jpg@400w_400h_1c.jpg',
    );
    expect(
      sizedCoverUrl('https://i0.hdslb.com/bfs/archive/a.jpg@100w_100h.jpg'),
      'https://i0.hdslb.com/bfs/archive/a.jpg@100w_100h.jpg',
    );
    expect(
      sizedCoverUrl('https://example.com/cover.png'),
      'https://example.com/cover.png',
    );
  });
}
