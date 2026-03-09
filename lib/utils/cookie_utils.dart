enum CookieCategory {
  essential,
  analytics,
  advertising,
  social,
  functional,
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
    '_ga_': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_gid': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_gat': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utma': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmb': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmc': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmz': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmt': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_gcl_au': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    '__gads': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    '__gpi': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    '__gpa': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
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
    '_GRECAPTCHA': {
      'cat': CookieCategory.essential,
      'prov': 'Google reCAPTCHA'
    },
    '__gsas': {'cat': CookieCategory.analytics, 'prov': 'Google Ads'},
    'pm_sess': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'cookiePreferences': {
      'cat': CookieCategory.functional,
      'prov': 'Google Tag Manager'
    },
    'td': {'cat': CookieCategory.analytics, 'prov': 'Google Tag Manager'},

    // --- Meta / Facebook ---
    '_fbp': {'cat': CookieCategory.advertising, 'prov': 'Meta Pixel'},
    '_fbc': {'cat': CookieCategory.advertising, 'prov': 'Meta Pixel'},
    'fr': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'sb': {'cat': CookieCategory.essential, 'prov': 'Facebook'},
    'datr': {'cat': CookieCategory.essential, 'prov': 'Facebook'},
    'c_user': {'cat': CookieCategory.essential, 'prov': 'Facebook'},
    'xs': {'cat': CookieCategory.essential, 'prov': 'Facebook'},
    'wd': {'cat': CookieCategory.essential, 'prov': 'Facebook'},

    // --- YouTube ---
    'YSC': {'cat': CookieCategory.advertising, 'prov': 'YouTube'},
    'VISITOR_INFO1_LIVE': {
      'cat': CookieCategory.advertising,
      'prov': 'YouTube'
    },
    'PREF': {'cat': CookieCategory.functional, 'prov': 'YouTube'},

    // --- Microsoft / LinkedIn / Clarity ---
    '_clck': {'cat': CookieCategory.analytics, 'prov': 'Microsoft Clarity'},
    '_clsk': {'cat': CookieCategory.analytics, 'prov': 'Microsoft Clarity'},
    'CLID': {'cat': CookieCategory.analytics, 'prov': 'Microsoft Clarity'},
    'ANONCHK': {'cat': CookieCategory.analytics, 'prov': 'Microsoft Clarity'},
    'MR': {'cat': CookieCategory.analytics, 'prov': 'Microsoft Clarity'},
    'SM': {'cat': CookieCategory.analytics, 'prov': 'Microsoft Clarity'},
    '_uetsid': {'cat': CookieCategory.advertising, 'prov': 'Microsoft Ads'},
    '_uetvid': {'cat': CookieCategory.advertising, 'prov': 'Microsoft Ads'},
    'MUID': {'cat': CookieCategory.advertising, 'prov': 'Microsoft Ads'},
    'MUIDB': {'cat': CookieCategory.advertising, 'prov': 'Microsoft Ads'},
    'ARRAffinity': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'ARRAffinitySameSite': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'TiPMix': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'x-ms-gateway-slice': {'cat': CookieCategory.essential, 'prov': 'Azure'},
    'ASP.NET_SessionId': {'cat': CookieCategory.essential, 'prov': 'ASP.NET'},
    'MSCC': {'cat': CookieCategory.essential, 'prov': 'Microsoft'},
    'li_at': {'cat': CookieCategory.essential, 'prov': 'LinkedIn'},
    'li_sugr': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'UserMatchHistory': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'bscookie': {'cat': CookieCategory.social, 'prov': 'LinkedIn'},
    'bcookie': {'cat': CookieCategory.social, 'prov': 'LinkedIn'},
    'lidc': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'lang': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},

    // --- HubSpot ---
    'hubspotutk': {'cat': CookieCategory.analytics, 'prov': 'HubSpot'},
    '__hssc': {'cat': CookieCategory.analytics, 'prov': 'HubSpot'},
    '__hssrc': {'cat': CookieCategory.analytics, 'prov': 'HubSpot'},
    '__hstc': {'cat': CookieCategory.analytics, 'prov': 'HubSpot'},
    'messagesUtk': {'cat': CookieCategory.functional, 'prov': 'HubSpot Chat'},

    // --- Matomo / Piwik ---
    '_pk_id': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    '_pk_ses': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    '_pk_ref': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    'mtm_': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},

    // --- Hotjar ---
    '_hjSession_': {'cat': CookieCategory.analytics, 'prov': 'Hotjar'},
    '_hjSessionUser_': {'cat': CookieCategory.analytics, 'prov': 'Hotjar'},
    '_hjIncludedInSample': {'cat': CookieCategory.analytics, 'prov': 'Hotjar'},
    '_hjAbsoluteSessionInProgress': {
      'cat': CookieCategory.analytics,
      'prov': 'Hotjar'
    },

    // --- Shopify ---
    '_s_id': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_s_session': {'cat': CookieCategory.essential, 'prov': 'Shopify'},
    '_shopify_s': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_shopify_y': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    'cart': {'cat': CookieCategory.essential, 'prov': 'Shopify'},
    'cart_sig': {'cat': CookieCategory.essential, 'prov': 'Shopify'},
    'keep_alive': {'cat': CookieCategory.essential, 'prov': 'Shopify'},

    // --- Segment ---
    'ajs_anonymous_id': {'cat': CookieCategory.analytics, 'prov': 'Segment'},
    'ajs_user_id': {'cat': CookieCategory.analytics, 'prov': 'Segment'},

    // --- Snowplow ---
    '_sp_': {'cat': CookieCategory.analytics, 'prov': 'Snowplow'},

    // --- Cookie Consent (Various) ---
    'cookiehub': {'cat': CookieCategory.essential, 'prov': 'CookieHub'},
    'OptanonConsent': {'cat': CookieCategory.essential, 'prov': 'OneTrust'},
    'OptanonAlertBoxClosed': {
      'cat': CookieCategory.essential,
      'prov': 'OneTrust'
    },
    'euconsent': {'cat': CookieCategory.essential, 'prov': 'IAB Consent'},
    'euconsent-v2': {'cat': CookieCategory.essential, 'prov': 'IAB Consent'},
    'Cookieyes-consent': {'cat': CookieCategory.essential, 'prov': 'CookieYes'},
    'cookieyes-': {'cat': CookieCategory.essential, 'prov': 'CookieYes'},
    '_cs_c': {'cat': CookieCategory.essential, 'prov': 'Contentsquare'},
    'ckns_explicit': {
      'cat': CookieCategory.essential,
      'prov': 'Consent Manager'
    },
    'CookieConsent': {'cat': CookieCategory.essential, 'prov': 'Cookiebot'},
    'CookieConsentBulkTicket': {
      'cat': CookieCategory.functional,
      'prov': 'Cookiebot'
    },
    'userlang': {'cat': CookieCategory.functional, 'prov': 'Cookiebot'},
    'consentUUID': {'cat': CookieCategory.essential, 'prov': 'Cookiebot'},
    'CrossConsent': {'cat': CookieCategory.essential, 'prov': 'Cookiebot'},

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

    // --- Pinterest ---
    '_pin_dot': {'cat': CookieCategory.advertising, 'prov': 'Pinterest'},
    '_pinterest_sess': {'cat': CookieCategory.essential, 'prov': 'Pinterest'},
    '_pinterest_ct_ua': {'cat': CookieCategory.analytics, 'prov': 'Pinterest'},

    // --- Chartbeat ---
    '_cb': {'cat': CookieCategory.analytics, 'prov': 'Chartbeat'},
    '_chartbeat2': {'cat': CookieCategory.analytics, 'prov': 'Chartbeat'},
    '_cb_ls': {'cat': CookieCategory.analytics, 'prov': 'Chartbeat'},
    '_cb_cp': {'cat': CookieCategory.analytics, 'prov': 'Chartbeat'},

    // --- Advertising & Tracking (General) ---
    '__qca': {'cat': CookieCategory.advertising, 'prov': 'Quantcast'},
    'uuid': {'cat': CookieCategory.advertising, 'prov': 'General AdTech'},
    'uuid2': {'cat': CookieCategory.advertising, 'prov': 'AppNexus'},
    'sess': {'cat': CookieCategory.advertising, 'prov': 'AppNexus'},
    'pdomid': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    '_cmpQcif3pcsupported': {
      'cat': CookieCategory.functional,
      'prov': 'Consent Manager'
    },
    'Universal_uid': {'cat': CookieCategory.analytics, 'prov': 'Universal ID'},
    'ltid': {'cat': CookieCategory.analytics, 'prov': 'LiveIntent'},
    '_li_ss': {'cat': CookieCategory.advertising, 'prov': 'LiveIntent'},
    '__ain_cid': {'cat': CookieCategory.analytics, 'prov': 'AudiencePlus'},
    '__aim_hls': {'cat': CookieCategory.analytics, 'prov': 'AudiencePlus'},
    '__eoi': {'cat': CookieCategory.advertising, 'prov': 'Google Ad Manager'},
    '_cto_bidid': {'cat': CookieCategory.advertising, 'prov': 'Criteo'},
    '_pcid': {'cat': CookieCategory.analytics, 'prov': 'Piano Analytics'},
    '_cc_id': {'cat': CookieCategory.advertising, 'prov': 'Lotame'},
    '_st_id': {'cat': CookieCategory.analytics, 'prov': 'StatCounter'},
    '__tbc': {'cat': CookieCategory.advertising, 'prov': 'Taboola / Piano'},
    '_pctx': {'cat': CookieCategory.analytics, 'prov': 'Piano Analytics'},
    '_pcus': {'cat': CookieCategory.analytics, 'prov': 'Piano Analytics'},
    '_pprv': {
      'cat': CookieCategory.essential,
      'prov': 'Piano Analytics (Privacy)'
    },
    'cX_G': {'cat': CookieCategory.analytics, 'prov': 'Piano (Cxense)'},
    'cx_P': {'cat': CookieCategory.analytics, 'prov': 'Piano (Cxense)'},
    'xbc': {'cat': CookieCategory.analytics, 'prov': 'Piano Analytics'},
    'permutive-id': {'cat': CookieCategory.analytics, 'prov': 'Permutive'},
    'ecos.dt': {'cat': CookieCategory.analytics, 'prov': 'Dynatrace'},
    'ckns_policy': {'cat': CookieCategory.essential, 'prov': 'Consent Manager'},
    'usnatUUID': {'cat': CookieCategory.essential, 'prov': 'Privacy/Consent'},

    // --- Analytics (General) ---
    'mp_': {'cat': CookieCategory.analytics, 'prov': 'Mixpanel'},
    'optimizelyEndUserId': {
      'cat': CookieCategory.analytics,
      'prov': 'Optimizely'
    },
    'optimizelySession': {
      'cat': CookieCategory.analytics,
      'prov': 'Optimizely'
    },
    '_ym_uid': {'cat': CookieCategory.analytics, 'prov': 'Yandex Metrica'},
    '_ym_d': {'cat': CookieCategory.analytics, 'prov': 'Yandex Metrica'},
    '_ym_isad': {'cat': CookieCategory.analytics, 'prov': 'Yandex Metrica'},
    'ELQSTATUS': {'cat': CookieCategory.analytics, 'prov': 'Oracle Eloqua'},
    'ELOQUA': {'cat': CookieCategory.analytics, 'prov': 'Oracle Eloqua'},

    // --- A/B Testing & Personalization ---
    '_vwo_': {'cat': CookieCategory.analytics, 'prov': 'VWO'},
    '_vis_opt_': {'cat': CookieCategory.analytics, 'prov': 'VWO'},
    '_ga_exp': {'cat': CookieCategory.analytics, 'prov': 'Google Optimize'},

    // --- Server / CMS / Tech ---
    'eviivo': {'cat': CookieCategory.essential, 'prov': 'eviivo'},
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
    'laravel_session': {'cat': CookieCategory.essential, 'prov': 'Laravel'},
    'XSRF-TOKEN': {'cat': CookieCategory.essential, 'prov': 'Security/CSRF'},
    '__Secure-PHPSESSID': {'cat': CookieCategory.essential, 'prov': 'PHP'},
    'csrftoken': {'cat': CookieCategory.essential, 'prov': 'Django/Security'},

    // --- Security & Bot Management ---
    'ak_bmsc': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
    'bm_sv': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
    'bm_sz': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
    'bm_mi': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
    '_abck': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
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
      final firstPart = sc.split(';')[0];
      final name = firstPart.split('=')[0].trim();
      merged[name] = analyze(firstPart, 'Server');
    }

    final browserList = parseBrowserCookies(browserCookies);
    for (var bc in browserList) {
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
