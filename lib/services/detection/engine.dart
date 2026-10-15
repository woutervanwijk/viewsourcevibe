import 'package:view_source_vibe/models/detection_evidence.dart';
import 'package:view_source_vibe/services/detection/catalog.dart';

export 'package:view_source_vibe/services/detection/catalog.dart';

// One detection engine for every tab. The page source is scanned once (in the
// metadata isolate, see [scanSource]); requests and cookies, which arrive
// later from the browser, are merged in with [detect].

class Detection {
  final Entity entity;
  final List<DetectionEvidence> evidence = [];
  final Set<String> hosts = {};
  final Set<String> cookies = {};
  int requests = 0;

  /// Requests that report the visit (see [Entity.beacons]).
  int pings = 0;

  /// Found in page code (script, tag attribute, header or generator).
  bool inSource = false;

  /// Only seen as a preconnect / dns-prefetch hint.
  bool get hintOnly =>
      !inSource && requests == 0 && cookies.isEmpty && evidence.isNotEmpty;

  String? version;

  Detection(this.entity);

  /// How certain the detection is (0–100), with the strongest signal.
  (int, String) get confidence {
    if (evidence.any((e) => e.kind == EvidenceKind.header)) {
      return (92, 'Response header');
    }
    if (requests > 0) return (90, 'Loaded by the page');
    if (version != null) return (88, 'Version in a generator tag or file name');
    if (cookies.isNotEmpty) return (82, 'Cookie set on this site');
    if (inSource) return (72, 'Found in the page source');
    return (40, 'Connection hint only');
  }

  String get name => entity.name;
  DetectionCategory get category => entity.category;

  void add(DetectionEvidence item) {
    if (evidence.length < 12 &&
        !evidence
            .any((e) => e.title == item.title && e.detail == item.detail)) {
      evidence.add(item);
    }
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category.name,
        'evidence': [for (final e in evidence) e.toMap()],
        'hosts': hosts.toList(),
        'inSource': inSource,
        if (version != null) 'version': version,
      };

  static Detection? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString() ?? '';
    final category = DetectionCategory.values
        .where((c) => c.name == raw['category'])
        .firstOrNull;
    if (name.isEmpty || category == null) return null;
    final d = Detection(entityNamed(name) ?? Entity(name, category))
      ..inSource = raw['inSource'] == true
      ..version = raw['version']?.toString();
    d.hosts.addAll([for (final h in raw['hosts'] as List? ?? []) '$h']);
    for (final e in raw['evidence'] as List? ?? []) {
      if (DetectionEvidence.fromMap(e) case final item?) d.evidence.add(item);
    }
    return d;
  }

  static List<Detection> listFrom(dynamic raw) => [
        for (final item in raw is List ? raw : const [])
          if (fromMap(item) case final d?) d,
      ];
}

String _hostOf(String url) {
  if (url.startsWith('data:') || url.startsWith('blob:')) return '';
  return Uri.tryParse(url.startsWith('//') ? 'https:$url' : url)
          ?.host
          .toLowerCase() ??
      '';
}

bool _sameSite(String host, String pageHost) =>
    pageHost.isNotEmpty &&
    (host == pageHost ||
        host.endsWith('.$pageHost') ||
        pageHost.endsWith('.$host'));

final _compiled = [
  for (final e in catalog)
    for (final p in e.patterns) (e, RegExp(p)),
];

final _cookieRules = [
  for (final e in catalog)
    for (final c in e.cookies) (e, c),
];

/// Entities for a URL: specific URL patterns (gtag.js?id=AW- is Ads, not
/// Tag Manager) win over the host; same-site hosts only match patterns.
/// A technology pattern (jquery.min.js) does not hide who serves the file,
/// so then the host's service (Google Hosted Libraries) is returned too.
List<Entity> _entitiesForUrl(String url, String host, String pageHost) {
  final byPattern = _compiled.where((c) => c.$2.hasMatch(url)).firstOrNull?.$1;
  final byHost = _sameSite(host, pageHost) ? null : entityForHost(host);
  return [
    if (byPattern != null) byPattern,
    if (byHost != null &&
        byHost != byPattern &&
        (byPattern == null || byPattern.category.tech))
      byHost,
  ];
}

final _resourcePath = RegExp(
    r'\.(?:m?js|css|json|gif|png|jpe?g|svg|webp|avif|ico|woff2?|php|html?|aspx?)(?:[?#]|$)'
    r'|(?:^|/)(?:js|embed|widgets?|player|sdk|tags?|pixel|collect|sync|ads?|beacon|track(?:ing)?|events?|analytics|load|loader|serve|launcher|getuid)(?:[/?.#]|$)',
    caseSensitive: false);
