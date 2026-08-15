import 'dart:convert';
import 'dart:io';

import 'package:melune/bili/models.dart';
import 'package:melune/lyrics/lrc.dart';

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/125.0.0.0 Safari/537.36';

bool _isGenericArtist(String artist) {
  final key = foldLyricKey(artist);
  return key.isEmpty ||
      key == 'bilibili' ||
      key == 'bilibili音乐' ||
      key == '哔哩哔哩' ||
      key == '哔哩哔哩音乐';
}

Future<List<MeluneLyricLine>> matchCatalogLyrics({
  required String title,
  String artist = '',
  Duration duration = Duration.zero,
}) async {
  final song = title.trim();
  if (song.isEmpty) {
    return const [];
  }
  final singer = _isGenericArtist(artist) ? '' : artist.trim();
  final queries = <String>{
    song,
    if (singer.isNotEmpty) '$song $singer',
  };
  final hits = <_Hit>[];
  await Future.wait([
    for (final query in queries) ...[
      _collect(hits, () => _searchNetease(query, song, singer, duration)),
      _collect(hits, () => _searchQq(query, song, singer, duration)),
      _collect(hits, () => _searchKugou(query, song, singer, duration)),
    ],
  ]);
  hits.sort((a, b) => b.score.compareTo(a.score));
  for (final hit in hits.take(8)) {
    if (hit.score < 0.42) {
      break;
    }
    try {
      final sheet = await hit.load().timeout(const Duration(seconds: 8));
      if (looksLikeTimedLyrics(sheet.lrc)) {
        return parseTimedLyrics(sheet.lrc, translation: sheet.trans);
      }
    } catch (_) {
      continue;
    }
  }
  return const [];
}

Future<void> _collect(
  List<_Hit> hits,
  Future<List<_Hit>> Function() search,
) async {
  try {
    hits.addAll(await search().timeout(const Duration(seconds: 8)));
  } catch (_) {}
}

class _Hit {
  const _Hit({required this.score, required this.load});

  final double score;
  final Future<({String lrc, String trans})> Function() load;
}

Future<List<_Hit>> _searchNetease(
  String query,
  String title,
  String artist,
  Duration duration,
) async {
  final data = await _getJson(
    Uri.https('music.163.com', '/api/search/get/web', {
      's': query,
      'type': '1',
      'offset': '0',
      'limit': '8',
    }),
    referer: 'https://music.163.com/',
  );
  final songs = data['result']?['songs'];
  if (songs is! List) {
    return const [];
  }
  final hits = <_Hit>[];
  for (final raw in songs.take(8)) {
    if (raw is! Map) {
      continue;
    }
    final id = raw['id'];
    if (id == null) {
      continue;
    }
    final names = (raw['artists'] as List?)
            ?.map((item) => item is Map ? '${item['name'] ?? ''}' : '')
            .where((name) => name.isNotEmpty)
            .join(' ') ??
        '';
    final score = lyricMatchScore(
      wantTitle: title,
      wantArtist: artist,
      wantDurationSec: duration.inSeconds,
      gotTitle: '${raw['name'] ?? ''}',
      gotArtist: names,
      gotDurationSec: ((raw['duration'] as num?)?.toInt() ?? 0) ~/ 1000,
    );
    hits.add(
      _Hit(
        score: score,
        load: () async {
          final lyric = await _getJson(
            Uri.https('music.163.com', '/api/song/lyric', {
              'os': 'pc',
              'id': '$id',
              'lv': '-1',
              'tv': '-1',
              'kv': '-1',
            }),
            referer: 'https://music.163.com/',
          );
          return (
            lrc: '${lyric['lrc']?['lyric'] ?? ''}',
            trans: '${lyric['tlyric']?['lyric'] ?? ''}',
          );
        },
      ),
    );
  }
  return hits;
}

