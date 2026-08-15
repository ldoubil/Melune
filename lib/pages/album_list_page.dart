import 'package:flutter/material.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/album_card.dart';

class AlbumListPage extends StatelessWidget {
  const AlbumListPage({
    super.key,
    required this.title,
    required this.albums,
  });

  final String title;
  final List<MeluneAlbum> albums;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      key: const Key('album-list-page'),
      color: tokens.colorBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
            child: Row(
              children: [
                IconButton(
                  key: const Key('album-list-back'),
                  tooltip: '返回',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: tokens.colorContrast,
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
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
            child: albums.isEmpty
                ? Center(
                    child: Text(
                      '暂时没有专辑',
                      style: TextStyle(color: tokens.colorBase),
                    ),
                  )
                : AlbumGrid(
                    albums: albums,
                    padding: context.listPadding(16, 8, 16, 24),
                  ),
          ),
        ],
      ),
    );
  }
}
