import 'dart:convert';

import '../models/html_file.dart';
import '../models/inspection/browser_snapshot.dart';
import '../models/inspection/observed.dart';
import '../models/inspection/page_inspection.dart';
import '../models/inspection/server_snapshot.dart';
import 'probe_service.dart';

/// Old-style maps for the widgets that still read them, built from the
/// store's browser snapshot. Pure functions: a value that is not Present is
/// null (timeline) or left out (everything else), never 0, '' or a
/// placeholder.

BrowserSnapshot? _browser(PageInspection p) {
  final b = p.browser;
  return b is Present<BrowserSnapshot> ? b.value : null;
}

List<ResourceEntry>? _resources(BrowserSnapshot b) {
  final r = b.resources;
  return r is Present<List<ResourceEntry>> ? r.value : null;
}

T? _value<T>(Observed<T> o) => o is Present<T> ? o.value : null;

/// Why [o] has no value, as text; null when it is Present or still Pending.
String? _note<T>(Observed<T> o) => switch (o) {
      Unavailable<T>(reason: final r, detail: final d) =>
        unavailableMessage(r, d),
      Failed<T>(error: final e) => e,
      _ => null,
    };

/// `resourceTimelineData`: one map per resource with `name`, `transfer`,
/// `decoded`, `startTime`, `duration` (null when not Present), `initiatorType`
/// and `source`; `transferNote` / `decodedNote` say why a size is missing.
List<Map<String, dynamic>> legacyResourceTimeline(PageInspection p) {
  final b = _browser(p);
  final resources = b == null ? null : _resources(b);
  if (resources == null) return const [];
  return List.unmodifiable([
    for (final r in resources)
      {
        'name': r.url,
        'transfer': _value(r.transfer),
        'decoded': _value(r.decoded),
        'startTime': _value(r.startTime),
        'duration': _value(r.duration),
        'initiatorType': r.type,
        'source': r.source.name,
        if (_note(r.transfer) != null) 'transferNote': _note(r.transfer),
        if (_note(r.decoded) != null) 'decodedNote': _note(r.decoded),
      },
  ]);
}

class _Bucket {
  int count = 0;
  int transfer = 0, decoded = 0;
  bool hasTransfer = false, hasDecoded = false;

  Map<String, dynamic> toMap() => {
        'count': count,
        if (hasTransfer) 'transfer': transfer,
        if (hasDecoded) 'decoded': decoded,
      };
}

