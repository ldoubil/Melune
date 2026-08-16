import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:melune/bili/bili_client.dart';
import 'package:melune/bili/melune_fav.dart';
import 'package:melune/bili/models.dart';

class FavoriteLibrary extends ChangeNotifier {
  FavoriteLibrary({required this.bili});

  final BiliClient bili;
  List<MeluneFavoriteFolder> folders = const [];

  var _listLoaded = false;
  var _hydrateGen = 0;
  Future<List<MeluneFavoriteFolder>>? _inflight;

  MeluneFavoriteFolder? get defaultFolder {
    for (final folder in folders) {
      if (folder.isDefault) {
        return folder;
      }
    }
    return null;
  }

  void clear() {
    _hydrateGen += 1;
    _listLoaded = false;
    folders = const [];
    notifyListeners();
  }

  Future<List<MeluneFavoriteFolder>> ensure({bool force = false}) {
    if (!force && _listLoaded && folders.isNotEmpty) {
      return Future.value(folders);
    }
    if (force) {
      _listLoaded = false;
      _inflight = null;
    }
    return _inflight ??= _load(
      force: force,
    ).whenComplete(() => _inflight = null);
  }

  Future<List<MeluneFavoriteFolder>> _load({bool force = false}) async {
    final all = await bili.favoriteFolders();
    var ours = all.where((folder) => folder.isMelune).toList();
    if (ours.every((folder) => !folder.isDefault)) {
      try {
        final created = await bili.createFavoriteFolder(kMeluneDefaultFavTitle);
        ours = [created.copyWith(favState: false), ...ours];
      } catch (_) {}
    }
    folders = _merge(ours);
    _listLoaded = true;
    notifyListeners();
    unawaited(_hydrate(force: force));
    return folders;
  }

  Future<MeluneFavoriteFolder> createNamed(String name) async {
    final created = await bili.createFavoriteFolder(
      meluneFavStorageTitle(name),
    );
    folders = [...folders, created];
    notifyListeners();
    return created;
  }

  Future<Set<int>> folderIdsFor(MeluneTrack track) async {
    await ensure();
    final all = await bili.favoriteFolders(rid: track.aid);
    final selected = <int>{};
    for (final folder in all) {
      if (folder.isMelune && folder.favState) {
        selected.add(folder.id);
      }
    }
    folders = [
      for (final folder in folders)
        folder.copyWith(favState: selected.contains(folder.id)),
    ];
    return selected;
  }

  Future<bool> isInDefault(MeluneTrack track) async {
    final selected = await folderIdsFor(track);
    final folder = defaultFolder;
    return folder != null && selected.contains(folder.id);
  }

  Future<void> toggleDefault(MeluneTrack track, {required bool like}) async {
    await ensure();
    final folder = defaultFolder;
    if (folder == null) {
      throw Exception('请先登录后收藏到 Melune 收藏夹');
    }
    await bili.dealFavorite(
      rid: track.aid,
      bvid: track.bvid,
      addIds: like ? [folder.id] : const [],
      delIds: like ? const [] : [folder.id],
    );
    adjust(folder.id, delta: like ? 1 : -1, coverUrl: track.coverUrl);
  }

  Future<void> applyFolders(MeluneTrack track, Set<int> selectedIds) async {
    await ensure();
    final current = await folderIdsFor(track);
    final addIds = selectedIds.difference(current).toList();
    final delIds = current.difference(selectedIds).toList();
    if (addIds.isEmpty && delIds.isEmpty) {
      return;
    }
    await bili.dealFavorite(
      rid: track.aid,
      bvid: track.bvid,
      addIds: addIds,
      delIds: delIds,
    );
    for (final id in addIds) {
      adjust(id, delta: 1, coverUrl: track.coverUrl);
    }
    for (final id in delIds) {
      adjust(id, delta: -1);
    }
  }

  void patch(int folderId, {int? mediaCount, String? coverUrl}) {
    if (folderId <= 0) {
      return;
    }
    folders = [
      for (final folder in folders)
        folder.id != folderId
            ? folder
            : folder.copyWith(
                mediaCount: mediaCount ?? folder.mediaCount,
                coverUrl: (coverUrl != null && coverUrl.isNotEmpty)
                    ? coverUrl
                    : folder.coverUrl,
              ),
    ];
    notifyListeners();
  }

  void adjust(int folderId, {required int delta, String coverUrl = ''}) {
    if (folderId <= 0 || delta == 0) {
      return;
    }
    folders = [
      for (final folder in folders)
        if (folder.id != folderId)
          folder
        else
          folder.copyWith(
            mediaCount: (folder.mediaCount + delta).clamp(0, 999999),
            coverUrl: coverUrl.isNotEmpty && folder.coverUrl.isEmpty
                ? coverUrl
                : folder.coverUrl,
          ),
    ];
    notifyListeners();
  }

  Future<void> _hydrate({bool force = false}) async {
    final gen = ++_hydrateGen;
    final snapshot = folders;
    if (snapshot.isEmpty) {
      return;
    }
    final updated = await Future.wait([
      for (final folder in snapshot) _hydrateFolder(folder, force: force),
    ]);
    if (gen != _hydrateGen) {
      return;
    }
    folders = updated;
    notifyListeners();
  }

  Future<MeluneFavoriteFolder> _hydrateFolder(
    MeluneFavoriteFolder folder, {
    required bool force,
  }) async {
    if (!force && folder.mediaCount > 0 && folder.coverUrl.isNotEmpty) {
      return folder;
    }
    try {
      final page = await bili.favoriteTracks(folder.id, page: 1);
      final counted = page.totalPages <= page.page
          ? page.items.length
          : (page.totalResults > 0 ? page.totalResults : page.items.length);
      return folder.copyWith(
        mediaCount: (force || folder.mediaCount <= 0)
            ? counted
            : folder.mediaCount,
        coverUrl: folder.coverUrl.isNotEmpty
            ? folder.coverUrl
            : (page.items.isEmpty ? '' : page.items.first.coverUrl),
      );
    } catch (_) {
      return folder;
    }
  }

  List<MeluneFavoriteFolder> _merge(List<MeluneFavoriteFolder> next) {
    final prev = {for (final folder in folders) folder.id: folder};
    return [
      for (final folder in next)
        folder.copyWith(
          mediaCount: folder.mediaCount > 0
              ? folder.mediaCount
              : (prev[folder.id]?.mediaCount ?? 0),
          coverUrl: folder.coverUrl.isNotEmpty
              ? folder.coverUrl
              : (prev[folder.id]?.coverUrl ?? ''),
        ),
    ];
  }
}
