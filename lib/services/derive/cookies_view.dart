import 'dart:convert';

import 'package:material_ui/material_ui.dart' show IconData, Icons;

import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../../utils/cookie_utils.dart';
import 'cookies.dart';
import 'header_insights.dart' show InsightTone;
import 'observed_text.dart';
import 'probe_general.dart' show probeGate;
import 'score_band.dart';

/// One cookie as the Cookies tab shows it. Flags are "yes", "no" or
/// "unknown": a flag the platform did not expose is never "no".
class CookieRow {
  final String name;

  /// Shown in the app and copied on request; never exported.
  final String value;
  final int valueBytes;
  final String category;
  final String? provider;

  /// "Server", "Browser" or "Server + Browser".
  final String source;
  final String secure;
  final String httpOnly;
  final String sameSite;
  final String domain;
  final String path;
  final String expires;

  final bool thirdPartyish;
  final bool weakSameSite;
  final bool missingSecure;

  const CookieRow({
    required this.name,
    required this.value,
    required this.valueBytes,
    required this.category,
    required this.provider,
    required this.source,
    required this.secure,
    required this.httpOnly,
    required this.sameSite,
    required this.domain,
    required this.path,
    required this.expires,
    required this.thirdPartyish,
    required this.weakSameSite,
    required this.missingSecure,
  });

  String get flagsLine =>
      'Secure: $secure · HttpOnly: $httpOnly · SameSite: $sameSite';
  String get scopeLine => 'Domain: $domain · Path: $path · Expires: $expires';
}

class CookieChip {
  final IconData icon;
  final String label;
  final InsightTone tone;
  const CookieChip(this.icon, this.label, this.tone);
}

class CookieNote {
  final IconData icon;
  final InsightTone tone;
  final String text;
  const CookieNote(this.icon, this.tone, this.text);
}

class CookiesModel {
  final List<CookieRow> rows;

  /// True when both the server's Set-Cookie headers and the browser's
  /// cookies were read.
  final bool complete;

  /// Which sources are missing and why; null when [complete].
  final String? sourcesNote;

  /// Privacy score of the cookies seen, null when it cannot be judged (no
  /// cookie and a source is unknown).
  final int? score;
  final String verdict;
  final int total;
  final int analyticsCount;
  final int advertisingCount;
  final int socialCount;
  final int uncategorizedCount;
  final int secureCount;
  final int unknownSecureCount;
  final int httpOnlyCount;
  final int unknownHttpOnlyCount;
  final List<CookieChip> chips;
  final List<CookieNote> notes;

  const CookiesModel({
    required this.rows,
    required this.complete,
    required this.sourcesNote,
    required this.score,
    required this.verdict,
    required this.total,
    required this.analyticsCount,
    required this.advertisingCount,
    required this.socialCount,
    required this.uncategorizedCount,
    required this.secureCount,
    required this.unknownSecureCount,
    required this.httpOnlyCount,
    required this.unknownHttpOnlyCount,
    required this.chips,
    required this.notes,
  });
}

String _flag(bool? v) => v == null ? 'unknown' : (v ? 'yes' : 'no');

String? _bare(String? d) {
  if (d == null || d.isEmpty) return null;
  final l = d.toLowerCase();
  return l.startsWith('.') ? l.substring(1) : l;
}

bool _related(String a, String b) =>
    a == b || a.endsWith('.$b') || b.endsWith('.$a');

/// The page's final URL: server's when known, else the browser's.
Uri? _pageUrl(PageInspection p) {
  final s = p.server;
  if (s is Present<ServerSnapshot>) {
    final f = s.value.finalUrl;
    if (f is Present<Uri>) return f.value;
  }
  final b = p.browser;
  return b is Present<BrowserSnapshot> ? b.value.url : null;
}

