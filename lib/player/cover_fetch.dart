import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

const kCoverUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36';

String normalizeCoverUrl(String url) {
  var out = url.trim();
  if (out.startsWith('//')) {
    return 'https:$out';
  }
  if (out.startsWith('http://')) {
    return 'https://${out.substring(7)}';
  }
  return out;
}

Map<String, String> coverImageHeaders() {
  return const {
    HttpHeaders.refererHeader: 'https://www.bilibili.com',
    HttpHeaders.userAgentHeader: kCoverUserAgent,
  };
}

Future<Uint8List?> fetchCoverBytes(String url) async {
  final canonical = normalizeCoverUrl(url);
  if (!canonical.startsWith('https://') && !canonical.startsWith('http://')) {
    return null;
  }
  final uri = Uri.tryParse(canonical);
  if (uri == null) {
    return null;
  }
  final client = HttpClient();
  client.userAgent = kCoverUserAgent;
  client.connectionTimeout = const Duration(seconds: 10);
  client.autoUncompress = true;
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.refererHeader, 'https://www.bilibili.com');
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      return null;
    }
    return await consolidateHttpClientResponseBytes(response);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
