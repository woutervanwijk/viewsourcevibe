import 'dart:convert';

import '../models/html_file.dart';
import '../models/inspection/browser_snapshot.dart';
import '../models/inspection/observed.dart';
import '../models/inspection/page_inspection.dart';
import 'derive/page_weight.dart';

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

/// The page weight as the old map: totals over the values that are Present,
/// a breakdown per type, `isPartial` when something is missing. See
/// [derivePageWeight]. Null unless the browser's resources are Present.
Map<String, dynamic>? legacyPageWeight(PageInspection p) {
  final w = derivePageWeight(p);
  if (w == null) return null;
  return {
    if (w.transfer != null) 'transfer': w.transfer,
    if (w.decoded != null) 'decoded': w.decoded,
    'isPartial': w.isPartial,
    if (w.documentSource != null) 'documentSource': w.documentSource!.name,
    if (w.snapshotTimeMs != null) 'snapshotTimeMs': w.snapshotTimeMs,
    'breakdown': {
      for (final e in w.breakdown.entries)
        e.key: {
          'count': e.value.count,
          if (e.value.transfer != null) 'transfer': e.value.transfer,
          if (e.value.decoded != null) 'decoded': e.value.decoded,
        },
    },
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
