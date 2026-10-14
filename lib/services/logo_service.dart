import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

export 'package:view_source_vibe/services/detection/catalog.dart'
    show logoDomainFor;

/// Fetches and caches service/tracker logos (in memory and on disk, 30 days).
///
/// Logos come from DuckDuckGo's favicon service, so the inspected site is
/// never contacted; DuckDuckGo only sees which service domains are displayed.
class LogoService {
  static const _maxAge = Duration(days: 30);
  static final Map<String, Future<Uint8List?>> _requests = {};
  static final Map<String, Uint8List> _loaded = {};

  /// Bytes already available without waiting, if any.
  static Uint8List? cached(String domain) => _loaded[domain];

  static Future<Uint8List?> load(String domain) =>
      _requests.putIfAbsent(domain, () => _fetch(domain));

  static Future<Uint8List?> _fetch(String domain) async {
    try {
      File? file;
      if (!kIsWeb) {
        try {
          final dir = await getApplicationCacheDirectory();
          file = File('${dir.path}/logos/$domain.img');
          if (await file.exists() &&
              DateTime.now().difference(await file.lastModified()) < _maxAge) {
            return _loaded[domain] = await file.readAsBytes();
          }
        } catch (_) {
          file = null; // no cache directory available: memory only
        }
      }

      final response = await http
          .get(Uri.parse('https://icons.duckduckgo.com/ip3/$domain.ico'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      if (file != null) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
      }
      return _loaded[domain] = response.bodyBytes;
    } catch (e) {
      debugPrint('Logo fetch failed for $domain: $e');
      _requests.remove(domain); // allow a retry later
      return null;
    }
  }
}
