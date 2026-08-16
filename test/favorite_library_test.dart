import 'package:flutter_test/flutter_test.dart';
import 'package:melune/bili/favorite_library.dart';
import 'package:melune/bili/fake_bili_client.dart';
import 'package:melune/bili/melune_fav.dart';
import 'package:melune/bili/models.dart';

class _NativeOnlyFolderClient extends FakeBiliClient {
  _NativeOnlyFolderClient() : super(loggedIn: true);

  MeluneFavoriteFolder? created;

  @override
  Future<List<MeluneFavoriteFolder>> favoriteFolders({int rid = 0}) async {
    return const [
      MeluneFavoriteFolder(
        id: 9,
        title: '默认收藏夹',
        mediaCount: 1,
        coverUrl: '',
      ),
    ];
  }

  @override
  Future<MeluneFavoriteFolder> createFavoriteFolder(String title) async {
    if (created != null) {
      throw Exception('收藏夹名称已存在');
    }
    created = MeluneFavoriteFolder(
      id: 42,
      title: title,
      mediaCount: 0,
      coverUrl: '',
    );
    return created!;
  }
}

void main() {
  test('default folder matching trims titles', () {
    const folder = MeluneFavoriteFolder(
      id: 1,
      title: ' Melune_默认收藏 ',
      mediaCount: 0,
      coverUrl: '',
    );
    expect(folder.isMelune, isTrue);
    expect(folder.isDefault, isTrue);
    expect(folder.displayTitle, kMeluneDefaultFavName);
  });

  test('refresh keeps Melune folders when Bilibili omits them', () async {
    final bili = _NativeOnlyFolderClient();
    final library = FavoriteLibrary(bili: bili);

    await library.ensure();
    expect(library.defaultFolder, isNotNull);
    expect(library.defaultFolder!.displayTitle, kMeluneDefaultFavName);
    expect(library.folders.where((folder) => folder.isMelune).length, 1);

    await library.ensure(force: true);
    expect(library.defaultFolder, isNotNull);
    expect(library.defaultFolder!.id, 42);
    expect(library.folders.any((folder) => folder.displayTitle == '默认收藏'), isTrue);
  });

  test('empty folder list does not wipe already loaded Melune folders', () async {
    final bili = FakeBiliClient(loggedIn: true);
    final library = FavoriteLibrary(bili: bili);
    await library.ensure();
    expect(library.defaultFolder, isNotNull);

    bili.loggedIn = false;
    await library.ensure(force: true);
    expect(library.defaultFolder, isNotNull);
  });
}
