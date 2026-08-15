import 'package:flutter/material.dart';
import 'package:melune/bili/bili_client.dart';

class BiliScope extends InheritedWidget {
  const BiliScope({
    super.key,
    required this.client,
    required super.child,
  });

  final BiliClient client;

  static BiliClient of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BiliScope>();
    assert(scope != null, 'BiliScope not found');
    return scope!.client;
  }

  @override
  bool updateShouldNotify(BiliScope oldWidget) => client != oldWidget.client;
}
