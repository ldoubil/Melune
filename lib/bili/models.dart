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

  static const guest = MeluneUser(
    isLogin: false,
    mid: 0,
    name: '',
    face: '',
  );
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
  });

  final int id;
  final String title;
  final int mediaCount;
  final String coverUrl;
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
      subtitle: subtitle.isNotEmpty
          ? subtitle
          : '${tracks.length} 首',
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
      title: folder.title,
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

  MeluneAlbum copyWith({List<MeluneTrack>? tracks, String? coverUrl}) {
    return MeluneAlbum(
      id: id,
      title: title,
      subtitle: subtitle,
      coverUrl: coverUrl ?? this.coverUrl,
      tracks: tracks ?? this.tracks,
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

  bool get isHiRes =>
      id == 30251 || id == 30252 || label.contains('Hi-Res');

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
