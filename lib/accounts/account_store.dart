import 'package:flutter/material.dart';
import 'package:melune/accounts/account.dart';
import 'package:melune/bili/bili_client.dart';
import 'package:melune/bili/models.dart';

class AccountStore extends ChangeNotifier {
  AccountStore({required this.bili, MeluneUser? initial}) {
    if (initial != null) {
      _applyUser(initial);
    }
  }

  final BiliClient bili;
  MeluneAccount? _active;
  String? error;

  MeluneAccount? get active => _active;
  bool get isLoggedIn => _active != null;
  List<MeluneAccount> get accounts =>
      _active == null ? const [] : [_active!];

  Future<void> refresh() async {
    try {
      final user = await bili.nav();
      _applyUser(user);
      error = null;
    } catch (err) {
      error = err.toString();
    }
    notifyListeners();
  }

  Future<MeluneQrCode> startQr() {
    return bili.qrGenerate();
  }

  Future<MeluneQrPoll> pollQr(String qrcodeKey) async {
    final result = await bili.qrPoll(qrcodeKey);
    if (result.code == 0) {
      await refresh();
    }
    return result;
  }

  Future<void> logout() async {
    await bili.logout();
    _active = null;
    notifyListeners();
  }

  void debugSetUser(MeluneAccount account) {
    _active = account;
    notifyListeners();
  }

  void _applyUser(MeluneUser user) {
    if (!user.isLogin || user.mid == 0) {
      _active = null;
      return;
    }
    _active = MeluneAccount(
      id: '${user.mid}',
      name: user.name.isEmpty ? 'Bilibili 用户' : user.name,
      face: user.face,
      mid: user.mid,
    );
  }
}

class AccountScope extends InheritedNotifier<AccountStore> {
  const AccountScope({
    super.key,
    required AccountStore store,
    required super.child,
  }) : super(notifier: store);

  static AccountStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccountScope>();
    assert(scope != null, 'AccountScope not found');
    return scope!.notifier!;
  }
}