CookieRow _row(CookieInfo c, Uri? page, DateTime now) {
  final fromServer = c.source.contains('Server');
  final category = c.category.name;
  final sameSiteLower = c.sameSite?.toLowerCase();
  // A missing SameSite defaults to Lax in browsers; only None is weak.
  final weak = sameSiteLower == 'none';
  final https = page?.scheme == 'https';
  final missingSecure =
      https && (fromServer ? c.secure != true : c.secure == false);
  final host = page?.host.toLowerCase();
  final cookieHost = _bare(c.domain ?? c.requestHost);
  final thirdParty = host != null &&
      host.isNotEmpty &&
      cookieHost != null &&
      !_related(cookieHost, host);
  var expires = c.expires ?? (fromServer ? 'session' : 'unknown');
  final exp = DateTime.tryParse(expires);
  if (exp != null && exp.isBefore(now)) expires = '$expires (expired)';
  return CookieRow(
    name: c.name,
    value: c.value,
    valueBytes: utf8.encode(c.value).length,
    category: category,
    provider: c.provider,
    source: c.source,
    secure: _flag(c.secure),
    httpOnly: _flag(c.httpOnly),
    sameSite: c.sameSite != null && c.sameSite!.isNotEmpty
        ? c.sameSite!
        : (fromServer ? 'not set (Lax by default)' : 'unknown'),
    domain: c.domain ??
        (c.requestHost != null ? '${c.requestHost} (host-only)' : 'unknown'),
    path: c.path ?? (fromServer ? 'default' : 'unknown'),
    expires: expires,
    thirdPartyish: thirdParty,
    weakSameSite: weak,
    missingSecure: missingSecure,
  );
}

