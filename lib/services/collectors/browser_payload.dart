import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';

const _crossOriginZero = 'cross-origin resource without Timing-Allow-Origin';
const _localPage = 'resource sizes not measurable for local pages';
const _sameOriginZero =
    'reported 0 bytes; may be unmeasured (service worker / redirect)';

Present<T> _measured<T>(T v) => Present<T>(v, source: DataSource.browser);

/// Parses the JSON string returned by `__vsv_collect()`.
///
/// A non-String result (some Windows/Linux WebViews) gives sections that are
/// [Unavailable] (unsupportedPlatform); an unparsable string gives [Failed].
/// Never empty lists that look like "nothing found".
BrowserSnapshot _parsePayloadInIsolate(
    (String, BrowserPlatform, Uri) args) {
  return parseBrowserPayload(args.$1, args.$2, pageUrl: args.$3);
}

/// Parses the collector payload off the UI thread: the payload carries the
/// whole rendered DOM as one JSON string, so decoding it on the main isolate
/// blocks rendering while a page loads. Non-String answers are small and
/// parse directly.
Future<BrowserSnapshot> parseBrowserPayloadAsync(Object? raw,
    BrowserPlatform platform,
    {required Uri pageUrl}) async {
  if (raw is! String) {
    return parseBrowserPayload(raw, platform, pageUrl: pageUrl);
  }
  return compute(_parsePayloadInIsolate, (raw, platform, pageUrl));
}

BrowserSnapshot parseBrowserPayload(Object? raw, BrowserPlatform platform,
    {required Uri pageUrl}) {
  if (raw is! String) {
    return BrowserSnapshot.unavailable(
      pageUrl,
      platform,
      UnavailableReason.unsupportedPlatform,
      'evaluateJavascript returned ${raw == null ? 'null' : raw.runtimeType}, not a String',
    );
  }
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
    // Some platforms return the JSON string quoted once more.
    if (decoded is String) decoded = jsonDecode(decoded);
  } catch (e) {
    return BrowserSnapshot.failed(pageUrl, platform, 'Unparsable payload: $e',
        rawPayload: raw);
  }
  if (decoded is! Map) {
    return BrowserSnapshot.failed(pageUrl, platform, 'Payload is not an object',
        rawPayload: raw);
  }
  final p = decoded.cast<String, dynamic>();
  if (p['fatal'] != null) {
    return BrowserSnapshot.failed(pageUrl, platform, '${p['fatal']}',
        rawPayload: raw);
  }

  final ct = p['contentType'];
  final contentType = ct is String && ct.isNotEmpty
      ? _measured(ct)
      : const Unavailable<String>(UnavailableReason.notReportedByPlatform,
          'document.contentType empty');
  final ctString = ct is String ? ct : '';

  // The payload url is where the page ended up (redirects, pushState); the
  // caller's pageUrl may be stale. Sizes are judged against the payload url.
  final pu = p['url'];
  final effectiveUrl =
      (pu is String && pu.isNotEmpty ? Uri.tryParse(pu) : null) ?? pageUrl;

  var dropped = 0;
  final rs = p['resources'];
  if (rs is Map && rs['ok'] == true) {
    for (final k in const ['dropped', 'patchDropped']) {
      final d = rs[k];
      if (d is num && d > 0) dropped += d.toInt();
    }
  }

  return BrowserSnapshot(
    url: pageUrl,
    platform: platform,
    contentType: contentType,
    // A collect with {dom: false} reports the section as skipped: the DOM of
    // the last full collect stays (the merge keeps a Present over this).
    renderedDom: p['dom'] is Map && p['dom']['skipped'] == true
        ? const Unavailable<RenderedDom>(
            UnavailableReason.notReportedByPlatform, 'dom skipped in this collect')
        : _section(p['dom'], (m) => _parseDom(m, ctString)),
    resources: _section(
        p['resources'], (m) => _parseResources(m, platform, effectiveUrl)),
    resourcesTruncated: dropped > 0,
    resourcesDropped: dropped,
    cookies: _section(p['cookies'], _parseJsCookies),
    storage: _parseStorage(p['storage']),
    navigation: _section(p['navigation'], (m) => _parseNavigation(m)),
    snapshotTimeMs: _section(p['timing'], (m) {
      final n = m['now'];
      if (n is! num) throw const FormatException('timing.now missing');
      return _measured(n.toDouble()).value;
    }),
    rawPayload: raw,
  );
}

