import 'dart:convert';

import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../../utils/format_utils.dart';
import 'divergences.dart';
import 'observed_text.dart';
import 'page_size.dart' show formatSizePair;
import 'page_weight.dart';

// ---------------------------------------------------------------------------
// Content sniffing (moved out of the General view)
// ---------------------------------------------------------------------------

bool _looksLikeJson(String content) {
  final trimmed = content.trimLeft();
  if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return false;
  // Very large bodies: judge by their first and last character only.
  if (trimmed.length > (2 << 20)) {
    final end = trimmed.trimRight();
    return end.endsWith('}') || end.endsWith(']');
  }
  try {
    jsonDecode(trimmed);
    return true;
  } catch (_) {
    return false;
  }
}

bool _looksLikeStandaloneCss(String content) {
  final trimmed = content.trimLeft();
  final lower = trimmed.toLowerCase();
  if (lower.contains('<style') || lower.contains('<script')) return false;
  if (RegExp(r'^(const|let|var|function|class|import|export)\b')
      .hasMatch(lower)) {
    return false;
  }
  if (lower.startsWith('@charset') ||
      lower.startsWith('@import') ||
      lower.startsWith('@media') ||
      lower.startsWith('@font-face') ||
      lower.startsWith('@keyframes')) {
    return true;
  }
  return RegExp(r'^[.#]?[a-z0-9_:\-\*\[\]="\s,>+~]+\{[^}]*:[^}]*\}',
          caseSensitive: false, dotAll: true)
      .hasMatch(trimmed);
}

bool _looksLikeStandaloneJavascript(String content) {
  final trimmed = content.trimLeft();
  final lower = trimmed.toLowerCase();
  if (lower.contains('<script') || lower.contains('<style')) return false;
  return RegExp(
    r'^(import\s|export\s|const\s|let\s|var\s|function\s|class\s|async\s+function\s|\(\s*function|\w+\s*=>)',
    caseSensitive: false,
  ).hasMatch(trimmed);
}

/// What a text looks like: html, xml, json, css, javascript, text or empty.
String sniffContentType(String content, String? filename) {
  final trimmed = content.trimLeft();
  final lowerName = filename?.toLowerCase() ?? '';
  if (trimmed.isEmpty) return 'empty';

  final lower = trimmed.toLowerCase();
  final withoutLeadingComments = lower.replaceFirst(
    RegExp(r'^(<!--.*?-->\s*)+', dotAll: true),
    '',
  );

  // HTML wins before CSS/JS. Full documents and fragments often contain
  // inline <style> or <script> blocks that look like standalone CSS/JS.
  if (withoutLeadingComments.startsWith('<!doctype html') ||
      withoutLeadingComments.startsWith('<html') ||
      RegExp(r'<(head|body|title|meta|script|style|div|main|section|article)\b')
          .hasMatch(lower)) {
    return 'html';
  }

  if (lower.startsWith('<?xml') ||
      lower.startsWith('<rss') ||
      lower.startsWith('<feed') ||
      lower.startsWith('<svg')) {
    return 'xml';
  }

  if (_looksLikeJson(trimmed)) return 'json';

  if (lowerName.endsWith('.css') || _looksLikeStandaloneCss(trimmed)) {
    return 'css';
  }
  if (lowerName.endsWith('.js') ||
      lowerName.endsWith('.mjs') ||
      _looksLikeStandaloneJavascript(trimmed)) {
    return 'javascript';
  }
  return 'text';
}

