import 'package:flutter/material.dart';
import 'package:melune/bili/models.dart';
import 'package:melune/player/playback_store.dart';
import 'package:melune/theme/tokens.dart';

class TrackLikeButton extends StatelessWidget {
  const TrackLikeButton({
    super.key,
    required this.player,
    this.track,
    this.compact = false,
  });

  final PlaybackStore player;
  final MeluneTrack? track;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final item = track ?? player.track;
    final liked = player.isLiked(item);
    return IconButton(
      tooltip: liked ? '取消收藏到默认夹 · 长按指定收藏夹' : '收藏到默认夹 · 长按指定收藏夹',
      visualDensity: compact ? VisualDensity.compact : null,
      padding: compact ? EdgeInsets.zero : null,
      onPressed: item == null ? null : () => player.toggleLikeTrack(item),
      onLongPress: item == null
          ? null
          : () => showFavoriteFolderPicker(
              context: context,
              player: player,
              track: item,
            ),
      icon: Icon(
        liked ? Icons.favorite : Icons.favorite_border,
        size: compact ? 20 : null,
        color: liked ? tokens.colorBrand : tokens.colorBase,
      ),
    );
  }
}

Future<void> showFavoriteFolderPicker({
  required BuildContext context,
  required PlaybackStore player,
  required MeluneTrack track,
}) async {
  final tokens = context.tokens;
  try {
    await player.favorites.ensure();
  } catch (err) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$err')));
    }
    return;
  }
  if (!context.mounted) {
    return;
  }
  if (player.favorites.folders.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先登录，收藏会同步到 Melune 收藏夹')));
    return;
  }
  Set<int> selected = await player.favorites.folderIdsFor(track);
  if (!context.mounted) {
    return;
  }
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: tokens.colorRaisedBg,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final folders = player.favorites.folders;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '收藏到',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: tokens.colorContrast,
                    ),
                  ),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.colorBase),
                  ),
                  const SizedBox(height: 8),
                  ListView(
                    shrinkWrap: true,
                    children: [
                      for (final folder in folders)
                        CheckboxListTile(
                          value: selected.contains(folder.id),
                          title: Text(folder.displayTitle),
                          subtitle: folder.isDefault
                              ? const Text('点小心会同步到这里')
                              : null,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selected = {...selected, folder.id};
                              } else {
                                selected = {
                                  for (final id in selected)
                                    if (id != folder.id) id,
                                };
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  ListTile(
                    leading: const Icon(Icons.create_new_folder_outlined),
                    title: const Text('新建收藏夹'),
                    onTap: () async {
                      final created = await promptCreateMeluneFolder(
                        context: context,
                        player: player,
                      );
                      if (created == null) {
                        return;
                      }
                      setState(() {
                        selected = {...selected, created.id};
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  if (confirmed == true) {
    try {
      await player.applyFavoriteFolders(track, selected);
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$err')));
      }
    }
  }
}

Future<MeluneFavoriteFolder?> promptCreateMeluneFolder({
  required BuildContext context,
  required PlaybackStore player,
}) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('新建收藏夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '夹子名称',
            helperText: '会自动加上 Melune_ 前缀',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('创建'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    return await player.favorites.createNamed(trimmed);
  } catch (err) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$err')));
    }
    return null;
  }
}