Observed<T> _section<T>(Object? sec, T Function(Map<String, dynamic>) parse) {
  if (sec == null) {
    return Unavailable<T>(UnavailableReason.notReportedByPlatform,
        'section missing from payload');
  }
  if (sec is! Map) return Failed<T>('section is not an object');
  final m = sec.cast<String, dynamic>();
  if (m['ok'] != true) return Failed<T>('${m['error'] ?? 'unknown error'}');
  try {
    return _measured<T>(parse(m));
  } on _Unmeasured {
    return Unavailable<T>(UnavailableReason.notReportedByPlatform,
        'no resource observer and an empty performance buffer; nothing measured');
  } catch (e) {
    return Failed<T>('$e');
  }
}

// ---- DOM -----------------------------------------------------------------

bool _isRawTextDocument(String contentType) {
  final ct = contentType.split(';').first.trim().toLowerCase();
  if (ct.isEmpty || ct.contains('html') || ct.contains('xml')) return false;
  return ct.startsWith('text/') ||
      ct == 'application/json' ||
      ct.endsWith('+json') ||
      ct == 'application/javascript' ||
      ct == 'application/x-javascript';
}

RenderedDom _parseDom(Map<String, dynamic> m, String contentType) {
  final value = m['value'];
  if (value is! String) {
    throw FormatException('dom.value is ${value.runtimeType}, not a String');
  }
  final rawText = m['raw'];
  final unwrap = _isRawTextDocument(contentType) && rawText is String;
  return RenderedDom(
    text: unwrap ? rawText : value,
    unwrappedRawDocument: unwrap,
    iframeCount: (m['iframes'] as num?)?.toInt() ?? 0,
    shadowRootCount: (m['shadowRoots'] as num?)?.toInt() ?? 0,
  );
}

// ---- Resources -----------------------------------------------------------

String? _absoluteUrl(Object? name, Uri pageUrl) {
  if (name is! String || name.isEmpty) return null;
  try {
    final u = pageUrl.resolve(name);
    if (u.scheme == 'data' || u.scheme == 'blob') return null;
    return u.removeFragment().toString();
  } catch (_) {
    return null;
  }
}

bool _sameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;

bool _isImage(String type, String url) {
  if (type == 'img' || type == 'image') return true;
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  return RegExp(r'\.(png|jpe?g|gif|webp|avif|bmp|ico|svg)$').hasMatch(path);
}

Observed<double> _time(Object? v) => v is num
    ? _measured(v.toDouble())
    : const Unavailable<double>(UnavailableReason.notReportedByPlatform);

const _noOwnSizes =
    Unavailable<int>(UnavailableReason.notReportedByPlatform, _localPage);

bool _isWebPage(Uri u) => u.scheme == 'http' || u.scheme == 'https';

