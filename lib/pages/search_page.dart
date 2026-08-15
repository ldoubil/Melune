import 'package:flutter/material.dart';
import 'package:melune/bili/bili_scope.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/browse_scope.dart';
import 'package:melune/widgets/track_tile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.query = ''});

  final String query;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  var _loading = false;
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

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return _Empty(
        error: _error,
        searched: widget.query.isNotEmpty,
      );
    }

    return ListView.builder(
      padding: context.listPadding(16, 8, 16, 22),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return TrackTile(
          track: items[index],
          onTap: () => BrowseScope.of(context).openAlbum(
            MeluneAlbum.fromTrack(items[index]),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.error, required this.searched});

  final String? error;
  final bool searched;

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
          error ?? (searched ? '没有找到相关音乐' : '输入关键词开始搜索'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.colorBase,
          ),
        ),
      ],
    );
  }
}
