const kMeluneFavPrefix = 'Melune_';
const kMeluneDefaultFavName = '默认收藏';
const kMeluneDefaultFavTitle = '$kMeluneFavPrefix$kMeluneDefaultFavName';

bool isMeluneFavTitle(String title) {
  return title.startsWith(kMeluneFavPrefix);
}

String meluneFavDisplayTitle(String title) {
  if (title.startsWith(kMeluneFavPrefix)) {
    return title.substring(kMeluneFavPrefix.length);
  }
  return title;
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