final _attributeValueBefore = RegExp(
    r'''(?:=\s*["']?|url\(\s*["']?|@import\s*["']?|,\s*)(?:https?:)?$''');
final _srcBefore =
    RegExp(r'src[\w-]*\W{0,8}(?:https?:)?\\?$', caseSensitive: false);

/// Inside a script, a URL is only a dependency when it looks like a resource
/// (a .js file, an embed, a pixel), stands alone as a host, or is assigned
/// to a `src`. Profile and article links in JSON data (sameAs, href) are not.
bool _usedInScript(String html, int start, String path) {
  if (path.isEmpty || _resourcePath.hasMatch(path)) return true;
  return _srcBefore
      .hasMatch(html.substring(start < 40 ? 0 : start - 40, start));
}

/// The service whose first-party cookie this is, from the catalogue.
Entity? entityForCookie(String name) {
  for (final (e, rule) in _cookieRules) {
    if (rule.endsWith('*')
        ? name.startsWith(rule.substring(0, rule.length - 1))
        : name == rule) {
      return e;
    }
  }
  return null;
}

// ── Page source context ────────────────────────────────────────────────────

enum _Ctx { code, tag, script, hint, comment, skip }

/// Classifies positions in the page: code (scripts, styles, tag attributes)
/// counts; visible text, links and JSON-LD profile links do not.
class _Source {
  final String html;
  final String lower;
  final List<(int, int, _Ctx)> regions = [];

  _Source(this.html) : lower = html.toLowerCase() {
    for (final m in RegExp(r'<!--[\s\S]*?-->').allMatches(html)) {
      regions.add((m.start, m.end, _Ctx.comment));
    }
    final scripts = RegExp(r'<(script|style)\b([^>]*)>([\s\S]*?)</\1\s*>',
        caseSensitive: false);
    for (final m in scripts.allMatches(html)) {
      final start = m.end - m[3]!.length - '</${m[1]}>'.length;
      if (_inComment(m.start)) continue;
      final jsonLd = m[2]!.toLowerCase().contains('ld+json');
      regions.add((
        start,
        start + m[3]!.length,
        jsonLd
            ? _Ctx.skip
            : m[1]!.toLowerCase() == 'script'
                ? _Ctx.script
                : _Ctx.code
      ));
    }
    regions.sort((a, b) => a.$1.compareTo(b.$1));
  }

  bool _inComment(int index) =>
      regions.any((r) => r.$3 == _Ctx.comment && index >= r.$1 && index < r.$2);

  _Ctx at(int index) {
    // Last region starting at or before index.
    var lo = 0, hi = regions.length - 1, found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (regions[mid].$1 <= index) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (found >= 0 && index < regions[found].$2) return regions[found].$3;

    final lt = lower.lastIndexOf('<', index);
    if (lt < 0 || lower.lastIndexOf('>', index - 1) > lt) return _Ctx.skip;
    final tag = RegExp(r'<\s*([a-z0-9-]+)').matchAsPrefix(lower, lt)?[1] ?? '';
    if (tag == 'a' || tag == 'area' || tag == 'meta') return _Ctx.skip;
    if (tag == 'link') {
      final end = lower.indexOf('>', index);
      final rel = RegExp(r'''\brel\s*=\s*["']?([^"'>]+)''').firstMatch(
              lower.substring(lt, end < 0 ? lower.length : end))?[1] ??
          '';
      if (rel.contains('preconnect') || rel.contains('dns-prefetch')) {
        return _Ctx.hint;
      }
      if (!RegExp(r'stylesheet|preload|prefetch|icon').hasMatch(rel)) {
        return _Ctx.skip; // canonical, alternate, author, …
      }
    }
    return _Ctx.tag;
  }
}

String _headerName(String name) => name
    .split('-')
    .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
    .join('-');