/// The page weight: totals over the values that are Present, a breakdown per
/// type, and `isPartial` when something is missing from the totals (a
/// resource without a transfer size, a non-image without a decoded size,
/// truncated resources). Images are judged by their transfer size: WebKit
/// reports the decoded pixel buffer for them, so their decoded size is never
/// added there and its absence is not a gap.
///
/// The browser does not report the main document's own size; when the
/// server's body is Present its sizes are added (`documentSource: 'server'`).
/// Null unless the browser's resources are Present.
Map<String, dynamic>? legacyPageWeight(PageInspection p) {
  final b = _browser(p);
  final resources = b == null ? null : _resources(b);
  if (b == null || resources == null) return null;

  final pageUrl = b.url.toString();
  final buckets = {
    'scripts': _Bucket(),
    'css': _Bucket(),
    'images': _Bucket(),
    'html': _Bucket(),
    'other': _Bucket(),
  };
  var partial = b.resourcesTruncated;

  for (final r in resources) {
    final category = ProbeService.categorizeResource(r.url, pageUrl);
    final isImage = category == 'image' || r.type == 'img' || r.type == 'image';
    final bucket = buckets[switch (category) {
      'script' => 'scripts',
      'style' => 'css',
      'image' => 'images',
      'document' => 'html',
      _ => 'other',
    }]!;
    bucket.count++;

    final tx = _value(r.transfer);
    if (tx == null) {
      partial = true;
    } else {
      bucket.transfer += tx;
      bucket.hasTransfer = true;
    }

    final dec = _value(r.decoded);
    if (dec == null) {
      if (!isImage) partial = true;
    } else if (!(isImage && b.platform.isWebKit)) {
      bucket.decoded += dec;
      bucket.hasDecoded = true;
    }
  }

  var documentFromServer = false;
  final server = p.server;
  if (server is Present<ServerSnapshot>) {
    final body = server.value.body;
    if (body is Present<ServerBody>) {
      final html = buckets['html']!;
      html.count++;
      html.transfer += body.value.transferLength;
      html.hasTransfer = true;
      html.decoded += body.value.byteLength;
      html.hasDecoded = true;
      if (body.value.truncated) partial = true;
      documentFromServer = true;
    }
  }

  final all = buckets.values;
  final hasTransfer = all.any((x) => x.hasTransfer);
  final hasDecoded = all.any((x) => x.hasDecoded);
  final snapshotTime = _value(b.snapshotTimeMs);
  return {
    if (hasTransfer) 'transfer': all.fold<int>(0, (s, x) => s + x.transfer),
    if (hasDecoded) 'decoded': all.fold<int>(0, (s, x) => s + x.decoded),
    'isPartial': partial,
    if (documentFromServer) 'documentSource': 'server',
    if (snapshotTime != null) 'snapshotTimeMs': snapshotTime,
    'breakdown': {for (final e in buckets.entries) e.key: e.value.toMap()},
  };
}

Map<String, dynamic>? _storageArea(Observed<StorageArea> o) {
  final a = _value(o);
  if (a == null) return null;
  final bytes = _value(a.bytes);
  return {
    'count': a.count,
    if (bytes != null) 'bytes': bytes,
    'items': [
      for (final i in a.topItems) {'k': i.key, 's': i.bytes},
    ],
  };
}

/// `browserProbeResult`: what the browser reported about the page. The
/// server's status code and the page title are not copied (B19).
Map<String, dynamic>? legacyBrowserProbeMap(PageInspection p) {
  final b = _browser(p);
  if (b == null) return null;
  final resources = _resources(b);
  final weight = legacyPageWeight(p);
  final storage = _value(b.storage);
  final local = storage == null ? null : _storageArea(storage.local);
  final session = storage == null ? null : _storageArea(storage.session);
  return {
    'browser': 'InAppWebView',
    'os': b.platform.name,
    'platform': b.platform.name,
    'url': b.url.toString(),
    if (resources != null) 'resourceCount': resources.length,
    if (weight != null)
      'pageWeight': {
        if (weight.containsKey('transfer')) 'totalTransfer': weight['transfer'],
        if (weight.containsKey('decoded')) 'totalDecoded': weight['decoded'],
        'isPartial': weight['isPartial'],
        if (weight.containsKey('documentSource'))
          'documentSource': weight['documentSource'],
        if (weight.containsKey('snapshotTimeMs'))
          'snapshotTimeMs': weight['snapshotTimeMs'],
        'breakdown': weight['breakdown'],
      },
    if (local != null || session != null)
      'storage': {
        if (local != null) 'localStorage': local,
        if (session != null) 'sessionStorage': session,
      },
  };
}

/// The rendered DOM as a file for the viewer. Its `size` is the UTF-8 byte
/// length of the serialized DOM text: it is not the size of the network
/// response (that is the server body's or a resource entry's). Null unless
/// the DOM is Present.
HtmlFile? legacyDomFile(BrowserSnapshot b,
    {required String name, Map<String, dynamic>? probeResult}) {
  final dom = _value(b.renderedDom);
  if (dom == null) return null;
  return HtmlFile(
    name: name,
    path: b.url.toString(),
    content: dom.text,
    lastModified: DateTime.now(),
    size: utf8.encode(dom.text).length,
    isUrl: true,
    probeResult: probeResult,
  );
}
