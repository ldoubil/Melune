import 'package:flutter/material.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/album_card.dart';
import 'package:melune/widgets/browse_scope.dart';
import 'package:melune/widgets/track_tile.dart';

enum _SearchKind { all, playlists, tracks }

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.query = ''});

  final String query;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  var _loading = false;
  var _kind = _SearchKind.all;
  String? _error;
  MeluneSearchPage? _result;

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
    setState(() {
      _loading = true;
      _error = null;
      _kind = _SearchKind.all;
    });
    try {
      final page = await BiliScope.of(context).search(keyword);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = page;
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final items = _result?.items ?? const <MeluneTrack>[];
    final playlists = playlistsFromTracks(items);
    final singles = singlesFromTracks(items);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
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
                onTap: () => setState(() => _kind = _SearchKind.all),
              ),
              _KindChip(
                key: const Key('search-kind-playlists'),
                label: '歌单',
                selected: _kind == _SearchKind.playlists,
                onTap: () => setState(() => _kind = _SearchKind.playlists),
              ),
              _KindChip(
                key: const Key('search-kind-tracks'),
                label: '单曲',
                selected: _kind == _SearchKind.tracks,
                onTap: () => setState(() => _kind = _SearchKind.tracks),
              ),
            ],
          ),
        ),
        Expanded(child: _body(playlists, singles)),
      ],
    );
  }

  Widget _body(List<MeluneAlbum> playlists, List<MeluneTrack> singles) {
    final showPlaylists =
        _kind == _SearchKind.all || _kind == _SearchKind.playlists;
    final showTracks = _kind == _SearchKind.all || _kind == _SearchKind.tracks;
    final visiblePlaylists = showPlaylists ? playlists : const <MeluneAlbum>[];
    final visibleSingles = showTracks ? singles : const <MeluneTrack>[];

    if (visiblePlaylists.isEmpty && visibleSingles.isEmpty) {
      return _Empty(
        error: null,
        searched: true,
        message: _kind == _SearchKind.playlists ? '没有相关歌单' : '没有相关单曲',
      );
    }

    if (_kind == _SearchKind.playlists) {
      return AlbumGrid(
        albums: visiblePlaylists,
        padding: context.listPadding(16, 8, 16, 22),
      );
    }

    return ListView(
      padding: context.listPadding(16, 8, 16, 22),
      children: [
        if (visiblePlaylists.isNotEmpty) ...[
          if (_kind == _SearchKind.all) const _SectionLabel('歌单'),
          if (_kind == _SearchKind.all) const SizedBox(height: 10),
          AlbumStrip(albums: visiblePlaylists, empty: ''),
          const SizedBox(height: 22),
        ],
        if (visibleSingles.isNotEmpty) ...[
          if (_kind == _SearchKind.all && visiblePlaylists.isNotEmpty) ...[
            const _SectionLabel('单曲'),
            const SizedBox(height: 8),
          ],
          for (var i = 0; i < visibleSingles.length; i++)
            TrackTile(
              track: visibleSingles[i],
              onTap: () => PlaybackScope.of(context).playTracks(
                visibleSingles,
                start: i,
              ),
            ),
        ],
      ],
    );
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
