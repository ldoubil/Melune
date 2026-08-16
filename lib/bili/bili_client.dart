import 'package:melune/bili/models.dart';

abstract class BiliClient {
  Future<MeluneUser> init(String cookieDir);

  Future<MeluneUser> nav();

  Future<void> logout();

  Future<MeluneQrCode> qrGenerate();

  Future<MeluneQrPoll> qrPoll(String qrcodeKey);

  Future<MeluneSearchPage> search(String keyword, {int page = 1});

  Future<List<MeluneTrack>> videoPages(String bvid);

  Future<List<MeluneTrack>> seasonTracks({
    required int mid,
    required int seasonId,
  });

  Future<MeluneExtractedAudio> extractAudio(
    MeluneTrack track, {
    int qualityId = 0,
  });

  Future<String> proxyUrl(String audioUrl);

  Future<List<MeluneTrack>> musicRank();

  Future<List<MeluneTrack>> newSongs();

  Future<List<MeluneTrack>> musicRegion({int page = 1});

  Future<List<MeluneTrack>> musicZone({int cateId = 0, int page = 1});

  Future<List<MeluneTrack>> musicRecommend();

  Future<List<MeluneFavoriteFolder>> favoriteFolders({int rid = 0});

  Future<MeluneFavoriteFolder> createFavoriteFolder(String title);

  Future<void> dealFavorite({
    required int rid,
    required String bvid,
    required List<int> addIds,
    required List<int> delIds,
  });

  Future<MeluneSearchPage> favoriteTracks(int mediaId, {int page = 1});

  Future<MeluneHistoryPage> history({int cursorMax = 0, int cursorViewAt = 0});

  Future<List<MeluneLyricLine>> officialLyrics(String bvid, int cid);

  Future<MeluneUpProfile> userCard(int mid);

  Future<MeluneSearchPage> userArchives(int mid, {int page = 1});

  String cleanTitle(String title);
}
