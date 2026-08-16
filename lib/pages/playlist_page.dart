import 'package:flutter/material.dart';
import 'package:melune/player/playback_select.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:melune/widgets/track_tile.dart';

class PlaylistGate extends StatefulWidget {
  const PlaylistGate({super.key});

  @override
  State<PlaylistGate> createState() => _PlaylistGateState();
}

class _PlaylistGateState extends State<PlaylistGate>
    with SingleTickerProviderStateMixin {
  PlaybackStore? _store;
  var _open = false;
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = PlaybackScope.read(context);
    if (!identical(_store, store)) {
      _store?.removeListener(_onStore);
      _store = store;
      _syncOpen(store.playlistOpen, animate: false);
      store.addListener(_onStore);
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_onStore);
    _controller.dispose();
    super.dispose();
  }

  void _onStore() {
    _syncOpen(_store?.playlistOpen ?? false, animate: true);
  }

  void _syncOpen(bool open, {required bool animate}) {
    if (open == _open) {
      return;
    }
    _open = open;
    if (!animate) {
      _controller.value = open ? 1 : 0;
      return;
    }
    if (open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.status == AnimationStatus.dismissed) {
          return const SizedBox.shrink();
        }
        return child!;
      },
      child: SlideTransition(
        position: _slide,
        child: const ExcludeSemantics(child: PlaylistPage()),
      ),
    );
  }
}

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final player = PlaybackScope.read(context);
    return Material(
      key: const Key('playlist-page'),
      color: tokens.colorBg,
      child: PlaybackSelect(
        player: player,
        selector: (store) => (
          store.queue.length,
          store.track?.id,
          store.currentIndex,
          store.playing,
        ),
        builder: (context, store) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('playlist-back'),
                      tooltip: '返回',
                      onPressed: store.closePlaylist,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: tokens.colorContrast,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '播放列表',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tokens.colorContrast,
                        ),
                      ),
                    ),
                    if (store.queue.isEmpty)
                      const SizedBox(width: 48)
                    else
                      IconButton(
                        key: const Key('playlist-clear'),
                        tooltip: '清空',
                        onPressed: store.clearQueue,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: tokens.colorBase,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    store.queue.isEmpty ? '还没有歌曲' : '${store.queue.length} 首',
                    style: TextStyle(color: tokens.colorBase, fontSize: 13),
                  ),
                ),
              ),
              Expanded(
                child: store.queue.isEmpty
                    ? Center(
                        child: Text(
                          '从歌单里加入歌曲',
                          style: TextStyle(color: tokens.colorBase),
                        ),
                      )
                    : ListView.builder(
                        padding: context.listPadding(12, 0, 8, 24),
                        itemCount: store.queue.length,
                        itemBuilder: (context, index) {
                          final item = store.queue[index];
                          return TrackTile(
                            key: Key('playlist-item-$index'),
                            track: item,
                            highlighted: index == store.currentIndex,
                            onTap: () => store.playAt(index),
                            trailing: IconButton(
                              key: Key('playlist-remove-$index'),
                              tooltip: '移出播放列表',
                              onPressed: () => store.removeFromQueue(index),
                              icon: Icon(
                                Icons.remove_circle_outline_rounded,
                                color: tokens.colorBase,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
