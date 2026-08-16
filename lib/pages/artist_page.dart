import 'package:flutter/material.dart';
import 'package:melune/accounts/account_avatar.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/album_card.dart';
import 'package:melune/widgets/skeleton.dart';

class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.profile});

  final MeluneUpProfile profile;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  late MeluneUpProfile _profile;
  final _albums = <MeluneAlbum>[];
  var _page = 0;
  var _totalPages = 1;
  var _loading = true;
  var _loadingMore = false;
  var _gen = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final bili = BiliScope.of(context);
    final gen = ++_gen;
    setState(() {
      _loading = _albums.isEmpty;
      _error = null;
      _page = 0;
      _albums.clear();
    });
    try {
      final card = await bili.userCard(_profile.mid);
      if (!mounted || gen != _gen) {
        return;
      }
      setState(() => _profile = card);
      await _loadMore(reset: true, gen: gen);
    } catch (err) {
      if (!mounted || gen != _gen) {
        return;
      }
      setState(() {
        _loading = false;
        _error = err.toString();
      });
    }
  }

  Future<void> _loadMore({bool reset = false, int? gen}) async {
    if (_loadingMore || (!reset && _page >= _totalPages)) {
      return;
    }
    final bili = BiliScope.of(context);
    final token = gen ?? _gen;
    final next = reset ? 1 : _page + 1;
    setState(() => _loadingMore = !reset);
    try {
      final page = await bili.userArchives(_profile.mid, page: next);
      if (!mounted || token != _gen) {
        return;
      }
      final incoming = albumsFromTracks(page.items);
      final seen = <String>{for (final album in _albums) album.id};
      setState(() {
        if (reset) {
          _albums
            ..clear()
            ..addAll(incoming);
        } else {
          _albums.addAll([
            for (final album in incoming)
              if (seen.add(album.id)) album,
          ]);
        }
        _page = next;
        _totalPages = page.totalPages <= 0 ? next : page.totalPages;
        if (page.items.isEmpty) {
          _totalPages = next;
        }
        _loading = false;
        _loadingMore = false;
      });
    } catch (err) {
      if (!mounted || token != _gen) {
        return;
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error ??= err.toString();
      });
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification.metrics.extentAfter < 640) {
      _loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      key: Key('artist-page-${_profile.mid}'),
      color: tokens.colorBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                IconButton(
                  key: const Key('artist-back'),
                  tooltip: '返回',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: tokens.colorContrast,
                  ),
                ),
                Expanded(
                  child: Text(
                    '作者主页',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.colorContrast,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                AccountAvatar(
                  name: _profile.name,
                  face: _profile.face,
                  size: 64,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _profile.name.isEmpty
                          ? const MeluneSkeleton(
                              width: 120,
                              height: 22,
                              radius: 6,
                            )
                          : Text(
                              _profile.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: tokens.colorContrast,
                              ),
                            ),
                      const SizedBox(height: 4),
                      if (_loading &&
                          _profile.sign.isEmpty &&
                          _profile.fans <= 0)
                        const MeluneSkeleton(width: 160, height: 13, radius: 5)
                      else
                        Text(
                          [
                            if (_profile.sign.isNotEmpty) _profile.sign,
                            if (_profile.fans > 0)
                              '${formatPlayCount(_profile.fans)} 粉丝',
                            if (_profile.archiveCount > 0)
                              '${_profile.archiveCount} 投稿',
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.colorBase,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _error!,
                style: TextStyle(color: tokens.colorSecondary),
              ),
            ),
          Expanded(
            child: _loading
                ? AlbumGrid(
                    albums: const [],
                    padding: context.listPadding(16, 8, 16, 24),
                    skeletonCount: 8,
                  )
                : _albums.isEmpty
                ? Center(
                    child: Text(
                      '这位作者暂时没有音乐作品',
                      style: TextStyle(color: tokens.colorBase),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: AlbumGrid(
                      albums: _albums,
                      padding: context.listPadding(16, 8, 16, 24),
                      skeletonCount: _loadingMore ? 2 : 0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
