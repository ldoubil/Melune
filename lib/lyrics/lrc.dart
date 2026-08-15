import 'package:melune/bili/models.dart';

final _timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _metaTag = RegExp(r'^\[(ti|ar|al|by|offset|length):', caseSensitive: false);

List<MeluneLyricLine> parseTimedLyrics(String raw, {String translation = ''}) {
  final origin = _parseSheet(raw);
  if (origin.isEmpty) {
    return const [];
  }
  if (translation.trim().isEmpty) {
    return origin;
  }
  final mapped = {
    for (final line in _parseSheet(translation)) line.from: line.content,
  };
  return [
    for (final line in origin)
      MeluneLyricLine(
        from: line.from,
        to: line.to,
        content: () {
          final extra = mapped[line.from];
          if (extra == null || extra.isEmpty || extra == line.content) {
            return line.content;
          }
          return '${line.content}\n$extra';
        }(),
      ),
  ];
}

bool looksLikeTimedLyrics(String raw) {
  return _parseSheet(raw).length >= 3;
}

String foldLyricKey(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    var code = rune;
    if (code >= 0xFF01 && code <= 0xFF5E) {
      code = code - 0xFEE0;
    }
    final char = String.fromCharCode(code);
    if (RegExp(r'[a-z0-9\u3400-\u9fff]').hasMatch(char)) {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

double lyricMatchScore({
  required String wantTitle,
  required String wantArtist,
  required int wantDurationSec,
  required String gotTitle,
  required String gotArtist,
  required int gotDurationSec,
}) {
  final title = _similarity(foldLyricKey(wantTitle), foldLyricKey(gotTitle));
  final artistWant = foldLyricKey(wantArtist);
  final artistGot = foldLyricKey(gotArtist);
  final artist = artistWant.isEmpty
      ? 0.5
      : _similarity(artistWant, artistGot);
  var duration = 0.5;
  if (wantDurationSec >= 60 &&
      wantDurationSec <= 480 &&
      gotDurationSec > 0) {
    final diff = (wantDurationSec - gotDurationSec).abs();
    duration = diff <= 2
        ? 1
        : diff <= 8
            ? 0.74
            : diff <= 20
                ? 0.42
                : 0.16;
  }
  return title * 0.66 + artist * 0.18 + duration * 0.16;
}

List<MeluneLyricLine> _parseSheet(String raw) {
  final stamps = <Duration, String>{};
  for (final chunk in raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    final line = chunk.trim();
    if (line.isEmpty || _metaTag.hasMatch(line)) {
      continue;
    }
    final times = _timeTag.allMatches(line).toList(growable: false);
    if (times.isEmpty) {
      continue;
    }
    final text = line.replaceAll(_timeTag, '').trim();
    if (text.isEmpty || _isCreditOnly(text)) {
      continue;
    }
    for (final match in times) {
      stamps[_parseClock(match)] = text;
    }
  }
  if (stamps.isEmpty) {
    return const [];
  }
  final ordered = stamps.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return [
    for (var i = 0; i < ordered.length; i++)
      MeluneLyricLine(
        from: ordered[i].key,
        to: i + 1 < ordered.length
            ? ordered[i + 1].key
            : ordered[i].key + const Duration(seconds: 5),
        content: ordered[i].value,
      ),
  ];
}

Duration _parseClock(RegExpMatch match) {
  final minutes = int.parse(match.group(1)!);
  final seconds = int.parse(match.group(2)!);
  final fraction = match.group(3) ?? '';
  var millis = 0;
  if (fraction.isNotEmpty) {
    millis = int.parse(fraction.padRight(3, '0').substring(0, 3));
  }
  return Duration(
    milliseconds: ((minutes * 60) + seconds) * 1000 + millis,
  );
}

bool _isCreditOnly(String text) {
  const heads = ['作词', '作曲', '编曲', '制作人', '出品', '演唱', '翻唱'];
  final compact = text.replaceAll(' ', '');
  return heads.any((head) => compact.startsWith(head));
}

double _similarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) {
    return 0;
  }
  if (a == b) {
    return 1;
  }
  if (a.contains(b) || b.contains(a)) {
    final short = a.length < b.length ? a.length : b.length;
    final long = a.length < b.length ? b.length : a.length;
    return 0.78 + 0.22 * (short / long);
  }
  return _dice(a, b);
}

double _dice(String a, String b) {
  if (a.length < 2 || b.length < 2) {
    return a == b ? 1 : 0;
  }
  final left = <String>{};
  final right = <String>{};
  for (var i = 0; i < a.length - 1; i++) {
    left.add(a.substring(i, i + 2));
  }
  for (var i = 0; i < b.length - 1; i++) {
    right.add(b.substring(i, i + 2));
  }
  var hit = 0;
  for (final gram in left) {
    if (right.contains(gram)) {
      hit++;
    }
  }
  return (2 * hit) / (left.length + right.length);
}
