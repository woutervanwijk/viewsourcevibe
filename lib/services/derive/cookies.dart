import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../../utils/cookie_utils.dart';

String? _bareDomain(String? d) {
  if (d == null || d.isEmpty) return null;
  final lower = d.toLowerCase();
  return lower.startsWith('.') ? lower.substring(1) : lower;
}

/// A cookie is identified by (name, domain, path). A domain or path that is
/// unknown on either side (the platform did not report it) does not tell two
/// cookies apart; a host-only server cookie uses the host it came from.
bool _sameCookie(CookieInfo a, CookieInfo b) {
  if (a.name != b.name) return false;
  final x = _bareDomain(a.domain ?? a.requestHost);
  final y = _bareDomain(b.domain ?? b.requestHost);
  if (x != null && y != null && x != y) return false;
  if (a.path != null && b.path != null && a.path != b.path) return false;
  return true;
}

bool? _anyTrue(bool? a, bool? b) => a == true || b == true ? true : a ?? b;

/// Set-Cookie headers of the server plus the cookies the browser holds.
/// The same cookie seen by both is merged; cookies of the same name on
/// different domains or paths stay separate. [serverCookies] pairs each
/// Set-Cookie line with the host that sent it.
List<CookieInfo> mergeCookies(
  List<({String line, String host})> serverCookies,
  List<BrowserCookie> browserCookies, {
  DateTime? now,
}) {
  final merged = <CookieInfo>[];

  for (final sc in serverCookies) {
    final name = sc.line.split(';')[0].split('=')[0].trim();
    if (name.isEmpty) continue;
    final info =
        CookieUtils.analyze(sc.line, 'Server', now: now, requestHost: sc.host);
    final i = merged.indexWhere((m) => _sameCookie(m, info));
    if (i >= 0) {
      merged[i] = info; // a later Set-Cookie for the same cookie wins
    } else {
      merged.add(info);
    }
  }

  for (final b in browserCookies) {
    if (b.name.isEmpty) continue;
    final bc = CookieUtils.fromBrowser(b);
    final i = merged.indexWhere((m) => _sameCookie(m, bc));
    if (i < 0) {
      merged.add(bc);
      continue;
    }
    final existing = merged[i];
    merged[i] = CookieInfo(
      name: bc.name,
      value: bc.value,
      domain: existing.domain ?? bc.domain,
      path: existing.path ?? bc.path,
      requestHost: existing.requestHost,
      expires: existing.expires ?? bc.expires,
      // WebKit reports a cookie without SameSite as "None"; when the server
      // set it without the attribute, keep "not set" so the cookie reads the
      // same whether or not the browser also saw it.
      sameSite: existing.sameSite ??
          (existing.source == 'Server' && bc.sameSite?.toLowerCase() == 'none'
              ? null
              : bc.sameSite),
      secure: _anyTrue(existing.secure, bc.secure),
      httpOnly: _anyTrue(existing.httpOnly, bc.httpOnly),
      category: existing.category == CookieCategory.unknown
          ? bc.category
          : existing.category,
      provider: existing.provider ?? bc.provider,
      source: 'Server + Browser',
    );
  }
  return merged;
}

/// The cookies of the current inspection: Set-Cookie headers of every
/// server hop (when the server snapshot is Present) merged with the
/// browser's cookies (when Present). Nothing from any other generation.
///
/// Third-party cookies are not collected: the page only sees its own.
List<CookieInfo> deriveCookies(PageInspection p, {DateTime? now}) {
  final server = p.server;
  final browser = p.browser;
  final fromServer = <({String line, String host})>[
    if (server is Present<ServerSnapshot>)
      for (final h in server.value.hops)
        for (final c in h.setCookies) (line: c, host: h.url.host),
  ];
  final fromBrowser = browser is Present<BrowserSnapshot> &&
          browser.value.cookies is Present<List<BrowserCookie>>
      ? (browser.value.cookies as Present<List<BrowserCookie>>).value
      : const <BrowserCookie>[];
  return mergeCookies(fromServer, fromBrowser, now: now);
}

/// A cookie as the maps the widgets and the detection engine read.
/// Unknown flags are left out, never reported as false.
Map<String, dynamic> cookieInfoToMap(CookieInfo c) => {
      'name': c.name,
      'value': c.value,
      if (c.domain != null) 'domain': c.domain,
      if (c.path != null) 'path': c.path,
      if (c.expires != null) 'expires': c.expires,
      if (c.sameSite != null) 'sameSite': c.sameSite,
      if (c.secure != null) 'secure': c.secure,
      if (c.httpOnly != null) 'httpOnly': c.httpOnly,
      'category': c.category.toString().split('.').last,
      'provider': c.provider,
      'source': c.source,
    };
