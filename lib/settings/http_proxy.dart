import 'dart:io';

import 'package:flutter/foundation.dart';

class MeluneHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = findMeluneProxy;
    return client;
  }
}

String findMeluneProxy(Uri uri) {
  if (kIsWeb) {
    return 'DIRECT';
  }
  try {
    return _proxyFor(uri);
  } catch (_) {
    return 'DIRECT';
  }
}

String _proxyFor(Uri uri) {
  if (!_proxyEnabled) {
    return 'DIRECT';
  }
  final host = uri.host.toLowerCase();
  if (host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host.endsWith('.local')) {
    return 'DIRECT';
  }
  return 'PROXY $_proxyHost:$_proxyPort';
}

var _proxyEnabled = false;
var _proxyHost = '127.0.0.1';
var _proxyPort = 7890;

void updateHttpProxyConfig({
  required bool enabled,
  required String host,
  required int port,
}) {
  _proxyEnabled = enabled && host.trim().isNotEmpty;
  _proxyHost = host.trim();
  _proxyPort = port;
}

void installHttpProxyOverrides() {
  if (kIsWeb) {
    return;
  }
  HttpOverrides.global = MeluneHttpOverrides();
}
