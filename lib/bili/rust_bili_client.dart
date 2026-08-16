import 'package:melune/bili/bili_client.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/src/rust/api/bili.dart' as rust;

class RustBiliClient implements BiliClient {
  @override
  Future<MeluneUser> init(String cookieDir) async {
    final result = await rust.biliInit(cookieDir: cookieDir);
    return _user(result.user);
  }

  @override
  Future<MeluneUser> nav() async => _user(await rust.biliNav());

  @override
  Future<void> logout() => rust.biliLogout();

  @override
  Future<MeluneQrCode> qrGenerate() async {
    final data = await rust.biliQrGenerate();
    return MeluneQrCode(url: data.url, qrcodeKey: data.qrcodeKey);
  }

  @override
  Future<MeluneQrPoll> qrPoll(String qrcodeKey) async {
    final data = await rust.biliQrPoll(qrcodeKey: qrcodeKey);
    return MeluneQrPoll(
      code: data.code,
      message: data.message,
      loggedIn: data.loggedIn,
    );
  }

  @override
  Future<MeluneSearchPage> search(String keyword, {int page = 1}) async {
    return _search(await rust.biliSearch(keyword: keyword, page: page));
  }

  @override
  Future<List<MeluneTrack>> videoPages(String bvid) async {
    final pages = await rust.biliVideoPages(bvid: bvid);
    return pages.map(_track).toList();
  }

  @override
  Future<List<MeluneTrack>> seasonTracks({
    required int mid,
    required int seasonId,
  }) async {
    final tracks = await rust.biliSeasonTracks(
      mid: _i64(mid),
      seasonId: _i64(seasonId),
    );
    return tracks.map(_track).toList();
  }

  @override
  Future<MeluneExtractedAudio> extractAudio(
    MeluneTrack track, {
    int qualityId = 0,
  }) async {
    final sourced = await rust.biliExtractAudio(
      bvid: track.bvid,
      aid: _i64(track.aid),
      cid: _i64(track.cid),
      qualityId: qualityId,
    );
    final mapped = _track(sourced.track).copyWith(
      title: sourced.track.title.isEmpty ? track.title : sourced.track.title,
      albumTitle: sourced.track.albumTitle.isEmpty
          ? track.albumTitle
          : sourced.track.albumTitle,
      coverUrl: sourced.track.coverUrl.isEmpty
          ? track.coverUrl
          : sourced.track.coverUrl,
    );
    return MeluneExtractedAudio(
      track: mapped,
      qualities: sourced.qualities.map(_quality).toList(),
      selectedId: sourced.selectedId,
    );
  }

  @override
  Future<String> proxyUrl(String audioUrl) {
    return rust.biliProxyUrl(audioUrl: audioUrl);
  }

  @override
  Future<List<MeluneTrack>> musicRank() async {
    return (await rust.biliMusicRank()).map(_track).toList();
  }

  @override
  Future<List<MeluneTrack>> newSongs() async {
    return (await rust.biliNewSongs()).map(_track).toList();
  }

  @override
  Future<List<MeluneTrack>> musicRegion({int page = 1}) async {
    return (await rust.biliMusicRegion(page: page)).map(_track).toList();
  }

  @override
  Future<List<MeluneTrack>> musicZone({int cateId = 0, int page = 1}) async {
    return (await rust.biliMusicZone(
      cateId: _i64(cateId),
      page: page,
    )).map(_track).toList();
  }

  @override
  Future<List<MeluneTrack>> musicRecommend() async {
    return (await rust.biliMusicRecommend()).map(_track).toList();
  }

  @override
  Future<List<MeluneFavoriteFolder>> favoriteFolders({int rid = 0}) async {
    final folders = await rust.biliFavoriteFolders(rid: _i64(rid));
    return folders
        .map(
          (folder) => MeluneFavoriteFolder(
            id: _toInt(folder.id),
            title: folder.title,
            mediaCount: folder.mediaCount,
            coverUrl: folder.coverUrl,
            favState: folder.favState,
          ),
        )
        .toList();
  }

