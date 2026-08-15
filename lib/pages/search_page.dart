import 'package:flutter/material.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/album_card.dart';
import 'package:melune/widgets/track_tile.dart';

enum _SearchKind { all, playlists, tracks }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.query = ''});

  final String query;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _warmPages = 4;
  static const _maxAutoPages = 12;

  final _items = <MeluneTrack>[];
  final _seen = <String>{};
  var _kind = _SearchKind.all;
  var _loading = false;
  var _loadingMore = false;
  var _filling = false;
  var _hasMore = false;
  var _page = 0;
  var _totalPages = 0;
  var _generation = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(widget.query));
    }
  }

  @override
  void didUpdateWidget(SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query && widget.query.isNotEmpty) {
      _search(widget.query);
    }
  }

  Future<void> _search(String keyword) async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _kind = _SearchKind.all;
      _items.clear();
      _seen.clear();
      _page = 0;
      _totalPages = 0;
      _hasMore = true;
    });
    await _fill(gen, warm: true);
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _filling || !_hasMore) {
      return;
    }
    await _fill(_generation, warm: false);
  }

  Future<void> _fill(int gen, {required bool warm}) async {
    if (_filling || widget.query.isEmpty) {
      return;
    }
    _filling = true;
    if (_page > 0 && mounted && gen == _generation) {
      setState(() => _loadingMore = true);
    }
    try {
      final bili = BiliScope.of(context);
      while (mounted && gen == _generation && _hasMore) {
        final next = _page + 1;
        if (_totalPages > 0 && next > _totalPages) {
          _hasMore = false;
          break;
        }
        final page = await bili.search(widget.query, page: next);
        if (!mounted || gen != _generation) {
          return;
        }
        _append(page.items);
        _page = next;
        _totalPages = page.totalPages;
        _hasMore = _totalPages > 0
            ? _page < _totalPages
            : page.items.isNotEmpty;
        setState(() {
          _loading = false;
          _error = null;
        });
        if (!warm) {
          break;
        }
        if (!_hasMore) {
          break;
        }
        if (_page >= _warmPages && _enoughVisible) {
          break;
        }
        if (_page >= _maxAutoPages) {
          break;
        }
      }
    } catch (err) {
      if (!mounted || gen != _generation) {
        return;
      }
      setState(() {
        _error = err.toString();
        if (_items.isEmpty) {
          _hasMore = false;
        }
      });
    } finally {
      _filling = false;
      if (mounted && gen == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && gen == _generation) {
            _ensureFilled();
          }
        });
      }
    }
  }

  void _append(List<MeluneTrack> batch) {
    for (final track in batch) {
      if (_seen.add(track.id)) {
        _items.add(track);
      }
    }
  }

  bool get _enoughVisible {
    return switch (_kind) {
      _SearchKind.all => _items.length >= 16,
      _SearchKind.playlists => playlistsFromTracks(_items).length >= 8,
      _SearchKind.tracks => singlesFromTracks(_items).length >= 12,
    };
  }

  void _ensureFilled() {
    if (!_hasMore || _filling || _loading) {
      return;
    }
    if (!_enoughVisible) {
      _loadMore();
    }
  }

  void _selectKind(_SearchKind kind) {
    if (_kind == kind) {
      return;
    }
    setState(() => _kind = kind);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureFilled();
      }
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent <= 0) {
      return false;
    }
    if (metrics.pixels >= metrics.maxScrollExtent - 480) {
      _loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final playlists = playlistsFromTracks(_items);
    final singles = singlesFromTracks(_items);

    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return _Empty(
        error: _error,
        searched: widget.query.isNotEmpty,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KindChip(
                key: const Key('search-kind-all'),
                label: '全部',
                selected: _kind == _SearchKind.all,
                onTap: () => _selectKind(_SearchKind.all),
              ),
              _KindChip(
                key: const Key('search-kind-playlists'),
                label: '歌单',
                selected: _kind == _SearchKind.playlists,
                onTap: () => _selectKind(_SearchKind.playlists),
              ),
              _KindChip(
                key: const Key('search-kind-tracks'),
                label: '单曲',
                selected: _kind == _SearchKind.tracks,
                onTap: () => _selectKind(_SearchKind.tracks),
              ),
            ],
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: _body(playlists, singles),
          ),
        ),
      ],
    );
  }

  Widget _body(List<MeluneAlbum> playlists, List<MeluneTrack> singles) {
    final showPlaylists =
        _kind == _SearchKind.all || _kind == _SearchKind.playlists;
    final showTracks = _kind == _SearchKind.all || _kind == _SearchKind.tracks;
    final visiblePlaylists = showPlaylists ? playlists : const <MeluneAlbum>[];
    final visibleSingles = showTracks ? singles : const <MeluneTrack>[];
    final trailing = _SearchStatus(
      loading: _loadingMore,
      hasMore: _hasMore && _error == null,
      error: _error,
    );

    if (visiblePlaylists.isEmpty && visibleSingles.isEmpty) {
      if (_hasMore || _loadingMore) {
        return ListView(
          padding: context.listPadding(22, 16, 22, 22),
          children: [trailing],
        );
      }
      return _Empty(
        error: null,
        searched: true,
        message: _kind == _SearchKind.playlists ? '没有相关歌单' : '没有相关单曲',
      );
    }

    if (_kind == _SearchKind.playlists) {
      return AlbumGrid(
        albums: visiblePlaylists,
        padding: context.listPadding(16, 8, 16, 8),
        trailing: trailing,
      );
    }

    return ListView.builder(
      padding: context.listPadding(16, 8, 16, 8),
      itemCount: _listCount(visiblePlaylists, visibleSingles),
      itemBuilder: (context, index) {
        return _listChild(index, visiblePlaylists, visibleSingles, trailing);
      },
    );
  }

  int _listCount(List<MeluneAlbum> playlists, List<MeluneTrack> singles) {
    var count = 0;
    if (playlists.isNotEmpty) {
      if (_kind == _SearchKind.all) {
        count += 3;
      }
      count += 1;
    }
    if (singles.isNotEmpty) {
      if (_kind == _SearchKind.all && playlists.isNotEmpty) {
        count += 2;
      }
      count += singles.length;
    }
    return count + 1;
  }

  Widget _listChild(
    int index,
    List<MeluneAlbum> playlists,
    List<MeluneTrack> singles,
    Widget trailing,
  ) {
    var cursor = index;
    if (playlists.isNotEmpty) {
      if (_kind == _SearchKind.all) {
        if (cursor == 0) {
          return const _SectionLabel('歌单');
        }
        if (cursor == 1) {
          return const SizedBox(height: 10);
        }
        cursor -= 2;
      }
      if (cursor == 0) {
        return AlbumStrip(albums: playlists, empty: '');
      }
      if (cursor == 1 && _kind == _SearchKind.all) {
        return const SizedBox(height: 22);
      }
      cursor -= _kind == _SearchKind.all ? 2 : 1;
    }
    if (singles.isNotEmpty) {
      if (_kind == _SearchKind.all && playlists.isNotEmpty) {
        if (cursor == 0) {
          return const _SectionLabel('单曲');
        }
        if (cursor == 1) {
          return const SizedBox(height: 8);
        }
        cursor -= 2;
      }
      if (cursor >= 0 && cursor < singles.length) {
        return TrackTile(
          track: singles[cursor],
          onTap: () => PlaybackScope.of(context).playTracks(
            singles,
            start: cursor,
          ),
        );
      }
    }
    return trailing;
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: tokens.colorButtonBgSelected,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? tokens.colorButtonTextSelected : tokens.colorContrast,
      ),
      backgroundColor: tokens.colorRaisedBg,
      side: BorderSide.none,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: context.tokens.colorContrast,
      ),
    );
  }
}

class _SearchStatus extends StatelessWidget {
  const _SearchStatus({
    required this.loading,
    required this.hasMore,
    this.error,
  });

  final bool loading;
  final bool hasMore;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget child;
    if (loading) {
      child = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    } else if (error != null) {
      child = Text(
        error!,
        textAlign: TextAlign.center,
        style: TextStyle(color: tokens.colorBase, fontSize: 13),
      );
    } else if (hasMore) {
      child = const SizedBox(height: 12);
    } else {
      child = Text(
        '已经到底了',
        style: TextStyle(color: tokens.colorBase, fontSize: 12),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Center(child: child),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.error,
    required this.searched,
    this.message,
  });

  final String? error;
  final bool searched;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListView(
      padding: context.listPadding(22, 16, 22, 22),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.search, size: 48, color: tokens.colorBase),
        const SizedBox(height: 12),
        Text(
          error ??
              message ??
              (searched ? '没有找到相关音乐' : '输入关键词开始搜索'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.colorBase,
          ),
        ),
      ],
    );
  }
}
