const kMeluneFavPrefix = 'Melune_';
const kMeluneDefaultFavName = '默认收藏';
const kMeluneDefaultFavTitle = '$kMeluneFavPrefix$kMeluneDefaultFavName';

bool isMeluneFavTitle(String title) {
  return title.trim().startsWith(kMeluneFavPrefix);
}

String meluneFavDisplayTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.startsWith(kMeluneFavPrefix)) {
    return trimmed.substring(kMeluneFavPrefix.length);
  }
  return trimmed;
}

String meluneFavStorageTitle(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return kMeluneDefaultFavTitle;
  }
  if (trimmed.startsWith(kMeluneFavPrefix)) {
    return trimmed;
  }
  return '$kMeluneFavPrefix$trimmed';
}
