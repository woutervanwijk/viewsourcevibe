import 'dart:io' show HttpDate;

import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/detection/engine.dart';
import 'package:view_source_vibe/utils/cookie_db.g.dart';
import 'package:view_source_vibe/utils/cookie_overrides.dart';

enum CookieCategory {
  essential,
  analytics,
  advertising,
  social,
  functional,
  unknown,
}

/// A cookie table entry: (category, provider, wildcard). A wildcard entry
/// matches every cookie name that starts with its key.
typedef CookieDbEntry = (CookieCategory, String?, bool);

class CookieInfo {
  final String name;
  final String value;
  final String? domain;
  final CookieCategory category;
  final String? provider;
  final String source; // 'Server' or 'Browser'

  final String? expires;
  final String? sameSite;

  /// The Path attribute / the browser's cookie path; null = unknown.
  final String? path;

  /// For a server cookie: the host the Set-Cookie came from, used to match a
  /// host-only cookie (no Domain attribute) with the browser's copy.
  final String? requestHost;

  /// null = unknown (the browser did not expose the flag); never assumed false.
  final bool? secure;
  final bool? httpOnly;

  CookieInfo({
    required this.name,
    required this.value,
    this.domain,
    required this.category,
    this.provider,
    required this.source,
    this.expires,
    this.sameSite,
    this.secure,
    this.httpOnly,
    this.path,
    this.requestHost,
  });
}

class CookieUtils {
  /// Wildcard keys shorter than this match only the exact name. Short OCD
  /// wildcard rows (SR, CT, P_, tp, _s) would otherwise swallow unrelated
  /// first-party names.
  static const int minWildcardLength = 3;

  /// Wildcard entries (overrides and generated), longest key first so that
  /// the longest matching prefix wins.
  static final List<MapEntry<String, CookieDbEntry>> _wildcards = (() {
    final all = <String, CookieDbEntry>{
      ...generatedCookieDb,
      ...cookieOverrides,
    };
    return all.entries
        .where((e) =>
            (e.value.$3 || forcedWildcard.contains(e.key)) &&
            e.key.length >= minWildcardLength)
        .toList()
      ..sort((a, b) {
        final byLength = b.key.length.compareTo(a.key.length);
        return byLength != 0 ? byLength : a.key.compareTo(b.key);
      });
  })();

  /// Wildcard keys in lookup order (longest first).
  static List<String> get prefixKeysForTest =>
      [for (final e in _wildcards) e.key];

  /// The raw table entry for a cookie name (before analyze() applies the
  /// catalogue and distinctive-name rules): exact name (overrides, then the
  /// generated Open Cookie Database), else the longest wildcard prefix.
  static CookieDbEntry? lookupEntry(String name) {
    var key = name;
    var entry = cookieOverrides[name] ?? generatedCookieDb[name];
    if (entry == null) {
      for (final w in _wildcards) {
        if (name.startsWith(w.key)) {
          key = w.key;
          entry = w.value;
          break;
        }
      }
    }
    if (entry == null) return null;
    final forced = forcedCategory[key];
    return forced == null ? entry : (forced, entry.$2, entry.$3);
  }

  /// Names of consent-manager state cookies (not any name containing
  /// "consent": "consent_ad_id" is an ad id).
  static final RegExp _consentName = RegExp(
      r'^(cookie_?)?consent(_?(mode|status|settings|preferences|state))?$'
      r'|cookieconsent|consentmanager|^cmp',
      caseSensitive: false);

  static const _trackingCategories = {
    CookieCategory.analytics,
    CookieCategory.advertising,
    CookieCategory.social,
  };

  static CookieCategory _categoryOf(DetectionCategory c) => switch (c) {
        DetectionCategory.advertising => CookieCategory.advertising,
        DetectionCategory.social => CookieCategory.social,
        DetectionCategory.analytics ||
        DetectionCategory.behavior ||
        DetectionCategory.marketing =>
          CookieCategory.analytics,
        _ => CookieCategory.functional,
      };

