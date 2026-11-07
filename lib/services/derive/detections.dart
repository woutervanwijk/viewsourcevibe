import '../../models/detection_evidence.dart';
import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/file_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../detection/engine.dart';
import 'cookies.dart';

void _tag(Detection d, DataSource source) {
  for (var i = 0; i < d.evidence.length; i++) {
    if (d.evidence[i].source == null) {
      d.evidence[i] = d.evidence[i].withSource(source);
    }
  }
}

/// Folds [other] into [into] (same service seen in another document).
void _mergeInto(Detection into, Detection other) {
  for (final e in other.evidence) {
    into.add(e);
  }
  into.hosts.addAll(other.hosts);
  into.inSource = into.inSource || other.inSource;
  into.version ??= other.version;
  if (into.inSource) {
    into.evidence.removeWhere((x) => x.kind == EvidenceKind.hint);
  }
}

/// Services, trackers and technologies of the current inspection, from
/// snapshots only:
///  * the server's response headers and body source (evidence: server),
///  * the rendered DOM (browser) or, for a local file, the file text (file),
///  * the browser's resource URLs (browser),
///  * cookies: Set-Cookie headers (server), the browser's cookies (browser).
///
/// A detection found only in the DOM (e.g. injected by JavaScript) has
/// browser evidence only. Nothing from an earlier page or file leaks in: the
/// inputs are this inspection's snapshots.
List<Detection> deriveDetections(PageInspection p) {
  final byName = <String, Detection>{};
  void absorb(Iterable<Detection> found, DataSource source) {
    for (final d in found) {
      _tag(d, source);
      final existing = byName[d.name];
      if (existing == null) {
        byName[d.name] = d;
      } else {
        _mergeInto(existing, d);
      }
    }
  }

  var pageUrl = '';
  var html = '';

  final server = p.server;
  if (server is Present<ServerSnapshot> && server.value.hops.isNotEmpty) {
    final s = server.value;
    final fin = s.finalUrl;
    pageUrl = (fin is Present<Uri> ? fin.value : s.requestedUrl).toString();
    final headers = <String, String>{
      for (final e in s.hops.last.headers.entries)
        if (e.key != 'set-cookie') e.key: e.value.join(', '),
    };
    absorb(scanSource(html: '', headers: headers, pageUrl: pageUrl),
        DataSource.server);
    final body = s.body;
    if (body is Present<ServerBody> && !body.value.decoded.isBinary) {
      html = body.value.decoded.text;
      absorb(scanSource(html: html, pageUrl: pageUrl), DataSource.server);
    }
  }

  final requests = <String>[];
  final browser = p.browser;
  if (browser is Present<BrowserSnapshot>) {
    final b = browser.value;
    if (pageUrl.isEmpty) pageUrl = b.url.toString();
    final dom = b.renderedDom;
    if (dom is Present<RenderedDom>) {
      html = dom.value.text;
      absorb(scanSource(html: html, pageUrl: pageUrl), DataSource.browser);
    }
    final res = b.resources;
    if (res is Present<List<ResourceEntry>>) {
      requests.addAll(res.value.map((r) => r.url));
    }
  }

  final file = p.file;
  if (file is Present<FileSnapshot> && !file.value.isBinary) {
    html = file.value.text.text;
    absorb(scanSource(html: html), DataSource.file);
  }

  final result = detect(
    pageUrl: pageUrl,
    html: html,
    source: byName.values.toList(),
    requests: requests,
    cookies: [for (final c in deriveCookies(p)) cookieInfoToMap(c)],
  );
  for (final d in result) {
    for (var i = 0; i < d.evidence.length; i++) {
      final e = d.evidence[i];
      if (e.source != null) continue;
      d.evidence[i] = e.withSource(switch (e.kind) {
        EvidenceKind.header => DataSource.server,
        _ => DataSource.browser,
      });
    }
  }
  return result;
}