/// Scans the page source and response headers. Runs in the metadata isolate.
List<Detection> scanSource({
  required String html,
  Map<String, String>? headers,
  String pageUrl = '',
}) {
  final pageHost = _hostOf(pageUrl);
  final found = <String, Detection>{};
  Detection hit(Entity e) => found.putIfAbsent(e.name, () => Detection(e));

  // Headers.
  final h = {
    for (final e in (headers ?? const {}).entries) e.key.toLowerCase(): e.value
  };
  for (final e in catalog) {
    e.headers.forEach((name, regex) {
      final value = h[name];
      if (value == null) return;
      final m = RegExp(regex, caseSensitive: false).firstMatch(value);
      if (regex.isNotEmpty && m == null) return;
      final d = hit(e)
        ..inSource = true
        ..add(DetectionEvidence(
            EvidenceKind.header, 'Response header ${_headerName(name)}',
            detail: '${_headerName(name)}: $value'));
      if (m != null && m.groupCount > 0) d.version ??= m[1];
    });
  }
  if (html.isEmpty) return found.values.toList();

  final source = _Source(html);

  // Generator meta tags.
  for (final tag
      in RegExp(r'<meta\b[^>]*\bgenerator\b[^>]*>', caseSensitive: false)
          .allMatches(html)) {
    final content =
        RegExp(r'''content\s*=\s*["']([^"']*)''', caseSensitive: false)
                .firstMatch(tag[0]!)?[1] ??
            '';
    for (final e in catalog) {
      if (e.generator == null) continue;
      final m = RegExp(e.generator!, caseSensitive: false).firstMatch(content);
      if (m == null) continue;
      final d = hit(e)
        ..inSource = true
        ..add(DetectionEvidence.htmlAt(html, tag.start));
      if (m.groupCount > 0 && m[1] != null) d.version ??= m[1];
    }
  }

  void record(Entity e, int index, String match, _Ctx ctx) {
    if (ctx == _Ctx.skip || (ctx == _Ctx.comment && !e.category.tech)) return;
    final d = hit(e);
    if (ctx == _Ctx.hint) {
      if (!d.inSource) {
        final at = DetectionEvidence.htmlAt(html, index);
        d.add(DetectionEvidence(EvidenceKind.hint, 'Connection hint only',
            detail: at.detail, line: at.line));
      }
      return;
    }
    if (!d.inSource) {
      d.evidence.removeWhere((x) => x.kind == EvidenceKind.hint);
      d.add(DetectionEvidence.htmlAt(html, index, match: match));
    }
    d.inSource = true;
  }

  // Hostnames in URLs (`//host`, also JSON-escaped `\\/\\/host`).
  final terminator = RegExp('["\'\\s<>)]');
  for (final m in RegExp(
          r'(?:\\?/){2}([a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+)',
          caseSensitive: false)
      .allMatches(html)) {
    final host = m[1]!.toLowerCase();
    final end = html.indexOf(terminator, m.end);
    final path = html
        .substring(m.end, end < 0 ? html.length : end)
        .replaceAll(r'\/', '/')
        .replaceFirst(RegExp(r'\\+$'), '');
    final entities = _entitiesForUrl('//$host$path', host, pageHost);
    if (entities.isEmpty) continue;
    final ctx = source.at(m.start);
    // A URL that is a whole attribute value (src, href, srcset) is used; one
    // inside a JSON blob in an attribute is judged like script data.
    final inData = ctx == _Ctx.script ||
        (ctx == _Ctx.tag &&
            !_attributeValueBefore.hasMatch(
                html.substring(m.start < 20 ? 0 : m.start - 20, m.start)));
    if (inData && !_usedInScript(html, m.start, path)) {
      continue;
    }
    for (final e in entities) {
      record(e, m.start, host, ctx);
      if (ctx != _Ctx.skip && ctx != _Ctx.comment) {
        found[e.name]?.hosts.add(host);
      }
    }
  }

  // Code patterns.
  for (final (e, regex) in _compiled) {
    if (found[e.name]?.inSource == true && found[e.name]!.version != null) {
      continue;
    }
    for (final m in regex.allMatches(html)) {
      final ctx = source.at(m.start);
      if (ctx == _Ctx.skip || (ctx == _Ctx.comment && !e.category.tech)) {
        continue;
      }
      record(e, m.start, m[0]!, ctx);
      if (m.groupCount > 0 && m[1] != null) found[e.name]?.version ??= m[1];
      break;
    }
  }

  return found.values.toList();
}

/// Every URL a page loads: metadata links plus the browser's resource
/// timeline entries (maps with a `name`).
List<String> collectResourceUrls(
    Map<String, dynamic>? metadata, Iterable<Map<String, dynamic>> timeline) {
  final urls = <String>[];

  void add(dynamic value) {
    final raw =
        value is Map ? value['src'] ?? value['href'] ?? value['name'] : value;
    if (raw is String && raw.isNotEmpty) urls.add(raw);
  }

  if (metadata != null) {
    for (final key in [
      'jsLinks',
      'externalJsLinks',
      'cssLinks',
      'externalCssLinks',
      'iframeLinks',
      'externalIframeLinks',
    ]) {
      final list = metadata[key];
      if (list is List) list.forEach(add);
    }
    final media = metadata['media'];
    if (media is Map) {
      for (final key in ['images', 'videos']) {
        final list = media[key];
        if (list is List) list.forEach(add);
      }
    }
  }
  timeline.forEach(add);
  return urls;
}

/// The page only sees first-party cookies, so a generic name such as "token"
/// or "A" is the site's own cookie, not the ad network's cookie of that name.
/// Names with a separator (`_ga`-style, `cto_bundle`) are distinctive.
bool isDistinctiveCookieName(String name) =>
    name.length >= 4 && RegExp(r'[_.\-]').hasMatch(name);