  static CookieInfo analyze(String rawCookie, String source,
      {DateTime? now, String? requestHost}) {
    // Parse name and value, and handle attributes
    final parts = rawCookie.split(';');
    final pair = parts[0].split('=');
    final name = pair[0].trim();
    String value = pair.length > 1 ? pair.sublist(1).join('=') : '';

    String? domain;
    String? expires;
    String? path;
    int? maxAge;
    String? sameSite;
    bool secure = false;
    bool httpOnly = false;

    // Parse attributes
    for (var i = 1; i < parts.length; i++) {
      final attr = parts[i].trim();
      final lowerAttr = attr.toLowerCase();
      final eqIndex = attr.indexOf('=');

      if (lowerAttr.startsWith('domain=')) {
        if (eqIndex != -1) domain = attr.substring(eqIndex + 1).trim();
      } else if (lowerAttr.startsWith('expires=')) {
        if (eqIndex != -1) expires = attr.substring(eqIndex + 1).trim();
      } else if (lowerAttr.startsWith('max-age=')) {
        if (eqIndex != -1) {
          maxAge = int.tryParse(attr.substring(eqIndex + 1).trim());
        }
      } else if (lowerAttr.startsWith('path=')) {
        if (eqIndex != -1) {
          final v = attr.substring(eqIndex + 1).trim();
          if (v.isNotEmpty) path = v;
        }
      } else if (lowerAttr.startsWith('samesite=')) {
        if (eqIndex != -1) sameSite = attr.substring(eqIndex + 1).trim();
      } else if (lowerAttr == 'secure') {
        secure = true;
      } else if (lowerAttr == 'httponly') {
        httpOnly = true;
      }
    }

    final entry = lookupEntry(name);
    Map<String, dynamic>? knownData =
        entry == null ? null : {'cat': entry.$1, 'prov': entry.$2};

    // Same rules as the detection engine: a catalogued first-party cookie
    // names its service; a generic tracking name (NID, token, A) seen on
    // this site is the site's own cookie, not the ad network's.
    final entity = entityForCookie(name);
    if (entity != null) {
      knownData = {
        'cat': knownData?['cat'] ?? _categoryOf(entity.category),
        'prov': entity.name,
      };
    } else if (knownData != null &&
        _trackingCategories.contains(knownData['cat']) &&
        !isDistinctiveCookieName(name)) {
      knownData = null;
    } else if (knownData != null) {
      final prov = knownData['prov'] as String?;
      knownData = {
        ...knownData,
        'prov': prov == null ? null : entityNamed(prov)?.name ?? prov,
      };
    }

    // Wildcard consent detection for consent-manager state names.
    if (knownData == null && _consentName.hasMatch(name)) {
      knownData = {'cat': CookieCategory.essential, 'prov': 'Consent Manager'};
    }

    final known = knownData ?? {};

    // Max-Age wins over Expires (RFC 6265 5.3): expires = now + Max-Age.
    if (maxAge != null) {
      expires = maxAge <= 0
          ? 'expired (deleted)'
          : (now ?? DateTime.now())
              .toUtc()
              .add(Duration(seconds: maxAge))
              .toIso8601String();
    } else if (expires != null) {
      try {
        expires = HttpDate.parse(expires).toUtc().toIso8601String();
      } catch (_) {
        // Unparsable Expires: keep the raw text.
      }
    }

    return CookieInfo(
      name: name,
      value: value,
      domain: domain,
      path: path,
      requestHost: requestHost,
      expires: expires,
      sameSite: sameSite,
      secure: secure,
      httpOnly: httpOnly,
      category: known['cat'] ?? CookieCategory.unknown,
      provider: known['prov'],
      source: source,
    );
  }

  /// A cookie the browser reported, with its real flags: a flag the browser
  /// does not expose stays null (unknown), never false.
  static CookieInfo fromBrowser(BrowserCookie c) {
    final base = analyze('${c.name}=${c.value}', 'Browser');
    String? text<T>(Observed<T> o, String Function(T) f) =>
        o is Present<T> ? f(o.value) : null;
    bool? flag(Observed<bool> o) => o is Present<bool> ? o.value : null;
    return CookieInfo(
      name: c.name,
      value: c.value,
      domain: text<String>(c.domain, (v) => v),
      path: text<String>(c.path, (v) => v),
      expires: text<DateTime>(c.expires, (v) => v.toUtc().toIso8601String()),
      sameSite: text<String>(c.sameSite, (v) => v),
      secure: flag(c.isSecure),
      httpOnly: flag(c.isHttpOnly),
      category: base.category,
      provider: base.provider,
      source: 'Browser',
    );
  }
}