  @override
  Future<MeluneFavoriteFolder> createFavoriteFolder(String title) async {
    final folder = await rust.biliCreateFavoriteFolder(title: title);
    return MeluneFavoriteFolder(
      id: _toInt(folder.id),
      title: folder.title.isEmpty ? title : folder.title,
      mediaCount: folder.mediaCount,
      coverUrl: folder.coverUrl,
      favState: folder.favState,
    );
  }

  @override
  Future<void> dealFavorite({
    required int rid,
    required String bvid,
    required List<int> addIds,
    required List<int> delIds,
  }) {
    return rust.biliDealFavorite(
      rid: _i64(rid),
      bvid: bvid,
      addMediaIds: addIds.join(','),
      delMediaIds: delIds.join(','),
    );
  }

  @override
  Future<MeluneSearchPage> favoriteTracks(int mediaId, {int page = 1}) async {
    return _search(
      await rust.biliFavoriteTracks(mediaId: _i64(mediaId), page: page),
    );
  }

  @override
  Future<MeluneHistoryPage> history({
    int cursorMax = 0,
    int cursorViewAt = 0,
  }) async {
    final page = await rust.biliHistory(
      cursorMax: _i64(cursorMax),
      cursorViewAt: _i64(cursorViewAt),
    );
    return MeluneHistoryPage(
      tracks: page.tracks.map(_track).toList(),
      hasMore: page.hasMore,
      cursorMax: _toInt(page.cursorMax),
      cursorViewAt: _toInt(page.cursorViewAt),
    );
  }

  @override
  Future<List<MeluneLyricLine>> officialLyrics(String bvid, int cid) async {
    final lines = await rust.biliOfficialLyrics(bvid: bvid, cid: _i64(cid));
    return lines
        .map(
          (line) => MeluneLyricLine(
            from: Duration(milliseconds: line.fromMs),
            to: Duration(milliseconds: line.toMs),
            content: line.content,
          ),
        )
        .toList();
  }

  @override
  Future<MeluneUpProfile> userCard(int mid) async {
    final card = await rust.biliUserCard(mid: _i64(mid));
    return MeluneUpProfile(
      mid: _toInt(card.mid),
      name: card.name,
      face: card.face,
      sign: card.sign,
      fans: _toInt(card.fans),
      archiveCount: card.archiveCount,
    );
  }

  @override
  Future<MeluneSearchPage> userArchives(int mid, {int page = 1}) async {
    return _search(await rust.biliUserArchives(mid: _i64(mid), page: page));
  }

  @override
  String cleanTitle(String title) => rust.biliCleanTitle(title: title);
}

int _toInt(Object value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString()) ?? 0;
}

dynamic _i64(int value) => value;

MeluneUser _user(rust.BiliUser user) {
  return MeluneUser(
    isLogin: user.isLogin,
    mid: _toInt(user.mid),
    name: user.name,
    face: user.face,
    isVip: user.isVip,
  );
}

MeluneAudioQuality _quality(rust.BiliAudioQuality item) {
  return MeluneAudioQuality(
    id: item.id,
    label: item.label,
    detail: item.detail,
    bandwidth: _toInt(item.bandwidth),
    vipOnly: item.vipOnly,
    audioUrl: item.audioUrl,
  );
}

MeluneTrack _track(rust.BiliTrack track) {
  return MeluneTrack(
    id: track.id,
    bvid: track.bvid,
    aid: _toInt(track.aid),
    cid: _toInt(track.cid),
    title: track.title,
    artist: track.artist,
    albumTitle: track.albumTitle,
    coverUrl: track.coverUrl,
    durationSec: track.durationSec,
    playCount: _toInt(track.playCount),
    audioUrl: track.audioUrl,
    pageCount: track.pageCount,
    seasonId: _toInt(track.seasonId),
    upMid: _toInt(track.upMid),
  );
}

MeluneSearchPage _search(rust.BiliSearchPage page) {
  return MeluneSearchPage(
    items: page.items.map(_track).toList(),
    page: page.page,
    totalPages: page.totalPages,
    totalResults: _toInt(page.totalResults),
  );
}
