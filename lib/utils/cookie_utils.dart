enum CookieCategory {
  essential,
  analytics,
  advertising,
  social,
  functional, // Added new category
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
    // --- Google & DoubleClick ---
    '_ga': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_gid': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_gat': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utma': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmb': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmc': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmz': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmt': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_gcl_au': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    'NID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    '1P_JAR': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'AEC': {'cat': CookieCategory.essential, 'prov': 'Google'},
    'CONSENT': {'cat': CookieCategory.essential, 'prov': 'Google'},
    'SOCS': {'cat': CookieCategory.essential, 'prov': 'Google'},
    'SID': {'cat': CookieCategory.essential, 'prov': 'Google'},
    'HSID': {'cat': CookieCategory.essential, 'prov': 'Google'},
    'SSID': {'cat': CookieCategory.essential, 'prov': 'Google'},
    'APISID': {'cat': CookieCategory.essential, 'prov': 'Google'},
    'SAPISID': {'cat': CookieCategory.essential, 'prov': 'Google'},
    '__Secure-3PSID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    '__Secure-1PSID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'IDE': {'cat': CookieCategory.advertising, 'prov': 'DoubleClick'},
    'DSID': {'cat': CookieCategory.advertising, 'prov': 'DoubleClick'},
    '_greza_p': {'cat': CookieCategory.functional, 'prov': 'Google Recaptcha'},

    // --- Meta / Facebook ---
    '_fbp': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    '_fbc': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'fr': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'sb': {'cat': CookieCategory.essential, 'prov': 'Facebook'},
    'datr': {'cat': CookieCategory.essential, 'prov': 'Facebook'},
    'c_user': {'cat': CookieCategory.essential, 'prov': 'Facebook'},
    'xs': {'cat': CookieCategory.essential, 'prov': 'Facebook'},
    'wd': {'cat': CookieCategory.essential, 'prov': 'Facebook'},

    // --- Microsoft / LinkedIn / Azure ---
    'ARRAffinity': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'ARRAffinitySameSite': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'TiPMix': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'x-ms-gateway-slice': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'ASP.NET_SessionId': {'cat': CookieCategory.essential, 'prov': 'ASP.NET'},
    'MSCC': {'cat': CookieCategory.essential, 'prov': 'Microsoft'},
    'MUID': {'cat': CookieCategory.advertising, 'prov': 'Microsoft'},
    'MUIDB': {'cat': CookieCategory.advertising, 'prov': 'Microsoft'},
    'li_at': {'cat': CookieCategory.essential, 'prov': 'LinkedIn'},
    'li_sugr': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'UserMatchHistory': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'bscookie': {'cat': CookieCategory.social, 'prov': 'LinkedIn'},
    'lidc': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'lang': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},

    // --- Amazon / AWS ---
    'aws-target-visitor-id': {'cat': CookieCategory.analytics, 'prov': 'AWS'},
    'aws-target-data-provider-id': {
      'cat': CookieCategory.analytics,
      'prov': 'AWS'
    },
    'AWSALB': {'cat': CookieCategory.functional, 'prov': 'AWS Load Balancer'},
    'AWSALBCORS': {
      'cat': CookieCategory.functional,
      'prov': 'AWS Load Balancer'
    },
    'sp-cdn': {'cat': CookieCategory.functional, 'prov': 'Amazon'},

    // --- Cloudflare ---
    '__cf_bm': {'cat': CookieCategory.essential, 'prov': 'Cloudflare'},
    'cf_clearance': {'cat': CookieCategory.essential, 'prov': 'Cloudflare'},
    '__cflb': {'cat': CookieCategory.functional, 'prov': 'Cloudflare'},
    '_cfuvid': {'cat': CookieCategory.functional, 'prov': 'Cloudflare'},

    // --- Twitter / X ---
    'guest_id': {'cat': CookieCategory.analytics, 'prov': 'Twitter'},
    'guest_id_ads': {'cat': CookieCategory.advertising, 'prov': 'Twitter'},
    'guest_id_marketing': {
      'cat': CookieCategory.advertising,
      'prov': 'Twitter'
    },
    'personalization_id': {
      'cat': CookieCategory.advertising,
      'prov': 'Twitter'
    },
    '_twitter_sess': {'cat': CookieCategory.essential, 'prov': 'Twitter'},
    'ct0': {'cat': CookieCategory.essential, 'prov': 'Twitter'},
    'auth_token': {'cat': CookieCategory.essential, 'prov': 'Twitter'},

    // --- TikTok ---
    'tt_webid': {'cat': CookieCategory.analytics, 'prov': 'TikTok'},
    'tt_webid_v2': {'cat': CookieCategory.analytics, 'prov': 'TikTok'},
    '_tiktok_headers': {'cat': CookieCategory.functional, 'prov': 'TikTok'},

    // --- Advertising & Tracking (General) ---
    'uuid': {'cat': CookieCategory.advertising, 'prov': 'General AdTech'},
    'uuid2': {'cat': CookieCategory.advertising, 'prov': 'AppNexus'},
    'sess': {'cat': CookieCategory.advertising, 'prov': 'AppNexus'},
    '_cmpQcif3pcsupported': {
      'cat': CookieCategory.functional,
      'prov': 'Consent Manager'
    },
    'euconsent-v2': {'cat': CookieCategory.functional, 'prov': 'IAB Consent'},

    // --- Analytics (General) ---
    '_hjid': {'cat': CookieCategory.analytics, 'prov': 'Hotjar'},
    '_hjIncludedInSample': {'cat': CookieCategory.analytics, 'prov': 'Hotjar'},
    '_hjSessionUser': {'cat': CookieCategory.analytics, 'prov': 'Hotjar'},
    'mp_': {'cat': CookieCategory.analytics, 'prov': 'Mixpanel'},

    // --- Server / CMS / Tech ---
    'PHPSESSID': {'cat': CookieCategory.essential, 'prov': 'PHP'},
    'JSESSIONID': {'cat': CookieCategory.essential, 'prov': 'Java'},
    'X-Mapping-': {'cat': CookieCategory.functional, 'prov': 'Load Balancer'},
    'DYNSRV': {'cat': CookieCategory.functional, 'prov': 'Load Balancer'},
    'wordpress_test_cookie': {
      'cat': CookieCategory.functional,
      'prov': 'WordPress'
    },
    'wp-settings-': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'wp-settings-time-': {
      'cat': CookieCategory.functional,
      'prov': 'WordPress'
    },
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
