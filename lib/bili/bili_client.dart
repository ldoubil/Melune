import 'package:melune/bili/models.dart';

abstract class BiliClient {
  Future<MeluneUser> init(String cookieDir);

  Future<MeluneUser> nav();

  Future<void> logout();

  Future<MeluneQrCode> qrGenerate();

  Future<MeluneQrPoll> qrPoll(String qrcodeKey);

  Future<MeluneSearchPage> search(String keyword, {int page = 1});

  Future<List<MeluneTrack>> videoPages(String bvid);

  Future<MeluneExtractedAudio> extractAudio(
    MeluneTrack track, {
    int qualityId = 0,
  });


  Future<String> proxyUrl(String audioUrl);

  Future<List<MeluneTrack>> musicRank();

  Future<List<MeluneTrack>> newSongs();

  Future<List<MeluneTrack>> musicRegion({int page = 1});

  Future<List<MeluneTrack>> musicRecommend();

  Future<List<MeluneFavoriteFolder>> favoriteFolders();

  Future<MeluneSearchPage> favoriteTracks(int mediaId, {int page = 1});

  Future<MeluneHistoryPage> history({int cursorMax = 0, int cursorViewAt = 0});

  Future<List<MeluneLyricLine>> officialLyrics(String bvid, int cid);

  String cleanTitle(String title);
}
