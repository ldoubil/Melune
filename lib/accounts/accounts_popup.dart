import 'dart:async';

import 'package:flutter/material.dart';
import 'package:melune/accounts/account_avatar.dart';
import 'package:melune/accounts/account_store.dart';
import 'package:melune/theme/tokens.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showAccountsPopup(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '账号',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const AccountsPopup();
    },
  );
}

class AccountsPopup extends StatefulWidget {
  const AccountsPopup({super.key});

  @override
  State<AccountsPopup> createState() => _AccountsPopupState();
}

class _AccountsPopupState extends State<AccountsPopup> {
  String? _qrUrl;
  String? _qrHint;
  Timer? _poller;
  var _busy = false;

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final store = AccountScope.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Center(
          child: Material(
            color: tokens.colorRaisedBg,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '账号',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: tokens.colorContrast,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: tokens.colorBase),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (store.isLoggedIn)
                      _LoggedIn(store: store)
                    else
                      _LoginPane(
                        qrUrl: _qrUrl,
                        hint: _qrHint,
                        busy: _busy,
                        onScan: () => _startQr(store),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startQr(AccountStore store) async {
    setState(() {
      _busy = true;
      _qrHint = '正在获取二维码…';
    });
    try {
      final qr = await store.startQr();
      setState(() {
        _qrUrl = qr.url;
        _qrHint = '使用哔哩哔哩 App 扫码登录';
        _busy = false;
      });
      _poller?.cancel();
      _poller = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(_poll(store, qr.qrcodeKey));
      });
    } catch (err) {
      setState(() {
        _busy = false;
        _qrHint = err.toString();
      });
    }
  }

  Future<void> _poll(AccountStore store, String key) async {
    try {
      final result = await store.pollQr(key);
      if (!mounted) {
        return;
      }
      if (result.code == 86101) {
        setState(() => _qrHint = '等待扫码');
      } else if (result.code == 86090) {
        setState(() => _qrHint = '已扫码，请在手机上确认');
      } else if (result.code == 0) {
        _poller?.cancel();
        setState(() => _qrHint = '登录成功');
      } else if (result.code == 86038) {
        _poller?.cancel();
        setState(() => _qrHint = '二维码已过期，请重新获取');
      }
    } catch (_) {
      // 轮询失败时保持当前提示，下一秒再试。
    }
  }
}

class _LoggedIn extends StatelessWidget {
  const _LoggedIn({required this.store});

  final AccountStore store;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final account = store.active!;
    return Column(
      children: [
        const SizedBox(height: 12),
        AccountAvatar(name: account.name, face: account.face, size: 72),
        const SizedBox(height: 12),
        Text(
          account.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tokens.colorContrast,
          ),
        ),
        const SizedBox(height: 4),
        Text('UID ${account.mid}', style: TextStyle(color: tokens.colorBase)),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('account-logout'),
          onPressed: store.logout,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.colorBrand,
            foregroundColor: tokens.colorOnBrand,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('退出登录'),
        ),
      ],
    );
  }
}

class _LoginPane extends StatelessWidget {
  const _LoginPane({
    required this.qrUrl,
    required this.hint,
    required this.busy,
    required this.onScan,
  });

  final String? qrUrl;
  final String? hint;
  final bool busy;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '还没有登录账号',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.colorBase),
          ),
        ),
        if (qrUrl != null) ...[
          ColoredBox(
            color: Colors.white,
            child: QrImageView(
              data: qrUrl!,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (hint != null)
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.colorBase),
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('account-qr-login'),
          onPressed: busy ? null : onScan,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.colorBrand,
            foregroundColor: tokens.colorOnBrand,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          ),
          child: Text(busy ? '获取中…' : '扫码登录'),
        ),
      ],
    );
  }
}
