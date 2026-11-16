import 'dart:convert';

import '../probe_service.dart';

/// Query params that don't change the resource content (cache-busters).
const _cacheBusterParams = {
  'v',
  'ver',
  'version',
  't',
  'ts',
  'timestamp',
  'hash',
  '_',
  'cache',
  'cachebuster',
  'cb',
  'nocache',
  'rev',
  'revision',
};

/// Query string with cache-busting params removed, sorted for comparison.
String queryWithoutCacheBusters(Uri uri) {
  final params = Map<String, String>.from(uri.queryParameters);
  params
      .removeWhere((key, _) => _cacheBusterParams.contains(key.toLowerCase()));
  final keys = params.keys.toList()..sort();
  return keys.map((k) => '$k=${params[k]}').join('&');
}

/// True when [url1] and [url2] point to the same resource: same host and
/// path, and query params equal after dropping cache-busters. CDN
/// versioning (`?v=1` vs `?v=2`) still matches, but content-changing params
/// such as image resize options (`?width=112` vs `?width=264` or none)
/// never do.
bool sameResourceModuloCacheBusters(String url1, String url2) {
  if (url1 == url2) return true;
  try {
    final uri1 = Uri.parse(url1);
    final uri2 = Uri.parse(url2);
    if (uri1.host.toLowerCase() != uri2.host.toLowerCase()) return false;
    if (uri1.path != uri2.path) return false;
    return queryWithoutCacheBusters(uri1) == queryWithoutCacheBusters(uri2);
  } catch (_) {
    return false;
  }
}

/// The size of a timeline entry for the metadata lists; null when the
/// browser reported none. Images are judged by their transfer size: WebKit's
/// decoded size for them is the pixel buffer, so it is not reported.
Map<String, dynamic>? sizeOfTimelineEntry(Map match) {
  final tx = match['transfer'] as int?;
  final dec = match['decoded'] as int?;
  if (tx == null && dec == null) {
    final why = match['transferNote'] ?? match['decodedNote'];
    return {
      'transfer': null,
      'decoded': null,
      if (why != null) 'unknownReason': '$why',
    };
  }
  if (dec == null) {
    final isImage = match['initiatorType'] == 'img' ||
        match['initiatorType'] == 'image' ||
        ProbeService.categorizeResource('${match['name']}', '') == 'image';
    if (isImage) {
      return {'transfer': tx, 'decoded': tx, 'decodedFromTransfer': true};
    }
  }
  return {'transfer': tx, 'decoded': dec};
}

/// Finds the browser-measured size of a link in the resource timeline.
/// The timeline is indexed once; first entry wins.
class ResourceSizeIndex {
  final _byExact = <String, Map<String, dynamic>>{};
  final _byNormalized = <String, Map<String, dynamic>>{};
  final _byResourceKey = <String, Map<String, dynamic>>{};
  final _byImageVariant = <String, Map<String, dynamic>>{};
  final bool _empty;

  ResourceSizeIndex(Iterable<Map<String, dynamic>> timeline)
      : _empty = timeline.isEmpty {
    for (final r in timeline) {
      final name = r['name']?.toString();
      if (name == null || name.isEmpty) continue;
      _byExact.putIfAbsent(name, () => r);
      final u = Uri.tryParse(name);
      if (u == null) continue;
      final host = u.host.toLowerCase();
      _byNormalized.putIfAbsent('$host|${_trimmedPath(u)}|${u.query}', () => r);
      _byResourceKey.putIfAbsent(
          '$host|${u.path}|${queryWithoutCacheBusters(u)}', () => r);
      final last = _lastSegment(u);
      if (last.isNotEmpty && r['transfer'] is int && _isImage(r, name)) {
        _byImageVariant.putIfAbsent('$host|$last', () => r);
      }
    }
  }

  static String _trimmedPath(Uri u) => u.path.endsWith('/') && u.path.length > 1
      ? u.path.substring(0, u.path.length - 1)
      : u.path;

  static String _lastSegment(Uri u) {
    final parts = u.path.split('/').where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.last.toLowerCase();
  }

  static bool _isImage(Map r, String name) =>
      r['initiatorType'] == 'img' ||
      r['initiatorType'] == 'image' ||
      ProbeService.resourceTypeFromExtension(name) == 'image';

  Map<String, dynamic>? find(String? src) {
    if (src == null || src.isEmpty) return null;

    // Data URIs and inline SVGs: the size is the content itself.
    if (src.startsWith('data:') || src.startsWith('<svg')) {
      final bytes = utf8.encode(src).length;
      return {'transfer': bytes, 'decoded': bytes};
    }
    if (_empty) return null;

    final exact = _byExact[src];
    if (exact != null) return sizeOfTimelineEntry(exact);

    final u = Uri.tryParse(src);
    if (u == null) return null;
    final host = u.host.toLowerCase();

    // Host, path without trailing slash, query.
    final normalized = _byNormalized['$host|${_trimmedPath(u)}|${u.query}'];
    if (normalized != null) return sizeOfTimelineEntry(normalized);

    // Same host and path, query equal modulo cache-busters. Content-changing
    // params (?width=112 vs ?width=264) must not match.
    if (u.path.length > 3) {
      final byCb =
          _byResourceKey['$host|${u.path}|${queryWithoutCacheBusters(u)}'];
      if (byCb != null) return sizeOfTimelineEntry(byCb);
    }

    // Same image served as another size variant (same host, same last path
    // segment), only when the browser measured that variant: an estimate.
    final last = _lastSegment(u);
    if (last.isNotEmpty) {
      final img = _byImageVariant['$host|$last'];
      if (img != null) {
        final size = sizeOfTimelineEntry(img);
        if (size == null) return null;
        return {...size, 'estimated': true, 'variantOf': '${img['name']}'};
      }
    }
    return null;
  }
}