List<ResourceEntry> _parseResources(
    Map<String, dynamic> m, BrowserPlatform platform, Uri pageUrl) {
  final observed = m['observer'] as List? ?? const [];
  if (m['bootstrap'] != true && observed.isEmpty) {
    // No observer and an empty buffer: we never measured anything.
    throw const _Unmeasured();
  }
  final byUrl = <String, ResourceEntry>{};
  for (final e in observed) {
    if (e is! Map) continue;
    final url = _absoluteUrl(e['n'], pageUrl);
    if (url == null) continue;
    final entry = _observerEntry(e, url, platform, pageUrl);
    final prev = byUrl[url];
    byUrl[url] = prev == null ? entry : mergeResources([prev], [entry]).single;
  }
  // The observer wins over the fetch/XHR patch for the same URL (B13).
  for (final e in (m['patch'] as List? ?? const [])) {
    if (e is! Map) continue;
    final url = _absoluteUrl(e['n'], pageUrl);
    if (url == null) continue;
    final existing = byUrl[url];
    if (existing != null && existing.source == ResourceSource.observer) {
      continue;
    }
    final cl = e['cl'];
    final local = !_isWebPage(pageUrl);
    final entry = ResourceEntry(
      url: url,
      type: '${e['it'] ?? 'fetch'}',
      source: ResourceSource.patch,
      startTime: _time(e['st']),
      duration: const Unavailable(UnavailableReason.notReportedByPlatform,
          'fetch/XHR patch does not measure duration'),
      transfer: local
          ? _noOwnSizes
          : cl is num && cl > 0
              ? _measured(cl.toInt())
              : const Unavailable(UnavailableReason.notExposedToPage,
                  'no content-length header'),
      decoded: local
          ? _noOwnSizes
          : const Unavailable(UnavailableReason.notReportedByPlatform,
              'content-length is the compressed size'),
    );
    byUrl[url] =
        existing == null ? entry : mergeResources([existing], [entry]).single;
  }
  // Images on screen that no timing entry covers: loaded, but unmeasured.
  if (_isWebPage(pageUrl)) {
    for (final e in (m['shown'] as List? ?? const [])) {
      final url = _absoluteUrl(e, pageUrl);
      if (url == null || byUrl.containsKey(url)) continue;
      byUrl[url] = ResourceEntry(
        url: url,
        type: 'img',
        source: ResourceSource.shownImage,
        startTime: const Unavailable(UnavailableReason.notReportedByPlatform,
            _shownImageDetail),
        duration: const Unavailable(UnavailableReason.notReportedByPlatform,
            _shownImageDetail),
        transfer: const Unavailable(UnavailableReason.notReportedByPlatform,
            _shownImageDetail),
        decoded: const Unavailable(UnavailableReason.notReportedByPlatform,
            _shownImageDetail),
      );
    }
  }
  // URLs the collector's buffer dropped (lazy images and ads that loaded
  // after a flood of unique tracker URLs): listed without sizes, so the app
  // can still size them with its own request.
  for (final e in (m['droppedNames'] as List? ?? const [])) {
    if (e is! Map) continue;
    final url = _absoluteUrl(e['n'], pageUrl);
    if (url == null || byUrl.containsKey(url)) continue;
    final fo = e['fo'];
    byUrl[url] = ResourceEntry(
      url: url,
      type: '${e['it'] ?? ''}',
      source: ResourceSource.dropped,
      startTime: const Unavailable(
          UnavailableReason.notReportedByPlatform, _droppedDetail),
      duration: const Unavailable(
          UnavailableReason.notReportedByPlatform, _droppedDetail),
      transfer: _isWebPage(pageUrl)
          ? const Unavailable(
              UnavailableReason.notReportedByPlatform, _droppedDetail)
          : _noOwnSizes,
      decoded: _isWebPage(pageUrl)
          ? const Unavailable(
              UnavailableReason.notReportedByPlatform, _droppedDetail)
          : _noOwnSizes,
      frameOrigin: fo is String && fo.isNotEmpty ? fo : null,
    );
  }
  return byUrl.values.toList();
}

const _shownImageDetail = 'shown on the page, but the browser reported no '
    'timing for it (likely served from its memory cache)';

const _droppedDetail = 'not collected: the collector buffer was full';

ResourceEntry _observerEntry(
    Map e, String url, BrowserPlatform platform, Uri pageUrl) {
  // null = the browser did not report the field (never coerced to 0).
  int? n(Object? v) => v is num ? v.toInt() : null;
  final tx = n(e['tx']), enc = n(e['enc']), dec = n(e['dec']);
  final type = '${e['it'] ?? ''}';
  const missing = Unavailable<int>(UnavailableReason.notReportedByPlatform,
      'field not reported by this browser');

  Observed<int> transfer;
  Observed<int> decoded;
  var fromCache = false;
  final allZero = tx == 0 && enc == 0 && dec == 0;
  if (!_isWebPage(pageUrl)) {
    transfer = _noOwnSizes;
    decoded = _noOwnSizes;
  } else if (allZero && !_sameOrigin(Uri.parse(url), pageUrl)) {
    transfer = const Unavailable(
        UnavailableReason.blockedByPlatform, _crossOriginZero);
    decoded = const Unavailable(
        UnavailableReason.blockedByPlatform, _crossOriginZero);
  } else if (allZero) {
    transfer = const Unavailable(
        UnavailableReason.notReportedByPlatform, _sameOriginZero);
    decoded = const Unavailable(
        UnavailableReason.notReportedByPlatform, _sameOriginZero);
  } else {
    if (tx == null) {
      transfer = missing;
    } else if (tx == 0 && ((dec ?? 0) > 0 || (enc ?? 0) > 0)) {
      // A cache hit downloads nothing now; a fresh load downloads the
      // encoded body, so that is its download size (without headers).
      fromCache = true;
      transfer = (enc ?? 0) > 0
          ? Present(enc!,
              source: DataSource.browser, provenance: Provenance.derived)
          : const Unavailable(UnavailableReason.servedFromCache,
              'transferSize is 0 for a cached response, no encoded size');
    } else {
      transfer = _measured(tx);
    }
    if (dec == null) {
      decoded = missing;
    } else if (platform.isWebKit && _isImage(type, url)) {
      decoded = const Unavailable(UnavailableReason.notReportedByPlatform,
          'WebKit reports decoded image pixel buffer');
    } else {
      decoded = _measured(dec);
    }
  }
  return ResourceEntry(
    url: url,
    type: type,
    source: ResourceSource.observer,
    startTime: _time(e['st']),
    duration: _time(e['du']),
    transfer: transfer,
    decoded: decoded,
    fromCache: fromCache,
    frameOrigin: e['fr'] == 1 ? '${e['fo'] ?? ''}' : null,
  );
}

