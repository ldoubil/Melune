 import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melune/accounts/account.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/app.dart';
import 'package:melune/bili/fake_bili_client.dart';
import 'package:melune/bili/models.dart';

class _SecondPageFailsClient extends FakeBiliClient {
  _SecondPageFailsClient() : super(loggedIn: true);

  @override
  Future<MeluneSearchPage> favoriteTracks(int mediaId, {int page = 1}) async {
    if (page > 1) {
      throw Exception(
        'https://api.bilibili.com/x/v3/fav/resource/list: '
        'Network Error: received fatal alert: BadRecordMac',
      );
    }
    final items = (await musicRank()).take(2).toList(growable: false);
    return MeluneSearchPage(
      items: items,
      page: 1,
      totalPages: 2,
      totalResults: 5,
    );
  }
}

void main() {
  testWidgets('keeps loaded folder tracks when a later page fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bili = _SecondPageFailsClient();
    final accounts = AccountStore(bili: bili);
    accounts.debugSetUser(const MeluneAccount(id: '1', name: '洛音', mid: 42));

    await tester.pumpWidget(
      MeluneApp(
        appName: 'Melune · 洛音',
        greet: ({required String name}) => '你好，$name',
        accounts: accounts,
        bili: bili,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-favorites')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('album-card-fav-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('album-page')), findsOneWidget);
    expect(find.text('夜航'), findsWidgets);
    expect(find.text('网络波动，部分曲目未能加载'), findsOneWidget);
    expect(find.byKey(const Key('album-retry')), findsOneWidget);
    expect(find.text('这个歌单还没有曲目'), findsNothing);
    expect(find.textContaining('BadRecordMac'), findsNothing);
  });
}
