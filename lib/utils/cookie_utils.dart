import 'package:flutter/material.dart';

enum CookieCategory {
  essential,
  analytics,
  advertising,
  social,
  unknown,
}

class CookieInfo {
  final String name;
  final String value;
  final String? domain;
  final CookieCategory category;
  final String? provider;
  final String source; // 'Server' or 'Browser'

  CookieInfo({
    required this.name,
    required this.value,
    this.domain,
    required this.category,
    this.provider,
    required this.source,
  });
}

class CookieUtils {
  static final Map<String, Map<String, dynamic>> _knownCookies = {
    // Analytics (Google)
    '_ga': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_gid': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_gat': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utma': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmb': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmc': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmz': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    'NID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    '1P_JAR': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'AEC': {'cat': CookieCategory.essential, 'prov': 'Google'},

    // Azure / Microsoft
    'ARRAffinity': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'ARRAffinitySameSite': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'TiPMix': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'x-ms-gateway-slice': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'ASP.NET_SessionId': {'cat': CookieCategory.essential, 'prov': 'ASP.NET'},

    // Cloudflare
    '__cf_bm': {'cat': CookieCategory.essential, 'prov': 'Cloudflare'},
    'cf_clearance': {'cat': CookieCategory.essential, 'prov': 'Cloudflare'},

    // Facebook
    '_fbp': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'fr': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},

    // PHP
    'PHPSESSID': {'cat': CookieCategory.essential, 'prov': 'PHP'},

    // Java
    'JSESSIONID': {'cat': CookieCategory.essential, 'prov': 'Java'},

    // DoubleClick
    'IDE': {'cat': CookieCategory.advertising, 'prov': 'DoubleClick'},
    'DSID': {'cat': CookieCategory.advertising, 'prov': 'DoubleClick'},
  };

  static CookieInfo analyze(String rawCookie, String source) {
    // Parse name and value
    final parts = rawCookie.split('=');
    final name = parts[0].trim();
    String value = parts.length > 1 ? parts.sublist(1).join('=') : '';

    // If complex set-cookie string (e.g. "name=val; Path=/; Secure"), just take the first part
    if (value.contains(';')) {
      value = value.split(';')[0];
    }

    final known = _knownCookies[name] ??
        _knownCookies.entries
            .firstWhere((e) => name.startsWith(e.key),
                orElse: () => MapEntry('', {}))
            .value;

    return CookieInfo(
      name: name,
      value: value,
      category: known['cat'] ?? CookieCategory.unknown,
      provider: known['prov'],
      source: source,
    );
  }

  static List<CookieInfo> parseBrowserCookies(String documentCookie) {
    if (documentCookie.isEmpty) return [];

    return documentCookie
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => analyze(s, 'Browser'))
        .toList();
  }

  static List<CookieInfo> mergeCookies(
      List<String> serverCookies, String browserCookies) {
    final Map<String, CookieInfo> merged = {};

    // process server headers first
    for (var sc in serverCookies) {
      // Basic parsing of Set-Cookie header to get name
      // Header format: Name=Value; attributes...
      final firstPart = sc.split(';')[0];
      final name = firstPart.split('=')[0].trim();

      merged[name] = analyze(firstPart, 'Server');
    }

    // process browser cookies (overwrite server ones if present, as they are "live")
    // or keep separate? User said "without browser... only server, with browser... as much as possible"
    // Usually browser has the latest state.
    final browserList = parseBrowserCookies(browserCookies);
    for (var bc in browserList) {
      // If it existed from server, we might want to flag it was seen on both?
      // For now, simplify to just showing unique cookies.
      // Changing source to 'Browser + Server' if needed, but let's keep it simple.
      if (merged.containsKey(bc.name)) {
        merged[bc.name] = CookieInfo(
            name: bc.name,
            value: bc.value,
            category: bc.category,
            provider: bc.provider,
            source: 'Server + Browser');
      } else {
        merged[bc.name] = bc;
      }
    }

    return merged.values.toList();
  }
}
