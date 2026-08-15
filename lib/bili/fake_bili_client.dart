import 'package:melune/bili/bili_client.dart';
import 'package:melune/bili/models.dart';

class FakeBiliClient implements BiliClient {
  FakeBiliClient({this.loggedIn = false, this.userName = '洛音'});

  bool loggedIn;
  final String userName;

  static const _samples = [
    MeluneTrack(
      id: 'BV1demo1',
      bvid: 'BV1demo1',
      aid: 1,
      cid: 1,
      title: '夜航',
      artist: '洛音',
      albumTitle: '夜航',
      coverUrl: '',
      durationSec: 212,
      playCount: 1000,
    ),
    MeluneTrack(
      id: 'BV1demo2',
      bvid: 'BV1demo2',
      aid: 2,
      cid: 2,
      title: 'Emerald Waves',
      artist: 'Synth Collective',
      albumTitle: 'Emerald Waves',
      coverUrl: '',
      durationSec: 198,
      playCount: 800,
    ),
    MeluneTrack(
      id: 'BV1demo3',
      bvid: 'BV1demo3',
      aid: 3,
      cid: 3,
      title: '午夜回响',
      artist: 'Atlas Bound',
      albumTitle: 'Midnight Resonance',
      coverUrl: '',
      durationSec: 245,
      playCount: 640,
    ),
    MeluneTrack(
      id: 'BV1demo4',
      bvid: 'BV1demo4',
      aid: 4,
      cid: 4,
      title: '深海节拍',
      artist: 'Focus Flow',
      albumTitle: 'Instrumental Beats',
      coverUrl: '',
      durationSec: 186,
      playCount: 420,
    ),
    MeluneTrack(
      id: 'BV1list1',
      bvid: 'BV1list1',
      aid: 5,
      cid: 5,
      title: '夜航全专',
      artist: '洛音',
      albumTitle: '夜航',
      coverUrl: '',
      durationSec: 1200,
      playCount: 2200,
      pageCount: 6,
    ),
  ];

  @override
  Future<MeluneUser> init(String cookieDir) async => nav();

  @override
  Future<MeluneUser> nav() async {
    if (!loggedIn) {
      return MeluneUser.guest;
    }
    return MeluneUser(
      isLogin: true,
      mid: 1,
      name: userName,
      face: '',
      isVip: true,
    );
  }

  @override
  Future<void> logout() async {
    loggedIn = false;
  }

  @override
  Future<MeluneQrCode> qrGenerate() async {
    return const MeluneQrCode(url: 'https://example.com/qr', qrcodeKey: 'fake');
  }

  @override
  Future<MeluneQrPoll> qrPoll(String qrcodeKey) async {
    loggedIn = true;
    return const MeluneQrPoll(code: 0, message: '登录成功', loggedIn: true);
  }

  @override
  Future<MeluneSearchPage> search(String keyword, {int page = 1}) async {
    if (keyword.isEmpty) {
      return const MeluneSearchPage(
        items: [],
        page: 1,
        totalPages: 0,
        totalResults: 0,
      );
    }
    final needle = keyword.toLowerCase();
    final items = _samples
        .where(
          (item) =>
              item.title.toLowerCase().contains(needle) ||
              item.artist.toLowerCase().contains(needle) ||
              item.albumTitle.toLowerCase().contains(needle),
        )
        .toList(growable: false);
    return MeluneSearchPage(
      items: items,
      page: 1,
      totalPages: items.isEmpty ? 0 : 1,
      totalResults: items.length,
    );
  }

  @override
  Future<List<MeluneTrack>> videoPages(String bvid) async {
    final match = _samples.where((item) => item.bvid == bvid);
    if (match.isEmpty) {
      return const [];
    }
    final base = match.first;
    if (base.pageCount <= 1) {
      return [base];
    }
    return [
      for (var i = 1; i <= base.pageCount; i++)
        base.copyWith(title: '${base.title} P$i', cid: i),
    ];
  }

  @override
  Future<List<MeluneTrack>> seasonTracks({
    required int mid,
    required int seasonId,
  }) async {
    return _samples
        .where((item) => item.seasonId == seasonId)
        .toList(growable: false);
  }

  @override
  Future<MeluneExtractedAudio> extractAudio(
    MeluneTrack track, {
    int qualityId = 0,
  }) async {
    const qualities = [
      MeluneAudioQuality(
        id: 30251,
        label: 'Hi-Res无损',
        detail: 'FLAC · 985Kbps',
        bandwidth: 985000,
        vipOnly: true,
      ),
      MeluneAudioQuality(
        id: 30280,
        label: '192Kbps',
        detail: 'AAC · 192Kbps',
        bandwidth: 192000,
        vipOnly: false,
      ),
      MeluneAudioQuality(
        id: 30232,
        label: '132Kbps',
        detail: 'AAC · 132Kbps',
        bandwidth: 132000,
        vipOnly: false,
      ),
    ];
    final selected = qualities.firstWhere(
      (item) => item.id == qualityId,
      orElse: () => qualities.first,
    );
    return MeluneExtractedAudio(
      track: track,
      qualities: qualities,
      selectedId: selected.id,
    );
  }

  @override
  Future<String> proxyUrl(String audioUrl) async => audioUrl;

  @override
  Future<List<MeluneTrack>> musicRank() async => _samples;

  @override
  Future<List<MeluneTrack>> newSongs() async =>
      _samples.take(3).toList(growable: false);

  @override
  Future<List<MeluneTrack>> musicRegion({int page = 1}) async =>
      _samples.reversed.toList(growable: false);

  @override
  Future<List<MeluneTrack>> musicRecommend() async =>
      _samples.skip(1).toList(growable: false);

  @override
  Future<List<MeluneFavoriteFolder>> favoriteFolders() async {
    if (!loggedIn) {
      return const [];
    }
    return const [
      MeluneFavoriteFolder(
        id: 1,
        title: '默认收藏夹',
        mediaCount: 2,
        coverUrl: '',
      ),
    ];
  }

  @override
  Future<MeluneSearchPage> favoriteTracks(int mediaId, {int page = 1}) async {
    return MeluneSearchPage(
      items: _samples.take(2).toList(growable: false),
      page: 1,
      totalPages: 1,
      totalResults: 2,
    );
  }

  @override
  Future<MeluneHistoryPage> history({
    int cursorMax = 0,
    int cursorViewAt = 0,
  }) async {
    return const MeluneHistoryPage(
      tracks: [],
      hasMore: false,
      cursorMax: 0,
      cursorViewAt: 0,
    );
  }

  @override
  Future<List<MeluneLyricLine>> officialLyrics(String bvid, int cid) async {
    return const [
      MeluneLyricLine(
        from: Duration.zero,
        to: Duration(seconds: 5),
        content: '从空白的起点出发',
      ),
      MeluneLyricLine(
        from: Duration(seconds: 5),
        to: Duration(seconds: 10),
        content: '此刻绘出虚构的地平线\nNow we\'re painting synthetic horizons',
      ),
      MeluneLyricLine(
        from: Duration(seconds: 10),
        to: Duration(seconds: 15),
        content: '霓虹撞上海潮的边缘',
      ),
    ];
  }

  @override
  String cleanTitle(String title) => title;
}