int _compare(CookieRow a, CookieRow b) {
  final aKnown = a.category != 'unknown';
  final bKnown = b.category != 'unknown';
  if (aKnown != bKnown) return aKnown ? -1 : 1;
  if (aKnown) {
    final pa = (a.provider ?? '').toLowerCase();
    final pb = (b.provider ?? '').toLowerCase();
    if (pa != pb) return pa.compareTo(pb);
  }
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// The Cookies tab: the derived cookies (server Set-Cookie per hop merged
/// with the browser's) and a privacy lens over what is known about them.
Observed<CookiesModel> deriveCookiesView(PageInspection p, {DateTime? now}) {
  final gate = probeGate<CookiesModel>(p);
  if (gate != null) return gate;

  final server = p.server;
  final browser = p.browser;
  final Observed<List<BrowserCookie>> browserCookies =
      browser is Present<BrowserSnapshot>
          ? browser.value.cookies
          : notPresentAs(browser);
  final serverOk = server is Present<ServerSnapshot>;
  final browserOk = browserCookies is Present<List<BrowserCookie>>;

  if (!serverOk && !browserOk) {
    if (server is Failed<ServerSnapshot>) {
      return Failed(server.error);
    }
    if (browserCookies is Failed<List<BrowserCookie>>) {
      return Failed(browserCookies.error);
    }
    if (server is Pending<ServerSnapshot> ||
        browserCookies is Pending<List<BrowserCookie>>) {
      return const Pending();
    }
    return Unavailable(
        UnavailableReason.notApplicable,
        'No cookie source: server ${notPresentText(server)}; '
        'browser ${notPresentText(browserCookies)}');
  }

  final missing = [
    if (!serverOk) 'server Set-Cookie headers: ${unknownText(server)}',
    if (!browserOk) 'browser cookies: ${unknownText(browserCookies)}',
  ];
  final complete = missing.isEmpty;

  final page = _pageUrl(p);
  final clock = (now ?? DateTime.now()).toUtc();
  final rows = deriveCookies(p, now: now)
      .map((c) => _row(c, page, clock))
      .toList()
    ..sort(_compare);
  int count(bool Function(CookieRow) f) => rows.where(f).length;
  final analytics = count((r) => r.category == 'analytics');
  final advertising = count((r) => r.category == 'advertising');
  final social = count((r) => r.category == 'social');
  final uncategorized = count((r) => r.category == 'unknown');
  final secure = count((r) => r.secure == 'yes');
  final unknownSecure = count((r) => r.secure == 'unknown');
  final httpOnly = count((r) => r.httpOnly == 'yes');
  final unknownHttpOnly = count((r) => r.httpOnly == 'unknown');
  final thirdParty = count((r) => r.thirdPartyish);
  final weak = count((r) => r.weakSameSite);
  final notSecure = count((r) => r.missingSecure);

  // Only with every source read: cookies set later by JavaScript are not in
  // the Set-Cookie headers, and the server's cookies are not all the browser
  // holds, so a half-read list says too little to judge.
  int? score;
  if (complete) {
    score = (100 -
            advertising * 12 -
            analytics * 7 -
            social * 6 -
            uncategorized * 3 -
            thirdParty * 6 -
            weak * 5 -
            notSecure * 2)
        .clamp(0, 100);
  }
  final verdict = score == null
      ? 'No score: not enough data (not all cookie sources could be read).'
      : switch (cookieScale.band(score)!) {
          ScoreBand.good => 'Low visible tracking pressure from cookies.',
          ScoreBand.fair => 'Moderate cookie tracking signals detected.',
          ScoreBand.poor =>
            'Heavy tracking or weak cookie boundaries detected.',
        };

  final notes = <CookieNote>[
    if (advertising > 0)
      CookieNote(Icons.ad_units_outlined, InsightTone.warn,
          '${_plural(advertising, 'advertising cookie')} can support cross-site profiling.'),
    if (analytics > 0)
      CookieNote(Icons.analytics_outlined, InsightTone.info,
          '${_plural(analytics, 'analytics cookie')} can measure repeat visits.'),
    if (weak > 0)
      CookieNote(Icons.open_in_new, InsightTone.bad,
          '${_plural(weak, 'cookie')} use SameSite=None (sent on cross-site requests).'),
    if (notSecure > 0)
      CookieNote(Icons.lock_open, InsightTone.bad,
          '${_plural(notSecure, 'cookie')} not marked Secure.'),
    if (httpOnly > 0)
      CookieNote(Icons.shield_outlined, InsightTone.good,
          '${_plural(httpOnly, 'cookie')} protected from JavaScript access.'),
    if (unknownSecure > 0 || unknownHttpOnly > 0)
      CookieNote(
          Icons.help_outline,
          InsightTone.neutral,
          'Secure/HttpOnly flags are unknown for '
          '${_plural(rows.where((r) => r.secure == 'unknown' || r.httpOnly == 'unknown').length, 'cookie')} '
          '(the platform does not expose them).'),
  ];
  if (notes.isEmpty && rows.isNotEmpty) {
    notes.add(const CookieNote(Icons.check_circle_outline, InsightTone.good,
        'No obvious cookie privacy issues detected.'));
  }

  return Present(
      CookiesModel(
        rows: rows,
        complete: complete,
        sourcesNote: complete
            ? null
            : 'Cookies seen so far only. Unknown: ${missing.join('; ')}.',
        score: score,
        verdict: verdict,
        total: rows.length,
        analyticsCount: analytics,
        advertisingCount: advertising,
        socialCount: social,
        uncategorizedCount: uncategorized,
        secureCount: secure,
        unknownSecureCount: unknownSecure,
        httpOnlyCount: httpOnly,
        unknownHttpOnlyCount: unknownHttpOnly,
        chips: [
          CookieChip(
              Icons.cookie_outlined, '${rows.length} total', InsightTone.brand),
          if (analytics > 0)
            CookieChip(Icons.analytics_outlined, '$analytics analytics',
                InsightTone.info),
          if (advertising > 0)
            CookieChip(
                Icons.ad_units_outlined, '$advertising ads', InsightTone.warn),
          if (social > 0)
            CookieChip(
                Icons.share_outlined, '$social social', InsightTone.brand),
          if (uncategorized > 0)
            CookieChip(Icons.help_outline, '$uncategorized uncategorized',
                InsightTone.neutral),
          CookieChip(Icons.lock_outline, '$secure secure', InsightTone.good),
          if (unknownSecure > 0)
            CookieChip(Icons.help_outline, '$unknownSecure Secure unknown',
                InsightTone.neutral),
          CookieChip(
              Icons.shield_outlined, '$httpOnly HttpOnly', InsightTone.good),
          if (unknownHttpOnly > 0)
            CookieChip(Icons.help_outline, '$unknownHttpOnly HttpOnly unknown',
                InsightTone.neutral),
          if (thirdParty > 0)
            CookieChip(
                Icons.public, '$thirdParty cross-site-ish', InsightTone.bad),
          if (weak > 0)
            CookieChip(
                Icons.open_in_new, '$weak SameSite=None', InsightTone.bad),
        ],
        notes: notes.take(4).toList(),
      ),
      source: DataSource.server,
      provenance: Provenance.derived);
}
