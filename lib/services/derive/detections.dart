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

/// The texts the (expensive) source scan runs on, taken from the snapshots.
/// Compare with [sameDetectionTexts]: the strings are the snapshots' own, so
/// a resources/cookies-only update leaves them identical.
class DetectionTexts {
  final String pageUrl;
  final Map<String, String> serverHeaders;
  final String? serverText;
  final String? domText;
  final String? fileText;
  const DetectionTexts({
    required this.pageUrl,
    this.serverHeaders = const {},
    this.serverText,
    this.domText,
    this.fileText,
  });

  int get totalLength =>
      (serverText?.length ?? 0) +
      (domText?.length ?? 0) +
      (fileText?.length ?? 0);
}

/// Runs the source scan, possibly off-thread.
typedef DetectionScanner = Future<List<Map<String, dynamic>>> Function(
    DetectionTexts texts);

bool sameDetectionTexts(DetectionTexts? a, DetectionTexts? b) =>
    a != null &&
    b != null &&
    a.pageUrl == b.pageUrl &&
    identical(a.serverText, b.serverText) &&
    identical(a.domText, b.domText) &&
    identical(a.fileText, b.fileText) &&
    a.serverHeaders.length == b.serverHeaders.length &&
    a.serverHeaders.entries.every((e) => b.serverHeaders[e.key] == e.value);

DetectionTexts detectionTextsOf(PageInspection p) {
  var pageUrl = '';
  var headers = const <String, String>{};
  String? serverText, domText, fileText;

  final server = p.server;
  if (server is Present<ServerSnapshot> && server.value.hops.isNotEmpty) {
    final s = server.value;
    final fin = s.finalUrl;
    pageUrl = (fin is Present<Uri> ? fin.value : s.requestedUrl).toString();
    headers = {
      for (final e in s.hops.last.headers.entries)
        if (e.key != 'set-cookie') e.key: e.value.join(', '),
    };
    final body = s.body;
    if (body is Present<ServerBody> && !body.value.decoded.isBinary) {
      serverText = body.value.decoded.text;
    }
  }
  final browser = p.browser;
  if (browser is Present<BrowserSnapshot>) {
    if (pageUrl.isEmpty) pageUrl = browser.value.url.toString();
    final dom = browser.value.renderedDom;
    if (dom is Present<RenderedDom>) domText = dom.value.text;
  }
  final file = p.file;
  if (file is Present<FileSnapshot> && !file.value.isBinary) {
    fileText = file.value.text.text;
  }
  return DetectionTexts(
      pageUrl: pageUrl,
      serverHeaders: headers,
      serverText: serverText,
      domText: domText,
      fileText: fileText);
}

/// The source scan (headers, server body, DOM, file) as plain maps, so it
/// can run in an isolate. Every evidence item carries its DataSource.
List<Map<String, dynamic>> scanTextsToMaps(DetectionTexts t) {
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

  if (t.serverHeaders.isNotEmpty) {
    absorb(scanSource(html: '', headers: t.serverHeaders, pageUrl: t.pageUrl),
        DataSource.server);
  }
  if (t.serverText != null) {
    absorb(
        scanSource(html: t.serverText!, pageUrl: t.pageUrl), DataSource.server);
  }
  if (t.domText != null) {
    absorb(
        scanSource(html: t.domText!, pageUrl: t.pageUrl), DataSource.browser);
  }
  if (t.fileText != null) {
    absorb(scanSource(html: t.fileText!), DataSource.file);
  }
  return [for (final d in byName.values) d.toMap()];
}

/// Services, trackers and technologies of the current inspection, from
/// snapshots only:
///  * the server's response headers and body source (evidence: server),
///  * the rendered DOM (browser) or, for a local file, the file text (file),
///  * the browser's resource URLs (browser),
///  * cookies: Set-Cookie headers (server), the browser's cookies (browser).
///
/// [scanned] is the result of [scanTextsToMaps] for this inspection's texts
/// (cached or computed elsewhere); when null the scan runs here. A
/// detection found only in the DOM (e.g. injected by JavaScript) has browser
/// evidence only. Nothing from an earlier page or file leaks in.
List<Detection> deriveDetections(PageInspection p,
    {List<Map<String, dynamic>>? scanned}) {
  final texts = detectionTextsOf(p);
  final source = Detection.listFrom(scanned ?? scanTextsToMaps(texts));

  final requests = <String>[];
  final browser = p.browser;
  if (browser is Present<BrowserSnapshot>) {
    final res = browser.value.resources;
    if (res is Present<List<ResourceEntry>>) {
      requests.addAll(res.value.map((r) => r.url));
    }
  }

  final result = detect(
    pageUrl: texts.pageUrl,
    html: texts.domText ?? texts.serverText ?? texts.fileText ?? '',
    source: source,
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
