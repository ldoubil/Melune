import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melune/accounts/account.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/accounts/accounts_popup.dart';
import 'package:melune/app.dart';
import 'package:melune/bili/fake_bili_client.dart';
import 'package:melune/window/title_bar.dart';
import 'package:melune/window/window_controller.dart';

class _FakeWindowController extends WindowController {
  var minimized = false;
  var closed = false;
  var dragging = false;
  var maximized = false;

  @override
  bool get enabled => true;

  @override
  bool get isMaximized => maximized;

  @override
  Future<void> minimize() async {
    minimized = true;
  }

  @override
  Future<void> toggleMaximize() async {
    maximized = !maximized;
    notifyListeners();
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<void> startDragging() async {
    dragging = true;
  }
}

void main() {
  testWidgets('shows home music sections from injected Bili client', (
    tester,
  ) async {
    await tester.pumpWidget(
      MeluneApp(
        appName: 'Melune · 洛音',
        greet: ({required String name}) => '你好，$name。欢迎来到 Melune · 洛音。',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Melune · 洛音'), findsWidgets);
    expect(find.text('新专'), findsOneWidget);
    expect(find.text('接着听'), findsOneWidget);
    expect(find.text('为你推荐'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    expect(find.byKey(const Key('title-search-field')), findsOneWidget);
    expect(find.byKey(const Key('playback-play')), findsOneWidget);
    expect(find.byKey(const Key('playback-quality')), findsOneWidget);

    await tester.tap(find.byKey(const Key('album-card-BV1demo1')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('album-page')), findsOneWidget);
    expect(find.text('夜航'), findsWidgets);
    expect(find.byKey(const Key('album-play')), findsOneWidget);
    expect(find.byKey(const Key('album-queue')), findsOneWidget);

    await tester.tap(find.byKey(const Key('album-queue')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('album-back')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('playback-playlist')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('playlist-page')), findsOneWidget);
    expect(find.byKey(const Key('playlist-item-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('playlist-remove-0')));
    await tester.pumpAndSettle();
    expect(find.text('从歌单里加入歌曲'), findsOneWidget);

    await tester.tap(find.byKey(const Key('playlist-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('playlist-page')), findsNothing);
  });

  testWidgets('opens dedicated now playing lyrics page from playback bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MeluneApp(
        appName: 'Melune · 洛音',
        greet: ({required String name}) => '你好，$name',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('playback-now-playing')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-playing-page')), findsOneWidget);
    expect(find.byKey(const Key('now-playing-lyrics-pane')), findsOneWidget);
    expect(find.text('正在播放'), findsOneWidget);

    await tester.tap(find.byKey(const Key('now-playing-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-page')), findsNothing);
  });

  testWidgets('system back closes now playing instead of leaving the app', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MeluneApp(
        appName: 'Melune · 洛音',
        greet: ({required String name}) => '你好，$name',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('playback-now-playing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-page')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-page')), findsNothing);
    expect(find.byKey(const Key('playback-play')), findsOneWidget);
  });

  testWidgets('switches between navigation destinations', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MeluneApp(
        appName: 'Melune · 洛音',
        greet: ({required String name}) => '你好，$name',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-search')));
    await tester.pumpAndSettle();
    expect(find.text('输入关键词开始搜索'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('title-search-field')), '夜');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-kind-playlists')), findsOneWidget);
    expect(find.byKey(const Key('album-card-BV1list1')), findsOneWidget);
    expect(find.text('夜航'), findsWidgets);

    await tester.tap(find.byKey(const Key('search-kind-playlists')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('album-card-BV1list1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-kind-tracks')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('album-card-BV1list1')), findsNothing);

    await tester.tap(find.byKey(const Key('nav-favorites')));
    await tester.pumpAndSettle();
    expect(find.text('还没有收藏'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-settings')));
    await tester.pumpAndSettle();
    expect(find.text('关于'), findsOneWidget);
    expect(find.textContaining('Melune'), findsWidgets);
    expect(find.byKey(const Key('playback-play')), findsOneWidget);
  });

  testWidgets('custom title bar can drag and control the window', (
    tester,
  ) async {
    final window = _FakeWindowController();

    await tester.pumpWidget(
      MeluneApp(
        appName: 'Melune · 洛音',
        greet: ({required String name}) => '你好，$name',
        window: window,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MeluneTitleBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('window-minimize')));
    await tester.pump();
    expect(window.minimized, isTrue);

    await tester.tap(find.byKey(const Key('window-maximize')));
    await tester.pump();
    expect(window.maximized, isTrue);
    expect(find.byTooltip('还原'), findsOneWidget);

    await tester.tap(find.byKey(const Key('window-close')));
    await tester.pump();
    expect(window.closed, isTrue);

    await tester.drag(
      find.byKey(const Key('window-drag-area')),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();
    expect(window.dragging, isTrue);
  });

  testWidgets('can show logged-in account and logout', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bili = FakeBiliClient();
    final accounts = AccountStore(bili: bili);
    accounts.debugSetUser(
      const MeluneAccount(id: '1', name: '洛音', mid: 42),
    );

    await tester.pumpWidget(
      MeluneApp(
        appName: 'Melune · 洛音',
        greet: ({required String name}) => '你好，$name',
        accounts: accounts,
        bili: bili,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-account')));
    await tester.pumpAndSettle();

    expect(find.byType(AccountsPopup), findsOneWidget);
    expect(find.text('洛音'), findsWidgets);
    expect(find.text('UID 42'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-logout')));
    await tester.pumpAndSettle();
    expect(accounts.active, isNull);
    expect(find.text('还没有登录账号'), findsOneWidget);
    expect(find.text('扫码登录'), findsOneWidget);
  });
}
