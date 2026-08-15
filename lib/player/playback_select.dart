import 'package:flutter/material.dart';
import 'package:melune/player/playback_store.dart';

class PlaybackSelect extends StatefulWidget {
  const PlaybackSelect({
    super.key,
    required this.player,
    required this.selector,
    required this.builder,
  });

  final PlaybackStore player;
  final Object? Function(PlaybackStore player) selector;
  final Widget Function(BuildContext context, PlaybackStore player) builder;

  @override
  State<PlaybackSelect> createState() => _PlaybackSelectState();
}

class _PlaybackSelectState extends State<PlaybackSelect> {
  late Object? _signature;

  @override
  void initState() {
    super.initState();
    _signature = widget.selector(widget.player);
    widget.player.addListener(_onChange);
  }

  @override
  void didUpdateWidget(PlaybackSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      oldWidget.player.removeListener(_onChange);
      widget.player.addListener(_onChange);
      _signature = widget.selector(widget.player);
    }
  }

  @override
  void dispose() {
    widget.player.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final next = widget.selector(widget.player);
    if (next == _signature || !mounted) {
      return;
    }
    setState(() => _signature = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.player);
}