bool _mimeMatchesSniff(String mime, String sniffed) {
  if (sniffed == 'empty') return true;
  if (mime.contains('html')) return sniffed == 'html';
  if (mime.contains('xml') || mime.contains('svg')) return sniffed == 'xml';
  if (mime.contains('json')) return sniffed == 'json';
  if (mime.contains('javascript') || mime.contains('ecmascript')) {
    return sniffed == 'javascript' || sniffed == 'text';
  }
  if (mime == 'text/css') return sniffed == 'css' || sniffed == 'text';
  if (mime == 'text/plain') return sniffed == 'text';
  if (mime.startsWith('text/')) return sniffed == 'text';
  return true;
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// One response of the redirect chain.
class HopLine {
  final Uri url;
  final int status;
  final String reason;
  final String? location;

  const HopLine(this.url, this.status, this.reason, this.location);

  /// "301 Moved Permanently", or just "204" without a reason phrase.
  String get text => reason.isEmpty ? '$status' : '$status $reason';
}

/// One redirect: where it came from, what answered and where it pointed.
class RedirectStep {
  final String statusText;
  final String from;

  /// The next hop's URL, else the Location header; null when neither is known.
  final String? to;
  const RedirectStep(this.statusText, this.from, this.to);
}

/// Every 3xx answer in [hops]: where it came from and where it pointed.
List<RedirectStep> redirectStepsOf(List<HopLine> hops) => [
      for (var i = 0; i < hops.length; i++)
        if (hops[i].status >= 300 && hops[i].status < 400)
          RedirectStep(
            hops[i].text,
            hops[i].url.toString(),
            i + 1 < hops.length ? hops[i + 1].url.toString() : hops[i].location,
          ),
    ];

/// The hops of a server snapshot as lines.
List<HopLine> hopLinesOf(ServerSnapshot s) => [
      for (final h in s.hops)
        HopLine(h.url, h.statusCode, h.reasonPhrase, h.header('location')),
    ];

/// The status card: what the app's own request got (not the browser's).
class ServerStatus {
  final List<HopLine> hops;

  /// Every 3xx answer in the chain, in order.
  final List<RedirectStep> redirects;
  final Observed<Uri> finalUrl;
  final String? contentType;
  final String contentLengthLabel;
  final String bodyLabel;
  final String userAgent;
  final String? redirectTo;
  final String remoteAddressLabel;
  final String timingLabel;

  const ServerStatus({
    required this.hops,
    required this.redirects,
    required this.finalUrl,
    required this.contentType,
    required this.contentLengthLabel,
    required this.bodyLabel,
    required this.userAgent,
    required this.redirectTo,
    required this.remoteAddressLabel,
    required this.timingLabel,
  });

  HopLine get last => hops.last;
  String get finalStatusText => last.text;
  bool get isRedirect => hops.length > 1 || redirectTo != null;
  String get finalUrlLabel => presentOrUnknown(finalUrl, (u) => u.toString());
}

enum ContentTypeVerdict { aligned, mismatch, noHeader }

class ContentTypeTruth {
  /// The Content-Type header as sent; null when the server sent none.
  final String? declared;
  final String sniffed;
  final ContentTypeVerdict verdict;

  const ContentTypeTruth(this.declared, this.sniffed, this.verdict);

  String get verdictText => switch (verdict) {
        ContentTypeVerdict.aligned => 'Header and content look aligned.',
        ContentTypeVerdict.mismatch =>
          'Header does not match the content of the server response.',
        ContentTypeVerdict.noHeader =>
          'The server sent no Content-Type header, nothing to compare.',
      };
}

/// One side of the source diff and whether it can be compared yet.
class DiffSide {
  final String name;
  final bool ready;
  final String status;
  const DiffSide(this.name, this.ready, this.status);
}

class SourceDiff {
  final int serverLines;
  final int browserLines;
  final int addedLines;
  final int removedLines;
  final int similarity;
  final List<String> samples;

  const SourceDiff({
    required this.serverLines,
    required this.browserLines,
    required this.addedLines,
    required this.removedLines,
    required this.similarity,
    required this.samples,
  });

  int get changed => addedLines + removedLines;
}

/// Server HTML against the rendered DOM. [diff] is null until both exist.
class SourceDiffCard {
  final List<DiffSide> sides;
  final SourceDiff? diff;
  const SourceDiffCard(this.sides, this.diff);
}

class RobotsCard {
  final String robotsUrl;
  final String robotsLabel;

  /// null = unknown.
  final bool? robotsFound;
  final String sitemapsLabel;
  final List<String> sitemaps;
  final String disallowLabel;
  final String allowLabel;
  final String? truncatedNote;
  final List<String> sampleDisallow;

  const RobotsCard({
    required this.robotsUrl,
    required this.robotsLabel,
    required this.robotsFound,
    required this.sitemapsLabel,
    required this.sitemaps,
    required this.disallowLabel,
    required this.allowLabel,
    required this.truncatedNote,
    required this.sampleDisallow,
  });
}

class StorageAreaCard {
  final String countLabel;
  final String sizeLabel;
  final List<({String key, String size})> items;
  const StorageAreaCard(this.countLabel, this.sizeLabel, this.items);
}

class StorageCard {
  /// null = the browser did not report this area, see [localUnknown].
  final StorageAreaCard? local;
  final StorageAreaCard? session;
  final String? localUnknown;
  final String? sessionUnknown;
  const StorageCard(
      this.local, this.session, this.localUnknown, this.sessionUnknown);
}

class BrowserCard {
  final String url;
  final String environment;
  final String resourcesLabel;
  final String documentSizeLabel;
  final String totalSizeLabel;

  /// Always null: the browser's page does not report an HTTP status; the
  /// server status belongs to the app's own request.
  final String? serverStatusNote = null;

  const BrowserCard({
    required this.url,
    required this.environment,
    required this.resourcesLabel,
    required this.documentSizeLabel,
    required this.totalSizeLabel,
  });
}

class NetworkCard {
  final String remoteAddress;
  final String responseTime;
  final String userAgent;
  final String? serverSoftware;
  final String? via;

  /// Navigation timing the browser measured (label, value).
  final List<(String, String)> browserTiming;

  const NetworkCard({
    required this.remoteAddress,
    required this.responseTime,
    required this.userAgent,
    required this.serverSoftware,
    required this.via,
    required this.browserTiming,
  });
}

/// Everything the General tab shows. Each card has its own state; none of
/// them is guessed from another.
class GeneralModel {
  final Observed<ServerStatus> status;
  final Observed<ContentTypeTruth> contentType;
  final SourceDiffCard diff;
  final Observed<RobotsCard> robots;
  final Observed<StorageCard> storage;
  final Observed<NetworkCard> network;
  final Observed<BrowserCard> browser;
  final List<Divergence> divergences;

  const GeneralModel({
    required this.status,
    required this.contentType,
    required this.diff,
    required this.robots,
    required this.storage,
    required this.network,
    required this.browser,
    required this.divergences,
  });
}

// ---------------------------------------------------------------------------
// Derive
// ---------------------------------------------------------------------------

/// Why a probe tab has nothing to show for this target, or null when the
/// target is a URL.
Unavailable<T>? probeGate<T>(PageInspection p) => switch (p.target) {
      NoTarget() => const Unavailable(
          UnavailableReason.notApplicable, 'Probe a URL to see details'),
      FileTarget() => const Unavailable(UnavailableReason.notApplicable,
          'This is a local file: there is no server response, so there is nothing to probe.'),
      UrlTarget() => null,
    };

String _bytes(int n) => '$n bytes';

Observed<ServerStatus> _status(PageInspection p) {
  final server = p.server;
  if (server is! Present<ServerSnapshot>) return notPresentAs(server);
  final s = server.value;
  if (s.hops.isEmpty) {
    return const Failed('The server did not answer.');
  }
  final hops = hopLinesOf(s);
  final last = s.hops.last;
  final lastIsRedirect = last.statusCode >= 300 && last.statusCode < 400;
  final body = s.body;
  String contentLength;
  String bodyLabel;
  if (body is Present<ServerBody>) {
    final b = body.value;
    final declared = b.contentLength;
    contentLength = declared is Present<int>
        ? '${_bytes(declared.value)} (Content-Length header)'
        : notPresentText(declared);
    bodyLabel = '${_bytes(b.byteLength)}'
        '${b.transferLength != b.byteLength ? ' (transfer ${_bytes(b.transferLength)})' : ''}'
        '${b.truncated ? ', cut off at the size limit' : ''}';
  } else {
    contentLength = unknownText(body);
    bodyLabel = unknownText(body);
  }
  final redirects = redirectStepsOf(hops);
  return Present(
      ServerStatus(
        hops: hops,
        redirects: redirects,
        finalUrl: s.finalUrl,
        contentType: last.header('content-type'),
        contentLengthLabel: contentLength,
        bodyLabel: bodyLabel,
        userAgent: s.userAgent,
        redirectTo: lastIsRedirect ? last.header('location') : null,
        remoteAddressLabel: presentOrUnknown(last.remoteAddress, (a) => a),
        timingLabel: presentOrUnknown(s.timingMs,
            (ms) => '$ms ms (measured by the app, including DNS and TLS)'),
      ),
      source: DataSource.server);
}

Observed<ContentTypeTruth> _contentType(PageInspection p) {
  final server = p.server;
  if (server is! Present<ServerSnapshot> || server.value.hops.isEmpty) {
    return notPresentAs(server);
  }
  final s = server.value;
  final body = s.body;
  if (body is! Present<ServerBody>) return notPresentAs(body);
  if (body.value.decoded.isBinary) {
    return const Unavailable(UnavailableReason.notApplicable,
        'binary response, there is no text to check the header against');
  }
  final raw = s.hops.last.header('content-type');
  final mime = (raw ?? '').split(';').first.trim().toLowerCase();
  final fileName = s.hops.last.url.pathSegments.isEmpty
      ? null
      : s.hops.last.url.pathSegments.last;
  final sniffed = sniffContentType(body.value.decoded.text, fileName);
  final verdict = mime.isEmpty
      ? ContentTypeVerdict.noHeader
      : _mimeMatchesSniff(mime, sniffed)
          ? ContentTypeVerdict.aligned
          : ContentTypeVerdict.mismatch;
  return Present(ContentTypeTruth(mime.isEmpty ? null : raw, sniffed, verdict),
      source: DataSource.server, provenance: Provenance.derived);
}

List<String> _normalizedLines(String source) => source
    .split(RegExp(r'\r?\n'))
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .toList();

String _shortDiffLine(String line) {
  final collapsed = line.replaceAll(RegExp(r'\s+'), ' ');
  return collapsed.length > 140
      ? '${collapsed.substring(0, 137)}...'
      : collapsed;
}

/// Line-level difference between two texts.
SourceDiff diffSources(String serverSource, String browserSource) {
  final serverLines = _normalizedLines(serverSource);
  final browserLines = _normalizedLines(browserSource);
  final serverSet = serverLines.toSet();
  final browserSet = browserLines.toSet();
  final removed = serverLines.where((l) => !browserSet.contains(l)).toList();
  final added = browserLines.where((l) => !serverSet.contains(l)).toList();
  final shared = serverSet.intersection(browserSet).length;
  final total = serverSet.union(browserSet).length;
  final similarity = total == 0 ? 100 : ((shared / total) * 100).round();
  return SourceDiff(
    serverLines: serverLines.length,
    browserLines: browserLines.length,
    addedLines: added.length,
    removedLines: removed.length,
    similarity: similarity,
    samples: [
      ...removed.take(4).map((l) => '- ${_shortDiffLine(l)}'),
      ...added.take(4).map((l) => '+ ${_shortDiffLine(l)}'),
    ],
  );
}

DiffSide _side(String name, Observed<String> text) => switch (text) {
      Present<String>() => DiffSide(name, true, 'ready'),
      Pending<String>() => DiffSide(name, false, 'waiting'),
      Failed<String>(:final error) => DiffSide(name, false, 'failed: $error'),
      Unavailable<String>(:final reason, :final detail) =>
        DiffSide(name, false, unavailableMessage(reason, detail)),
    };

Observed<String> _serverText(PageInspection p) {
  final server = p.server;
  if (server is! Present<ServerSnapshot>) return notPresentAs(server);
  final body = server.value.body;
  if (body is! Present<ServerBody>) return notPresentAs(body);
  if (body.value.decoded.isBinary) {
    return const Unavailable(
        UnavailableReason.notApplicable, 'binary response');
  }
  return Present(body.value.decoded.text, source: DataSource.server);
}

Observed<String> _domText(PageInspection p) {
  final browser = p.browser;
  if (browser is! Present<BrowserSnapshot>) return notPresentAs(browser);
  final dom = browser.value.renderedDom;
  if (dom is! Present<RenderedDom>) return notPresentAs(dom);
  return Present(dom.value.text, source: DataSource.browser);
}

SourceDiffCard _diff(PageInspection p) {
  final a = _serverText(p);
  final b = _domText(p);
  return SourceDiffCard(
    [_side('server HTML', a), _side('rendered DOM', b)],
    a is Present<String> && b is Present<String>
        ? diffSources(a.value, b.value)
        : null,
  );
}

List<String> _sampleDisallow(String robots) {
  final out = <String>[];
  for (final raw in robots.split(RegExp(r'\r?\n|\r'))) {
    final line = raw.split('#').first.trim();
    final i = line.indexOf(':');
    if (i <= 0) continue;
    if (line.substring(0, i).trim().toLowerCase() != 'disallow') continue;
    final value = line.substring(i + 1).trim();
    if (value.isNotEmpty) out.add(value);
  }
  return out.take(8).toList();
}

Observed<RobotsCard> _robots(PageInspection p) {
  final r = p.robots;
  if (r is! Present<RobotsInfo>) return notPresentAs(r);
  final info = r.value;
  final t = p.target;
  final origin = t is UrlTarget
      ? Uri(scheme: t.url.scheme, host: t.url.host, port: t.url.port)
      : null;
  final status = info.robotsStatus;
  final listed = info.sitemaps;
  final text = info.robotsText;
  String count(String name, Observed<int> o) =>
      o is Present<int> ? '${o.value} $name' : '$name: ${unknownText(o)}';
  return Present(
      RobotsCard(
        robotsUrl: origin?.resolve('/robots.txt').toString() ?? 'unknown',
        robotsLabel: status is Present<int>
            ? 'robots ${status.value}'
            : 'robots: ${unknownText(status)}',
        robotsFound: status is Present<int>
            ? status.value >= 200 && status.value < 400
            : null,
        sitemapsLabel: listed is Present<List<String>>
            ? '${listed.value.length} sitemap${listed.value.length == 1 ? '' : 's'}'
            : 'sitemaps: ${unknownText(listed)}',
        sitemaps: listed is Present<List<String>> ? listed.value : const [],
        disallowLabel: count('disallow', info.disallowCount),
        allowLabel: count('allow', info.allowCount),
        truncatedNote: info.robotsTruncated
            ? 'robots.txt is too large: only the first part was read, so rule and sitemap counts are unknown.'
            : null,
        sampleDisallow:
            text is Present<String> ? _sampleDisallow(text.value) : const [],
      ),
      source: DataSource.server);
}

Observed<StorageCard> _storage(PageInspection p) {
  final browser = p.browser;
  if (browser is! Present<BrowserSnapshot>) return notPresentAs(browser);
  final storage = browser.value.storage;
  if (storage is! Present<BrowserStorage>) return notPresentAs(storage);
  StorageAreaCard? area(String label, Observed<StorageArea> a) {
    if (a is! Present<StorageArea>) return null;
    final v = a.value;
    return StorageAreaCard(
      '$label ${v.count} key${v.count == 1 ? '' : 's'}',
      presentOrUnknown(v.bytes, FormatUtils.formatBytes),
      [
        for (final i in v.topItems)
          (key: i.key, size: FormatUtils.formatBytes(i.bytes)),
      ],
    );
  }

  final s = storage.value;
  return Present(
      StorageCard(
        area('local', s.local),
        area('session', s.session),
        s.local is Present ? null : unknownText(s.local),
        s.session is Present ? null : unknownText(s.session),
      ),
      source: DataSource.browser);
}

String environmentOf(BrowserPlatform p) => switch (p) {
      BrowserPlatform.ios => 'iOS (WebKit)',
      BrowserPlatform.macos => 'macOS (WebKit)',
      BrowserPlatform.android => 'Android',
      BrowserPlatform.windows => 'Windows',
      BrowserPlatform.linux => 'Linux',
      BrowserPlatform.unknown => 'unknown platform',
    };

Observed<BrowserCard> _browserCard(PageInspection p) {
  final browser = p.browser;
  if (browser is! Present<BrowserSnapshot>) return notPresentAs(browser);
  final b = browser.value;
  final res = b.resources;
  final weight = derivePageWeight(p);

  String resources;
  if (res is Present<List<ResourceEntry>>) {
    resources = '${res.value.length} requests';
    if (b.resourcesTruncated) {
      resources = '${res.value.length} requests (list incomplete: '
          '${b.resourcesDropped} more were dropped)';
    }
  } else {
    resources = unknownText(res);
  }

  final server = p.server;
  String document;
  if (server is Present<ServerSnapshot> &&
      server.value.body is Present<ServerBody>) {
    final body = (server.value.body as Present<ServerBody>).value;
    document =
        '${formatSizePair(decoded: body.byteLength, transfer: body.transferLength)} (server response)';
  } else {
    document = 'unknown (the server response is not available)';
  }

  String total;
  if (weight == null) {
    total = unknownText(res);
  } else {
    final text =
        formatSizePair(decoded: weight.decoded, transfer: weight.transfer);
    total = text == null ? 'size unknown' : '${weight.totalPrefix}$text';
  }
  return Present(
      BrowserCard(
        url: b.url.toString(),
        environment: environmentOf(b.platform),
        resourcesLabel: resources,
        documentSizeLabel: document,
        totalSizeLabel: total,
      ),
      source: DataSource.browser);
}

Observed<NetworkCard> _network(PageInspection p) {
  final server = p.server;
  if (server is! Present<ServerSnapshot> || server.value.hops.isEmpty) {
    return notPresentAs(server);
  }
  final s = server.value;
  final last = s.hops.last;
  final timing = <(String, String)>[];
  final browser = p.browser;
  if (browser is Present<BrowserSnapshot> &&
      browser.value.navigation is Present<NavigationTiming>) {
    final n = (browser.value.navigation as Present<NavigationTiming>).value;
    String ms(Observed<double> o) =>
        presentOrUnknown(o, (v) => '${v.round()} ms');
    timing
      ..add(('Time to first byte', ms(n.timeToFirstByte)))
      ..add(('DOM interactive', ms(n.domInteractive)))
      ..add(('Load event', ms(n.loadEvent)));
  }
  return Present(
      NetworkCard(
        remoteAddress: presentOrUnknown(last.remoteAddress, (a) => a),
        responseTime: presentOrUnknown(s.timingMs,
            (ms) => '$ms ms (measured by the app, including DNS and TLS)'),
        userAgent: s.userAgent,
        serverSoftware: last.header('server'),
        via: last.header('via'),
        browserTiming: timing,
      ),
      source: DataSource.server);
}

/// The General tab: status, content-type check, source diff, robots,
/// storage, network and browser cards, each with its own state.
Observed<GeneralModel> deriveGeneral(PageInspection p,
    {List<Divergence> divergences = const []}) {
  final gate = probeGate<GeneralModel>(p);
  if (gate != null) return gate;
  return Present(
      GeneralModel(
        status: _status(p),
        contentType: _contentType(p),
        diff: _diff(p),
        robots: _robots(p),
        storage: _storage(p),
        network: _network(p),
        browser: _browserCard(p),
        divergences: divergences,
      ),
      source: DataSource.server,
      provenance: Provenance.derived);
}