const _cookieCategories = {
  'analytics': DetectionCategory.analytics,
  'advertising': DetectionCategory.advertising,
  'social': DetectionCategory.social,
};

/// All detections for a page: [source] (from [scanSource], or scanned here
/// from [html]) plus [requests] and analyzed [cookies].
List<Detection> detect({
  String pageUrl = '',
  String html = '',
  Map<String, String>? headers,
  List<Detection>? source,
  Iterable<String> requests = const [],
  Iterable<Map> cookies = const [],
}) {
  final pageHost = _hostOf(pageUrl);
  // The service the inspected site itself belongs to (Instagram on
  // instagram.com) is first party, not a third-party service.
  final own = pageHost.isEmpty ? null : entityForHost(pageHost);
  final found = <String, Detection>{
    for (final d
        in source ?? scanSource(html: html, headers: headers, pageUrl: pageUrl))
      d.name: d,
  };
  Detection hit(Entity e) => found.putIfAbsent(e.name, () => Detection(e));

  for (final url in requests.toSet()) {
    final host = _hostOf(url);
    if (host.isEmpty) continue;
    for (final e in _entitiesForUrl(url, host, pageHost)) {
      final index = html.isEmpty ? -1 : html.indexOf(url);
      final ping = e.beacons.any((b) => RegExp(b).hasMatch(url));
      final d = hit(e)
        ..requests += 1
        ..pings += ping ? 1 : 0
        ..hosts.add(host)
        ..evidence.removeWhere((x) => x.kind == EvidenceKind.hint);
      final item = DetectionEvidence(EvidenceKind.request,
          ping ? 'Pageview ping to $host' : 'Request to $host',
          detail: url,
          line: index < 0 ? null : DetectionEvidence.htmlAt(html, index).line);
      // The ping is the reason this service is listed, so show it first.
      ping ? d.evidence.insert(0, item) : d.add(item);
    }
  }

  for (final cookie in cookies) {
    final name = cookie['name']?.toString() ?? '';
    if (name.isEmpty) continue;
    final domain = (cookie['domain']?.toString() ?? '')
        .replaceFirst(RegExp(r'^\.'), '')
        .toLowerCase();
    var e = entityForCookie(name);
    if (e == null && domain.isNotEmpty && !_sameSite(domain, pageHost)) {
      e = entityForHost(domain);
    }
    final category = _cookieCategories[cookie['category']];
    final provider = cookie['provider']?.toString() ?? '';
    if (e == null &&
        category != null &&
        provider.isNotEmpty &&
        isDistinctiveCookieName(name)) {
      e = entityNamed(provider) ?? Entity(provider, category);
    }
    if (e == null) continue;
    hit(e)
      ..cookies.add(name)
      ..evidence.removeWhere((x) => x.kind == EvidenceKind.hint)
      ..add(DetectionEvidence.cookie(cookie));
  }

  final names = found.keys.toSet();
  final result = found.values
      .where((d) =>
          (d.entity.parent == null || names.contains(d.entity.parent)) &&
          (d.entity != own ||
              d.category.tech ||
              d.evidence.any((x) => x.kind == EvidenceKind.header)))
      .toList()
    ..sort((a, b) {
      final byWeight = b.category.tracking.compareTo(a.category.tracking);
      if (byWeight != 0) return byWeight;
      final byCategory = a.category.index.compareTo(b.category.index);
      if (byCategory != 0) return byCategory;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return result;
}

/// Non-tracking third parties that see the visit: services the browser
/// loads files from (fonts, cloud, payments, consent) and the CDN, proxy or
/// host serving the site itself (seen in its response headers). They still
/// receive the visitor's IP address and the page being visited.
List<Detection> seesVisit(Iterable<Detection> detections) => [
      for (final d in detections)
        if (!d.category.isTracking &&
            !d.hintOnly &&
            (d.category == DetectionCategory.cdn ||
                d.category == DetectionCategory.platform ||
                d.category == DetectionCategory.storage ||
                (!d.category.tech && d.hosts.isNotEmpty)))
          d
    ]..sort((a, b) {
        final byPings = b.pings.compareTo(a.pings);
        return byPings != 0 ? byPings : a.name.compareTo(b.name);
      });

/// Third-party services as `{category label: names}`.
Map<String, List<String>> servicesByCategory(Iterable<Detection> detections) {
  final services = <String, List<String>>{};
  for (final d in detections.where((d) =>
      !d.category.tech ||
      d.category == DetectionCategory.cdn ||
      d.category == DetectionCategory.platform)) {
    services.putIfAbsent(d.category.label, () => []).add(d.name);
  }
  return services;
}
