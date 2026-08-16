import 'package:flutter/material.dart';
import 'package:melune/bili/bili_client.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/browse_scope.dart';
import 'package:melune/widgets/queue_toggle.dart';
import 'package:melune/widgets/skeleton.dart';
import 'package:melune/widgets/track_cache_button.dart';
import 'package:melune/widgets/track_cover.dart';
import 'package:melune/widgets/track_tile.dart';

class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key, required this.album});

  final MeluneAlbum album;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late MeluneAlbum _album;
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    final bili = BiliScope.of(context);
    setState(() {
      _loading = _album.tracks.isEmpty;
      _error = null;
    });
    try {
      var tracks = _album.tracks;
      if (_album.folderId > 0) {
        tracks = await _loadFolder(bili, _album.folderId);
      } else if (_album.id == 'recent') {
        tracks = _album.tracks;
      } else if (_album.seasonId > 0 && _album.upMid > 0) {
        tracks = await bili.seasonTracks(
          mid: _album.upMid,
          seasonId: _album.seasonId,
        );
        if (tracks.isEmpty && _album.bvid.isNotEmpty) {
          tracks = await bili.videoPages(_album.bvid);
        }
      } else if (_album.bvid.isNotEmpty) {
        final pages = await bili.videoPages(_album.bvid);
        if (pages.length > 1 || (tracks.length <= 1 && pages.isNotEmpty)) {
          tracks = pages;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _album = _album.copyWith(tracks: tracks);
        _loading = false;
      });
      if (_album.folderId > 0) {
        PlaybackScope.read(context).favorites.patch(
          _album.folderId,
          mediaCount: tracks.length,
          coverUrl: tracks.isEmpty ? '' : tracks.first.coverUrl,
        );
      }
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = err.toString();
      });
    }
  }

  Future<List<MeluneTrack>> _loadFolder(BiliClient bili, int folderId) async {
    final items = <MeluneTrack>[];
    for (var page = 1; page <= 8; page++) {
      final result = await bili.favoriteTracks(folderId, page: page);
      items.addAll(result.items);
      if (result.items.isEmpty || page >= result.totalPages) {
        break;
      }
    }
    return items;
  }

  void _play({int start = 0}) {
    final tracks = _album.tracks;
    if (tracks.isEmpty) {
      return;
    }
    PlaybackScope.of(context).playTracks(tracks, start: start);
  }

  void _queueAlbum() {
    final added = PlaybackScope.of(context).enqueueAlbum(_album.tracks);
    if (!mounted) {
      return;
    }
    showQueueMessage(context, added);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tracks = _album.tracks;
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Material(
      key: const Key('album-page'),
      color: tokens.colorBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                IconButton(
                  key: const Key('album-back'),
                  tooltip: '返回',
                  onPressed: () => popContent(context),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: tokens.colorContrast,
                  ),
                ),
                Expanded(
                  child: Text(
                    '歌单',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.colorContrast,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: context.listPadding(20, 8, 20, 24),
              children: [
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrackCover(url: _album.coverUrl, size: 196, radius: 18),
                      const SizedBox(width: 22),
                      Expanded(
                        child: _Header(
                          album: _album,
                          loading: _loading,
                          onPlay: _play,
                          onQueue: _queueAlbum,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      TrackCover(url: _album.coverUrl, size: 220, radius: 18),
                      const SizedBox(height: 16),
                      _Header(
                        album: _album,
                        loading: _loading,
                        onPlay: _play,
                        onQueue: _queueAlbum,
                      ),
                    ],
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: tokens.colorSecondary)),
                ],
                const SizedBox(height: 22),
                if (_loading)
                  for (var i = 0; i < 8; i++) const TrackTileSkeleton()
                else if (tracks.isEmpty)
                  Text('这个歌单还没有曲目', style: TextStyle(color: tokens.colorBase))
                else
                  for (var i = 0; i < tracks.length; i++)
                    TrackTile(
                      track: tracks[i],
                      onTap: () => _play(start: i),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.album,
    required this.loading,
    required this.onPlay,
    required this.onQueue,
  });

  final MeluneAlbum album;
  final bool loading;
  final void Function({int start}) onPlay;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        album.title.isEmpty
            ? const MeluneSkeleton(width: 180, height: 28, radius: 8)
            : Text(
                album.title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: tokens.colorContrast,
                ),
              ),
        const SizedBox(height: 6),
        if (loading && album.tracks.isEmpty)
          const MeluneSkeleton(width: 96, height: 14, radius: 5)
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (album.upMid > 0)
                InkWell(
                  key: Key('album-artist-${album.upMid}'),
                  onTap: () => BrowseScope.of(context).openArtist(
                    MeluneUpProfile(
                      mid: album.upMid,
                      name: album.tracks.isNotEmpty
                          ? album.tracks.first.artist
                          : album.subtitle,
                    ),
                  ),
                  child: Text(
                    album.tracks.isNotEmpty
                        ? album.tracks.first.artist
                        : album.subtitle,
                    style: TextStyle(color: tokens.colorBrand, fontSize: 14),
                  ),
                )
              else if (album.subtitle.isNotEmpty &&
                  !_isSongCount(album.subtitle))
                Text(
                  album.subtitle,
                  style: TextStyle(color: tokens.colorBase, fontSize: 14),
                ),
              if (album.tracks.isNotEmpty)
                Text(
                  '${album.tracks.length} 首',
                  style: TextStyle(color: tokens.colorBase, fontSize: 14),
                )
              else if (_isSongCount(album.subtitle))
                Text(
                  album.subtitle,
                  style: TextStyle(color: tokens.colorBase, fontSize: 14),
                ),
            ],
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('album-play'),
              onPressed: album.tracks.isEmpty ? null : () => onPlay(),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('播放'),
            ),
            OutlinedButton.icon(
              key: const Key('album-queue'),
              onPressed: album.tracks.isEmpty ? null : onQueue,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('加入播放列表'),
            ),
            AlbumCacheButton(tracks: album.tracks),
          ],
        ),
      ],
    );
  }
}

bool _isSongCount(String text) => RegExp(r'^\d+ 首$').hasMatch(text);
