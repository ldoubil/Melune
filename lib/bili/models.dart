import 'package:melune/bili/melune_fav.dart';

class MeluneUser {
  const MeluneUser({
    required this.isLogin,
    required this.mid,
    required this.name,
    required this.face,
    this.isVip = false,
  });

  final bool isLogin;
  final int mid;
  final String name;
  final String face;
  final bool isVip;

  static const guest = MeluneUser(isLogin: false, mid: 0, name: '', face: '');
}

class MeluneTrack {
  const MeluneTrack({
    required this.id,
    required this.bvid,
    required this.aid,
    required this.cid,
    required this.title,
    required this.artist,
    required this.albumTitle,
    required this.coverUrl,
    required this.durationSec,
    required this.playCount,
    this.audioUrl = '',
    this.pageCount = 1,
    this.seasonId = 0,
    this.upMid = 0,
  });

  final String id;
  final String bvid;
  final int aid;
  final int cid;
  final String title;
  final String artist;
  final String albumTitle;
  final String coverUrl;
  final int durationSec;
  final int playCount;
  final String audioUrl;
  final int pageCount;
  final int seasonId;
  final int upMid;

  Duration get duration => Duration(seconds: durationSec);

  bool get isPlaylist => pageCount > 1;

  MeluneTrack copyWith({
    int? cid,
    String? title,
    String? audioUrl,
    String? albumTitle,
    String? coverUrl,
    int? durationSec,
    int? pageCount,
    int? seasonId,
    int? upMid,
  }) {
    return MeluneTrack(
      id: id,
      bvid: bvid,
      aid: aid,
      cid: cid ?? this.cid,
      title: title ?? this.title,
      artist: artist,
      albumTitle: albumTitle ?? this.albumTitle,
      coverUrl: coverUrl ?? this.coverUrl,
      durationSec: durationSec ?? this.durationSec,
      playCount: playCount,
      audioUrl: audioUrl ?? this.audioUrl,
      pageCount: pageCount ?? this.pageCount,
      seasonId: seasonId ?? this.seasonId,
      upMid: upMid ?? this.upMid,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'bvid': bvid,
    'aid': aid,
    'cid': cid,
    'title': title,
    'artist': artist,
    'albumTitle': albumTitle,
    'coverUrl': coverUrl,
    'durationSec': durationSec,
    'playCount': playCount,
    'pageCount': pageCount,
    'seasonId': seasonId,
    'upMid': upMid,
  };

  static MeluneTrack? tryParse(Object? raw) {
    final json = raw is Map ? Map<String, Object?>.from(raw) : null;
    if (json == null) {
      return null;
    }
    final bvid = json['bvid'] as String? ?? '';
    final id = json['id'] as String? ?? bvid;
    if (id.isEmpty && bvid.isEmpty) {
      return null;
    }
    return MeluneTrack(
      id: id.isEmpty ? bvid : id,
      bvid: bvid,
      aid: (json['aid'] as num?)?.toInt() ?? 0,
      cid: (json['cid'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      albumTitle: json['albumTitle'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 1,
      seasonId: (json['seasonId'] as num?)?.toInt() ?? 0,
      upMid: (json['upMid'] as num?)?.toInt() ?? 0,
    );
  }
}

class MeluneSearchPage {
  const MeluneSearchPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalResults,
  });

  final List<MeluneTrack> items;
  final int page;
  final int totalPages;
  final int totalResults;
}

class MeluneQrCode {
  const MeluneQrCode({required this.url, required this.qrcodeKey});

  final String url;
  final String qrcodeKey;
}

class MeluneQrPoll {
  const MeluneQrPoll({
    required this.code,
    required this.message,
    required this.loggedIn,
  });

  final int code;
  final String message;
  final bool loggedIn;
}

class MeluneFavoriteFolder {
  const MeluneFavoriteFolder({
    required this.id,
    required this.title,
    required this.mediaCount,
    required this.coverUrl,
    this.favState = false,
  });

  final int id;
  final String title;
  final int mediaCount;
  final String coverUrl;
  final bool favState;

  bool get isMelune => isMeluneFavTitle(title);

  bool get isDefault =>
      title.trim() == kMeluneDefaultFavTitle ||
      displayTitle == kMeluneDefaultFavName;

  String get displayTitle => meluneFavDisplayTitle(title);

  MeluneFavoriteFolder copyWith({
    int? mediaCount,
    String? coverUrl,
    bool? favState,
  }) {
    return MeluneFavoriteFolder(
      id: id,
      title: title,
      mediaCount: mediaCount ?? this.mediaCount,
      coverUrl: coverUrl ?? this.coverUrl,
      favState: favState ?? this.favState,
    );
  }
}

class MeluneAlbum {
  const MeluneAlbum({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    this.tracks = const [],
    this.bvid = '',
    this.folderId = 0,
    this.seasonId = 0,
    this.upMid = 0,
  });

  factory MeluneAlbum.fromTrack(MeluneTrack track) {
    final playlist = track.isPlaylist;
    final parts = <String>[
      if (playlist && track.pageCount > 1) '${track.pageCount} 首',
      if (track.artist.isNotEmpty) track.artist,
    ];
    return MeluneAlbum(
      id: track.seasonId > 0
          ? 'season-${track.seasonId}'
          : (track.bvid.isNotEmpty ? track.bvid : track.id),
      title: playlist && track.albumTitle.isNotEmpty
          ? track.albumTitle
          : (track.albumTitle.isNotEmpty ? track.albumTitle : track.title),
      subtitle: parts.isEmpty ? 'Bilibili 音乐' : parts.join(' · '),
      coverUrl: track.coverUrl,
      tracks: [track],
      bvid: track.bvid,
      seasonId: track.seasonId,
      upMid: track.upMid,
    );
  }

  factory MeluneAlbum.fromTracks({
    required String id,
    required String title,
    required List<MeluneTrack> tracks,
    String subtitle = '',
    String coverUrl = '',
  }) {
    return MeluneAlbum(
      id: id,
      title: title,
      subtitle: subtitle.isNotEmpty ? subtitle : '${tracks.length} 首',
      coverUrl: coverUrl.isNotEmpty
          ? coverUrl
          : (tracks.isEmpty ? '' : tracks.first.coverUrl),
      tracks: tracks,
      bvid: tracks.length == 1 ? tracks.first.bvid : '',
    );
  }

  factory MeluneAlbum.fromFolder(MeluneFavoriteFolder folder) {
    return MeluneAlbum(
      id: 'fav-${folder.id}',
      title: folder.displayTitle,
      subtitle: '${folder.mediaCount} 首',
      coverUrl: folder.coverUrl,
      folderId: folder.id,
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String coverUrl;
  final List<MeluneTrack> tracks;
  final String bvid;
  final int folderId;
  final int seasonId;
  final int upMid;

  MeluneAlbum copyWith({
    List<MeluneTrack>? tracks,
    String? coverUrl,
    String? subtitle,
  }) {
    final nextTracks = tracks ?? this.tracks;
    final nextCover = coverUrl ?? this.coverUrl;
    return MeluneAlbum(
      id: id,
      title: title,
      subtitle:
          subtitle ??
          (tracks != null && folderId > 0
              ? '${nextTracks.length} 首'
              : this.subtitle),
      coverUrl: nextCover.isNotEmpty
          ? nextCover
          : (nextTracks.isEmpty ? this.coverUrl : nextTracks.first.coverUrl),
      tracks: nextTracks,
      bvid: bvid,
      folderId: folderId,
      seasonId: seasonId,
      upMid: upMid,
    );
  }
}

List<MeluneAlbum> albumsFromTracks(List<MeluneTrack> tracks) {
  final seen = <String>{};
  final albums = <MeluneAlbum>[];
  for (final track in tracks) {
    final album = MeluneAlbum.fromTrack(track);
    if (!seen.add(album.id)) {
      continue;
    }
    albums.add(album);
  }
  return albums;
}

List<MeluneAlbum> playlistsFromTracks(List<MeluneTrack> tracks) {
  return albumsFromTracks([
    for (final track in tracks)
      if (track.isPlaylist) track,
  ]);
}

List<MeluneTrack> singlesFromTracks(List<MeluneTrack> tracks) {
  return [
    for (final track in tracks)
      if (!track.isPlaylist) track,
  ];
}

String formatPlayCount(int count) {
  if (count >= 100000000) {
    return '${(count / 100000000).toStringAsFixed(1)}亿';
  }
  if (count >= 10000) {
    return '${(count / 10000).toStringAsFixed(1)}万';
  }
  if (count > 0) {
    return '$count';
  }
  return '';
}

class MeluneMusicZone {
  const MeluneMusicZone({required this.cateId, required this.label});

  final int cateId;
  final String label;
}

/// 对齐 B 站音乐分区页 https://www.bilibili.com/c/music/ 的歌曲向子区。
const kMeluneMusicZones = [
  MeluneMusicZone(cateId: 0, label: '全部'),
  MeluneMusicZone(cateId: 28, label: '原创'),
  MeluneMusicZone(cateId: 31, label: '翻唱'),
  MeluneMusicZone(cateId: 30, label: 'VOCALOID'),
  MeluneMusicZone(cateId: 59, label: '演奏'),
  MeluneMusicZone(cateId: 193, label: 'MV'),
  MeluneMusicZone(cateId: 194, label: '电音'),
];

class MeluneHistoryPage {
  const MeluneHistoryPage({
    required this.tracks,
    required this.hasMore,
    required this.cursorMax,
    required this.cursorViewAt,
  });

  final List<MeluneTrack> tracks;
  final bool hasMore;
  final int cursorMax;
  final int cursorViewAt;
}

class MeluneUpProfile {
  const MeluneUpProfile({
    required this.mid,
    required this.name,
    this.face = '',
    this.sign = '',
    this.fans = 0,
    this.archiveCount = 0,
  });

  final int mid;
  final String name;
  final String face;
  final String sign;
  final int fans;
  final int archiveCount;
}

class MeluneLyricLine {
  const MeluneLyricLine({
    required this.from,
    required this.to,
    required this.content,
  });

  final Duration from;
  final Duration to;
  final String content;
}

class MeluneAudioQuality {
  const MeluneAudioQuality({
    required this.id,
    required this.label,
    required this.detail,
    required this.bandwidth,
    required this.vipOnly,
    this.audioUrl = '',
  });

  final int id;
  final String label;
  final String detail;
  final int bandwidth;
  final bool vipOnly;
  final String audioUrl;

  bool get isHiRes => id == 30251 || id == 30252 || label.contains('Hi-Res');

  bool get isDolby => id == 30250 || label.contains('杜比');
}

class MeluneExtractedAudio {
  const MeluneExtractedAudio({
    required this.track,
    required this.qualities,
    required this.selectedId,
  });

  final MeluneTrack track;
  final List<MeluneAudioQuality> qualities;
  final int selectedId;

  MeluneAudioQuality? get selected {
    for (final item in qualities) {
      if (item.id == selectedId) {
        return item;
      }
    }
    return qualities.isEmpty ? null : qualities.first;
  }
}