Future<List<_Hit>> _searchQq(
  String query,
  String title,
  String artist,
  Duration duration,
) async {
  final data = await _getJson(
    Uri.https('c.y.qq.com', '/soso/fcgi-bin/client_search_cp', {
      'format': 'json',
      'p': '1',
      'n': '8',
      'w': query,
      't': '0',
      'ct': '24',
      'cr': '1',
      'new_json': '1',
      'remoteplace': 'txt.yqq.song',
    }),
    referer: 'https://y.qq.com/',
  );
  final songs = data['data']?['song']?['list'];
  if (songs is! List) {
    return const [];
  }
  final hits = <_Hit>[];
  for (final raw in songs.take(8)) {
    if (raw is! Map) {
      continue;
    }
    final mid = '${raw['mid'] ?? raw['songmid'] ?? ''}';
    if (mid.isEmpty) {
      continue;
    }
    final singers = (raw['singer'] as List?)
            ?.map((item) => item is Map ? '${item['name'] ?? ''}' : '')
            .where((name) => name.isNotEmpty)
            .join(' ') ??
        '';
    final score = lyricMatchScore(
      wantTitle: title,
      wantArtist: artist,
      wantDurationSec: duration.inSeconds,
      gotTitle: '${raw['title'] ?? raw['name'] ?? raw['songname'] ?? ''}',
      gotArtist: singers,
      gotDurationSec: (raw['interval'] as num?)?.toInt() ?? 0,
    );
    hits.add(
      _Hit(
        score: score,
        load: () async {
          final lyric = await _getJson(
            Uri.https('c.y.qq.com', '/lyric/fcgi-bin/fcg_query_lyric_new.fcg', {
              'songmid': mid,
              'g_tk': '5381',
              'loginUin': '0',
              'hostUin': '0',
              'format': 'json',
              'inCharset': 'utf8',
              'outCharset': 'utf-8',
              'notice': '0',
              'platform': 'yqq.json',
              'needNewCode': '0',
            }),
            referer: 'https://y.qq.com/',
          );
          return (
            lrc: _decodeB64('${lyric['lyric'] ?? ''}'),
            trans: _decodeB64('${lyric['trans'] ?? ''}'),
          );
        },
      ),
    );
  }
  return hits;
}

Future<List<_Hit>> _searchKugou(
  String query,
  String title,
  String artist,
  Duration duration,
) async {
  final data = await _getJson(
    Uri.https('mobilecdn.kugou.com', '/api/v3/search/song', {
      'format': 'json',
      'keyword': query,
      'page': '1',
      'pagesize': '8',
      'showtype': '1',
    }),
    referer: 'https://www.kugou.com/',
  );
  final songs = data['data']?['info'];
  if (songs is! List) {
    return const [];
  }
  final hits = <_Hit>[];
  for (final raw in songs.take(8)) {
    if (raw is! Map) {
      continue;
    }
    final hash = '${raw['hash'] ?? raw['FileHash'] ?? ''}';
    if (hash.isEmpty) {
      continue;
    }
    final seconds = (raw['duration'] as num?)?.toInt() ?? 0;
    final score = lyricMatchScore(
      wantTitle: title,
      wantArtist: artist,
      wantDurationSec: duration.inSeconds,
      gotTitle: '${raw['songname'] ?? raw['SongName'] ?? ''}',
      gotArtist: '${raw['singername'] ?? raw['SingerName'] ?? ''}',
      gotDurationSec: seconds,
    );
    final keyword =
        '${raw['singername'] ?? ''} - ${raw['songname'] ?? ''}'.trim();
    hits.add(
      _Hit(
        score: score,
        load: () async {
          final candidates = await _getJson(
            Uri.https('krcs.kugou.com', '/search', {
              'ver': '1',
              'man': 'yes',
              'client': 'mobi',
              'keyword': keyword.isEmpty ? query : keyword,
              'duration': '${seconds * 1000}',
              'hash': hash,
            }),
            referer: 'https://www.kugou.com/',
          );
          final list = candidates['candidates'];
          if (list is! List || list.isEmpty || list.first is! Map) {
            return (lrc: '', trans: '');
          }
          final first = list.first as Map;
          final packed = await _getJson(
            Uri.https('lyrics.kugou.com', '/download', {
              'ver': '1',
              'client': 'pc',
              'id': '${first['id'] ?? ''}',
              'accesskey': '${first['accesskey'] ?? ''}',
              'fmt': 'lrc',
              'charset': 'utf8',
            }),
            referer: 'https://www.kugou.com/',
          );
          return (lrc: _decodeB64('${packed['content'] ?? ''}'), trans: '');
        },
      ),
    );
  }
  return hits;
}

String _decodeB64(String packed) {
  final compact = packed.replaceAll(RegExp(r'\s'), '');
  if (compact.isEmpty) {
    return '';
  }
  try {
    return utf8.decode(base64.decode(compact), allowMalformed: true);
  } catch (_) {
    return '';
  }
}

Future<Map<String, dynamic>> _getJson(
  Uri uri, {
  required String referer,
}) async {
  final client = HttpClient();
  client.userAgent = _ua;
  client.connectionTimeout = const Duration(seconds: 6);
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.refererHeader, referer);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json,text/plain,*/*');
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('lyric http ${response.statusCode}', uri: uri);
    }
    return _asMap(_decodePayload(body));
  } finally {
    client.close(force: true);
  }
}

dynamic _decodePayload(String body) {
  var text = body.trim();
  if (text.isEmpty) {
    return const {};
  }
  if (!text.startsWith('{') && !text.startsWith('[')) {
    final start = text.indexOf('(');
    final end = text.lastIndexOf(')');
    if (start >= 0 && end > start) {
      text = text.substring(start + 1, end);
    }
  }
  return jsonDecode(text);
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const {};
}