Observed<T> _prefer<T>(Observed<T> fresh, Observed<T> old) {
  if (fresh is Present<T>) return fresh;
  if (old is Present<T>) return old;
  return fresh;
}

/// Value equality of two resource entries (no `==` on the class itself, so
/// merges can stay identity-stable when nothing changed).
bool resourceEntriesEqual(ResourceEntry a, ResourceEntry b) =>
    a.url == b.url &&
    a.type == b.type &&
    a.source == b.source &&
    a.fromCache == b.fromCache &&
    a.frameOrigin == b.frameOrigin &&
    sameObserved(a.startTime, b.startTime) &&
    sameObserved(a.duration, b.duration) &&
    sameObserved(a.transfer, b.transfer) &&
    sameObserved(a.decoded, b.decoded);

/// Union by absolute URL. Fresh values win only where they are [Present]; a
/// Present value is never replaced by an Unavailable (B11/B12). An observer
/// entry is never replaced by a patch entry. When nothing actually changed,
/// [old] itself is returned, so callers can detect "no news" by identity.
List<ResourceEntry> mergeResources(
    List<ResourceEntry> old, List<ResourceEntry> fresh) {
  final byUrl = <String, ResourceEntry>{for (final e in old) e.url: e};
  var changed = false;
  for (final f in fresh) {
    final o = byUrl[f.url];
    if (o == null) {
      byUrl[f.url] = f;
      changed = true;
    } else if (f.source == ResourceSource.dropped &&
        o.source != ResourceSource.dropped) {
      // A dropped placeholder never replaces a real entry.
      continue;
    } else if ((o.source == ResourceSource.observer &&
            f.source == ResourceSource.patch) ||
        // A shown image never replaces a measured entry.
        (f.source == ResourceSource.shownImage &&
            o.source != ResourceSource.shownImage)) {
      continue;
    } else {
      final merged = ResourceEntry(
        url: f.url,
        type: f.type.isEmpty ? o.type : f.type,
        source: f.source,
        startTime: _prefer(f.startTime, o.startTime),
        duration: _prefer(f.duration, o.duration),
        transfer: _prefer(f.transfer, o.transfer),
        decoded: _prefer(f.decoded, o.decoded),
        // Follows the transfer value that was kept.
        fromCache: f.transfer is Present<int> || o.transfer is! Present<int>
            ? f.fromCache
            : o.fromCache,
        // The first report of where it was loaded stays.
        frameOrigin: o.frameOrigin ?? f.frameOrigin,
      );
      if (resourceEntriesEqual(merged, o)) continue;
      byUrl[f.url] = merged;
      changed = true;
    }
  }
  return changed ? byUrl.values.toList() : old;
}

// ---- Navigation ----------------------------------------------------------

NavigationTiming _parseNavigation(Map<String, dynamic> m) {
  Observed<double> t(Object? v) {
    if (v is! num) {
      return const Unavailable(UnavailableReason.notReportedByPlatform);
    }
    // 0 means the milestone has not happened yet (or is not reported).
    return v > 0 ? _measured(v.toDouble()) : const Pending();
  }

  final proto = m['protocol'];
  return NavigationTiming(
    timeToFirstByte: t(m['responseStart']),
    domInteractive: t(m['domInteractive']),
    domContentLoaded: t(m['domContentLoaded']),
    loadEvent: t(m['loadEnd']),
    protocol: proto is String && proto.isNotEmpty
        ? _measured(proto)
        : const Unavailable(UnavailableReason.notReportedByPlatform),
  );
}

// ---- Storage -------------------------------------------------------------

Observed<BrowserStorage> _parseStorage(Object? sec) {
  if (sec == null) {
    return const Unavailable(UnavailableReason.notReportedByPlatform,
        'section missing from payload');
  }
  if (sec is! Map) return const Failed('section is not an object');
  return _measured(BrowserStorage(
    local: _parseArea(sec['local']),
    session: _parseArea(sec['session']),
  ));
}

Observed<StorageArea> _parseArea(Object? a) {
  if (a is! Map) return const Failed('storage area missing');
  if (a['ok'] != true) return Failed('${a['error'] ?? 'unknown error'}');
  try {
    final items = <StorageItem>[];
    var bytes = 0;
    for (final i in (a['items'] as List? ?? const [])) {
      final k = '${i['k']}', v = '${i['v'] ?? ''}';
      final b = utf8.encode(k).length + utf8.encode(v).length;
      bytes += b;
      items.add(StorageItem(k, b));
    }
    items.sort((x, y) => y.bytes.compareTo(x.bytes));
    final truncated = a['truncated'] == true;
    return _measured(StorageArea(
      count: (a['count'] as num?)?.toInt() ?? items.length,
      bytes: truncated
          ? const Unavailable(UnavailableReason.exceedsLimit,
              'only the first items were sent; total size not known')
          : _measured(bytes),
      topItems: items.take(10).toList(),
    ));
  } catch (e) {
    return Failed('$e');
  }
}

// ---- Cookies -------------------------------------------------------------

/// Thrown inside the resources section when nothing was ever measured.
class _Unmeasured implements Exception {
  const _Unmeasured();
}

/// Cookies from `document.cookie`: name=value only.
List<BrowserCookie> _parseJsCookies(Map<String, dynamic> m) {
  const detail = 'document.cookie exposes name=value only';
  const na = UnavailableReason.notExposedToPage;
  final raw = m['raw'];
  if (raw is! String) throw const FormatException('cookies.raw missing');
  final out = <BrowserCookie>[];
  for (final part in raw.split(';')) {
    final s = part.trim();
    if (s.isEmpty) continue;
    final eq = s.indexOf('=');
    out.add(BrowserCookie(
      name: eq < 0 ? s : s.substring(0, eq),
      value: eq < 0 ? '' : s.substring(eq + 1),
      domain: const Unavailable(na, detail),
      path: const Unavailable(na, detail),
      expires: const Unavailable(na, detail),
      isSecure: const Unavailable(na, detail),
      isHttpOnly: const Unavailable(na, 'HttpOnly cookies are invisible to JS'),
      sameSite: const Unavailable(na, detail),
    ));
  }
  return out;
}

/// Cookies from the native cookie manager, in the shape of flutter_inappwebview
/// `Cookie.toMap()`. A missing or null flag is [Unavailable], never `false`.
List<BrowserCookie> parseNativeCookies(
    List<Map> raw, BrowserPlatform platform) {
  final missing = platform == BrowserPlatform.android
      ? 'Android CookieManager reports name=value only'
      : 'not reported by the cookie manager';

  Observed<T> field<T>(Map c, String key, T? Function(Object?) conv) {
    final v = c.containsKey(key) ? c[key] : null;
    final r = v == null ? null : conv(v);
    return r == null
        ? Unavailable<T>(UnavailableReason.notExposedToPage, missing)
        : _measured<T>(r);
  }

  String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
  bool? flag(Object? v) => v is bool ? v : null;

  return [
    for (final c in raw)
      BrowserCookie(
        name: '${c['name']}',
        value: '${c['value'] ?? ''}',
        domain: field<String>(c, 'domain', str),
        path: field<String>(c, 'path', str),
        expires: !c.containsKey('expiresDate')
            ? Unavailable<DateTime>(UnavailableReason.notExposedToPage, missing)
            : c['expiresDate'] == null
                ? !platform.isWebKit
                    // Android etc. always include the key, null = unknown.
                    ? Unavailable<DateTime>(
                        UnavailableReason.notExposedToPage, missing)
                    : const Unavailable<DateTime>(
                        UnavailableReason.notApplicable, 'session cookie')
                : c['expiresDate'] is num
                    ? _measured(DateTime.fromMillisecondsSinceEpoch(
                        (c['expiresDate'] as num).toInt(),
                        isUtc: true))
                    : Unavailable<DateTime>(
                        UnavailableReason.notExposedToPage, missing),
        isSecure: field<bool>(c, 'isSecure', flag),
        isHttpOnly: field<bool>(c, 'isHttpOnly', flag),
        sameSite: field<String>(c, 'sameSite', (v) => str('$v')),
      ),
  ];
}
