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

  final String? expires;
  final bool secure;
  final bool httpOnly;

  CookieInfo({
    required this.name,
    required this.value,
    this.domain,
    required this.category,
    this.provider,
    required this.source,
    this.expires,
    this.secure = false,
    this.httpOnly = false,
  });
}

class CookieUtils {
  static final List<String> _prefixKeys = _knownCookies.keys
      .where((k) => k.endsWith('_') || k.endsWith('-'))
      .toList();

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
    '_td': {'cat': CookieCategory.analytics, 'prov': 'Treasure Data'},
    'gtm_pageview_count': {
      'cat': CookieCategory.analytics,
      'prov': 'Google Tag Manager'
    },
    'gtm_session_start': {
      'cat': CookieCategory.analytics,
      'prov': 'Google Tag Manager'
    },
    'gtm_': {'cat': CookieCategory.analytics, 'prov': 'Google Tag Manager'},

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
    '__msid': {'cat': CookieCategory.analytics, 'prov': 'Microsoft'},
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

    // --- Heap Analytics ---
    '_hp5_': {'cat': CookieCategory.analytics, 'prov': 'Heap Analytics'},

    // --- Shopify ---
    '_s_id': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_s_session': {'cat': CookieCategory.essential, 'prov': 'Shopify'},
    '_shopify_s': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_shopify_y': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    'cart': {'cat': CookieCategory.essential, 'prov': 'Shopify'},
    'cart_sig': {'cat': CookieCategory.essential, 'prov': 'Shopify'},
    'keep_alive': {'cat': CookieCategory.essential, 'prov': 'Shopify'},

    // --- Billy Grace ---
    '__BillyPix_session_id': {
      'cat': CookieCategory.analytics,
      'prov': 'Billy Grace'
    },
    '__BillyPix_sid': {'cat': CookieCategory.analytics, 'prov': 'Billy Grace'},
    '__BillyPix_uid': {'cat': CookieCategory.analytics, 'prov': 'Billy Grace'},

    // --- Zephr ---
    'zephr_AWSALB': {'cat': CookieCategory.functional, 'prov': 'Zephr (AWS)'},
    'zephr_AWSALBCORS': {
      'cat': CookieCategory.functional,
      'prov': 'Zephr (AWS)'
    },
    'gtm_temptation_template_id': {
      'cat': CookieCategory.functional,
      'prov': 'Zephr'
    },
    'temptationTrackingId': {'cat': CookieCategory.analytics, 'prov': 'Zephr'},

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
    'didomi_dcs': {'cat': CookieCategory.essential, 'prov': 'Didomi'},
    '_cs_c': {'cat': CookieCategory.essential, 'prov': 'Contentsquare'},
    'cs_fpid': {'cat': CookieCategory.analytics, 'prov': 'Contentsquare'},
    'ckns_explicit': {
      'cat': CookieCategory.essential,
      'prov': 'Consent Manager'
    },
    'tcf20_purposes': {
      'cat': CookieCategory.essential,
      'prov': 'TCF Consent Manager'
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

    // --- Snapchat ---
    '_scid': {'cat': CookieCategory.advertising, 'prov': 'Snapchat Pixel'},
    '_sctr': {'cat': CookieCategory.advertising, 'prov': 'Snapchat Pixel'},

    // --- Reddit ---
    '_rdt_uuid': {'cat': CookieCategory.advertising, 'prov': 'Reddit Pixel'},

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
    '_cb_svref': {'cat': CookieCategory.analytics, 'prov': 'Chartbeat'},

    // --- Prebid / Common ID ---
    '_pubcid': {'cat': CookieCategory.advertising, 'prov': 'Prebid'},
    '_pubcid_cst': {'cat': CookieCategory.advertising, 'prov': 'Prebid'},
    'shd_uid': {'cat': CookieCategory.advertising, 'prov': 'SharedID'},

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
    'cto_bidid': {'cat': CookieCategory.advertising, 'prov': 'Criteo'},
    'cto_': {'cat': CookieCategory.advertising, 'prov': 'Criteo'},
    '_pcid': {'cat': CookieCategory.analytics, 'prov': 'Piano Analytics'},
    '_cc_id': {'cat': CookieCategory.advertising, 'prov': 'Lotame'},
    '_cc_cc': {'cat': CookieCategory.advertising, 'prov': 'Lotame'},
    '_cc_dc': {'cat': CookieCategory.advertising, 'prov': 'Lotame'},
    '_st_id': {'cat': CookieCategory.analytics, 'prov': 'StatCounter'},
    '__tbc': {'cat': CookieCategory.advertising, 'prov': 'Taboola / Piano'},
    'taboola_session_id': {
      'cat': CookieCategory.advertising,
      'prov': 'Taboola'
    },
    't_session_id': {'cat': CookieCategory.advertising, 'prov': 'Taboola'},
    '_pctx': {'cat': CookieCategory.analytics, 'prov': 'Piano Analytics'},
    '_pcus': {'cat': CookieCategory.analytics, 'prov': 'Piano Analytics'},
    '_pprv': {
      'cat': CookieCategory.essential,
      'prov': 'Piano Analytics (Privacy)'
    },
    'pa_privacy': {
      'cat': CookieCategory.essential,
      'prov': 'Piano Analytics (Privacy)'
    },
    'cX_G': {'cat': CookieCategory.analytics, 'prov': 'Piano (Cxense)'},
    'cx_P': {'cat': CookieCategory.analytics, 'prov': 'Piano (Cxense)'},
    'fig_firstparty': {
      'cat': CookieCategory.analytics,
      'prov': 'Piano (Cxense)'
    },
    'fig_': {'cat': CookieCategory.analytics, 'prov': 'Piano (Cxense)'},
    'xbc': {'cat': CookieCategory.analytics, 'prov': 'Piano Analytics'},
    'permutive-id': {'cat': CookieCategory.analytics, 'prov': 'Permutive'},
    'ecos.dt': {'cat': CookieCategory.analytics, 'prov': 'Dynatrace'},
    'ckns_policy': {'cat': CookieCategory.essential, 'prov': 'Consent Manager'},
    'usnatUUID': {'cat': CookieCategory.essential, 'prov': 'Privacy/Consent'},

    // --- Adobe Analytics / Experience Cloud ---
    's_ecid': {'cat': CookieCategory.analytics, 'prov': 'Adobe Analytics'},
    's_fid': {'cat': CookieCategory.analytics, 'prov': 'Adobe Analytics'},
    's_cc': {'cat': CookieCategory.essential, 'prov': 'Adobe Analytics'},
    's_sq': {'cat': CookieCategory.analytics, 'prov': 'Adobe Analytics'},
    's_vi': {'cat': CookieCategory.analytics, 'prov': 'Adobe Analytics'},
    's_nr': {'cat': CookieCategory.analytics, 'prov': 'Adobe Analytics'},
    's_ppv': {'cat': CookieCategory.analytics, 'prov': 'Adobe Analytics'},
    's_ptc': {'cat': CookieCategory.analytics, 'prov': 'Adobe Analytics'},
    'AMCVS_': {
      'cat': CookieCategory.essential,
      'prov': 'Adobe Experience Cloud'
    },
    'AMCV_': {
      'cat': CookieCategory.essential,
      'prov': 'Adobe Experience Cloud'
    },
    'mbox': {'cat': CookieCategory.analytics, 'prov': 'Adobe Target'},

    // --- Advertising (Additional AdTech) ---
    'bkdc': {'cat': CookieCategory.advertising, 'prov': 'Oracle BlueKai'},
    'bku': {'cat': CookieCategory.advertising, 'prov': 'Oracle BlueKai'},
    'obuid': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'rpb': {'cat': CookieCategory.advertising, 'prov': 'Rubicon Project'},
    'khaos': {'cat': CookieCategory.advertising, 'prov': 'Rubicon Project'},
    'KRTB_CLIENT_ID': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'KTPCACHED': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'tdid': {'cat': CookieCategory.advertising, 'prov': 'The Trade Desk'},
    'TDID': {'cat': CookieCategory.advertising, 'prov': 'The Trade Desk'},
    'TDCPM': {'cat': CookieCategory.advertising, 'prov': 'The Trade Desk'},
    'mt_id': {'cat': CookieCategory.advertising, 'prov': 'MediaMath'},
    'mt_muid': {'cat': CookieCategory.advertising, 'prov': 'MediaMath'},
    'mc': {'cat': CookieCategory.advertising, 'prov': 'Quantcast'},
    'sifi_uuid': {'cat': CookieCategory.advertising, 'prov': 'Simpli.fi'},
    '__adroll_fpc': {'cat': CookieCategory.advertising, 'prov': 'AdRoll'},
    '__ar_v4': {'cat': CookieCategory.advertising, 'prov': 'AdRoll'},
    'gg_id': {'cat': CookieCategory.advertising, 'prov': 'GumGum'},
    'idl': {'cat': CookieCategory.advertising, 'prov': 'LiveRamp'},
    '_lr_': {'cat': CookieCategory.advertising, 'prov': 'LiveRamp'},
    '_sh_id': {'cat': CookieCategory.advertising, 'prov': 'SteelHouse'},
    'tluid': {'cat': CookieCategory.advertising, 'prov': 'TripleLift'},
    '_cb_sv': {'cat': CookieCategory.analytics, 'prov': 'Chartbeat'},

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
    '_vwo_ds': {'cat': CookieCategory.analytics, 'prov': 'VWO'},
    '_vis_opt_': {'cat': CookieCategory.analytics, 'prov': 'VWO'},
    '_ga_exp': {'cat': CookieCategory.analytics, 'prov': 'Google Optimize'},

    // --- Nielsen / NetRatings ---
    '__nrbi': {'cat': CookieCategory.analytics, 'prov': 'Nielsen'},
    '__nrbic': {'cat': CookieCategory.analytics, 'prov': 'Nielsen'},

    // --- Wysistat ---
    'Wysistat': {'cat': CookieCategory.analytics, 'prov': 'Wysistat'},

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
    'authId': {'cat': CookieCategory.essential, 'prov': 'Authentication'},
    'dsy-color-mode': {'cat': CookieCategory.functional, 'prov': 'UI Preference'},
    'uhz': {'cat': CookieCategory.functional, 'prov': 'Internal Identifier'},

    // --- Security & Bot Management ---
    'ak_bmsc': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
    'bm_sv': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
    'bm_sz': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
    'bm_mi': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
    'bm_lso': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
    'bm_s': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},
    '_abck': {'cat': CookieCategory.essential, 'prov': 'Akamai Bot Manager'},

    // --- Consent Management (Mozilla Rules) ---
    '.consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (galaxus.de)'
    },
    'BCP': {'cat': CookieCategory.essential, 'prov': 'Consent (bing.com)'},
    'BDK_CookieLawAccepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (borger.dk)'
    },
    'BayernMatomo': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bayern.de)'
    },
    'CBARIH': {'cat': CookieCategory.essential, 'prov': 'Consent (alza.cz)'},
    'CONSENTMGR': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (vodafone.com)'
    },
    'ConsentChecked': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (intersport.bg)'
    },
    'ConsentV2': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (intersport.fo)'
    },
    'CookieBanner_Closed': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (jamanetwork.com)'
    },
    'CookiePermissionInfo': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (postnl.nl)'
    },
    'ECCC': {'cat': CookieCategory.essential, 'prov': 'Consent (ecosia.org)'},
    'FC2_GDPR': {'cat': CookieCategory.essential, 'prov': 'Consent (fc2.com)'},
    'FCCDCF': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (kupujemprodajem.com)'
    },
    'FCNEC': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (kupujemprodajem.com)'
    },
    'HASSEENNOTICE': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (ups.com)'
    },
    'OPTOUTCONSENT': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (vodafone.pt)'
    },
    'OPTOUTMULTI_TYPE': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (autodesk.com)'
    },
    'PRIVACY_POLICY_INFO_2018_OPT_OUT': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (uio.no)'
    },
    'RABO_PSL': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (rabobank.nl)'
    },
    'SSLB': {'cat': CookieCategory.essential, 'prov': 'Consent (swedbank.se)'},
    'TC_PRIVACY': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (sparkasse.at)'
    },
    'UA_ADS': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (novilist.hr)'
    },
    '_CookiePolicyHint': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bequiet.com)'
    },
    '__Secure-HO_Cookie_Consent_Declined': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (hetzner.com)'
    },
    '__cookie__agree': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (sberdevices.ru)'
    },
    '__tnw_cookieConsent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (thenextweb.com)'
    },
    '_accept_usage': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (censor.net)'
    },
    '_cookies_accepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (ubuntu.com)'
    },
    '_cookies_v2': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (blablacar.com.br)'
    },
    '_hjFirstSeen': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (ox.ac.uk)'
    },
    '_s.cookie_consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (smallpdf.com)'
    },
    '_tt_enable_cookie': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (eventbrite.com)'
    },
    '_youtube_vimeo_vid': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (verbatim.co.il)'
    },
    'accept_cookies': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (aemet.es)'
    },
    'accepts-cookies': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (milenio.com)'
    },
    'addtl_consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (promotions.hu)'
    },
    'analytic': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (supersport.hr)'
    },
    'analytics_accepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (aboutcookies.org)'
    },
    'and_cba_EN_US': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (android.com)'
    },
    'approve': {'cat': CookieCategory.essential, 'prov': 'Consent (linker.hr)'},
    'bolConsentChoices': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bol.com)'
    },
    'c24consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (check24.de)'
    },
    'cb': {'cat': CookieCategory.essential, 'prov': 'Consent (threads.net)'},
    'cc_cookie': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (yazio.com)'
    },
    'cc_cookie_accept': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (petel.bg)'
    },
    'cck1': {'cat': CookieCategory.essential, 'prov': 'Consent (europa.eu)'},
    'ck': {'cat': CookieCategory.essential, 'prov': 'Consent (ilovepdf.com)'},
    'cmc_gdpr_hide': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (coinmarketcap.com)'
    },
    'cocos': {'cat': CookieCategory.essential, 'prov': 'Consent (t-mobile.cz)'},
    'consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (science.org)'
    },
    'consentLevel': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (web.de)'
    },
    'consent_cookie': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (worldbank.org)'
    },
    'consent_functional': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (huk24.de)'
    },
    'consent_marketing': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (huk24.de)'
    },
    'consent_status': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (immobilienscout24.de)'
    },
    'consent_technical': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (huk24.de)'
    },
    'consent_version': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (huk24.de)'
    },
    'cookie-agreed': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (gsis.gr)'
    },
    'cookie-allow-necessary': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bundesfinanzministerium.de)'
    },
    'cookie-allow-tracking': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bundesfinanzministerium.de)'
    },
    'cookie-banner': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bundesfinanzministerium.de)'
    },
    'cookie-banner-acceptance-state': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (migros.ch)'
    },
    'cookie-consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (tiktok.com)'
    },
    'cookie-policy-agreement': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (anwb.nl)'
    },
    'cookie-preference': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (korodrogerie.de)'
    },
    'cookie-preferences': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (coolblue.nl)'
    },
    'cookieAgree': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (reg.ru)'
    },
    'cookieApprove': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (nv.ua)'
    },
    'cookieBarSeen': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (olx.ua)'
    },
    'cookieChoice': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (ok.ru)'
    },
    'cookieConsent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (telekom.mk)'
    },
    'cookieConsentVersion': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (telekom.sk)'
    },
    'cookieControl': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (teamspeak.com)'
    },
    'cookieControlPrefs': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (zamunda.net)'
    },
    'cookieControllerStatus': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (verbatim.co.il)'
    },
    'cookieDeclined': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (grundstoff.net)'
    },
    'cookieNotification': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (vegetology.com)'
    },
    'cookiePolicy': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (pnas.org)'
    },
    'cookiePolicyConfirmation': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (halooglasi.com)'
    },
    'cookieSettings': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (steamcommunity.com)'
    },
    'cookie_accepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (aboutcookies.org)'
    },
    'cookie_banner': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bitly.com)'
    },
    'cookie_consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (arbeitsagentur.de)'
    },
    'cookie_consent_essential': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (opera.com)'
    },
    'cookie_consent_marketing': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (opera.com)'
    },
    'cookie_dismiss': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (duh.de)'
    },
    'cookie_functional': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bequiet.com)'
    },
    'cookie_manager': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (credit-agricole.com)'
    },
    'cookie_manager_cookie_marketing_enabled': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (credit-agricole.it)'
    },
    'cookie_manager_cookie_necessary_enabled': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (credit-agricole.it)'
    },
    'cookie_manager_cookie_statistic_enabled': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (credit-agricole.it)'
    },
    'cookie_manager_policy_accepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (credit-agricole.it)'
    },
    'cookie_marketing': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bequiet.com)'
    },
    'cookie_notice_accepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (danas.rs)'
    },
    'cookie_policy_agreement': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (chollometro.com)'
    },
    'cookiebanner': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (thw.de)'
    },
    'cookiebanner_accepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (raspberrypi.com)'
    },
    'cookieconsent_dismissed': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (online-filmek.me)'
    },
    'cookieconsent_status': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (021.rs)'
    },
    'cookiehint': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (dataport.de)'
    },
    'cookielaw': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (openwrt.org)'
    },
    'cookiepermission': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (seasonic.com)'
    },
    'cookies': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (deutschetelekomitsolutions.sk)'
    },
    'cookiesAccepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (onlyfans.com)'
    },
    'cookiesAgreement': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (dnevnik.bg)'
    },
    'cookiesPolicy': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (elcorteingles.es)'
    },
    'cookiesPrivacyPolicy': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (akyga.com)'
    },
    'cookiesPrivacyPolicyExtended': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (akyga.com)'
    },
    'cookies_accepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (mindfactory.de)'
    },
    'cookies_denied': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (aboutcookies.org)'
    },
    'cookies_ok': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (project529.com)'
    },
    'cookiesconsent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (alo.bg)'
    },
    'cookiesjsr': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (mediamarktsaturn.com)'
    },
    'corec': {'cat': CookieCategory.essential, 'prov': 'Consent (t-mobile.cz)'},
    'cpnbCookiesDeclined': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (vodafone.pf)'
    },
    'cpnb_cookiesSettings': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (vodafone.pf)'
    },
    'cto_bundle': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (sport24.gr)'
    },
    'cuPivacyNotice': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (columbia.edu)'
    },
    'd_prefs': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (twitter.com)'
    },
    'data_consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (pricerunner.dk)'
    },
    'dont-track': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (chollometro.com)'
    },
    'dp-cookie-consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bob-sh.de)'
    },
    'eclipse_cookieconsent_status': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (adoptium.net)'
    },
    'ekConsentTcf2': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (kleinanzeigen.de)'
    },
    'et_cookies': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (elegantthemes.com)'
    },
    'eu_cookie': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (reddit.com)'
    },
    'euconsent-bypass': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (web.de)'
    },
    'f_c': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (chollometro.com)'
    },
    'fedconsent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (belgium.be)'
    },
    'fucking-eu-cookies': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bazos.sk)'
    },
    'functionalCookieStatus': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (verbatim.co.il)'
    },
    'g_p': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (chollometro.com)'
    },
    'gdpr': {'cat': CookieCategory.essential, 'prov': 'Consent (kinopoisk.ru)'},
    'gdpr_agreed': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (usnews.com)'
    },
    'googleAnalyticsCookieStatus': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (verbatim.co.il)'
    },
    'gsbbanner': {'cat': CookieCategory.essential, 'prov': 'Consent (bmbf.de)'},
    'happycow-cookie-policy': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (happycow.net)'
    },
    'hideCookieBanner': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (substack.com)'
    },
    'hidecookie': {'cat': CookieCategory.essential, 'prov': 'Consent (vrn.de)'},
    'isReadCookiePolicyDNT': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (asus.com)'
    },
    'isReadCookiePolicyDNTAa': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (asus.com)'
    },
    'isTrackingConsentGiven': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bund.de)'
    },
    'is_agree': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (gordonua.com)'
    },
    'js-cookie-opt-in__consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (anexia.com)'
    },
    'ks-cookie-consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (roku.com)'
    },
    'legal_cookie': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (meteo.be)'
    },
    'mal_consent_gdpr_personalization': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (mall.cz)'
    },
    'mal_consent_gdpr_remarketing': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (mall.cz)'
    },
    'marketing': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (supersport.hr)'
    },
    'marketing_consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (arbeitsagentur.de)'
    },
    'mdpi_cookies_accepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (mdpi.com)'
    },
    'meta_connect_cookies_session': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (metaconnect.com)'
    },
    'miCookieOptOut': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (obi.de)'
    },
    'mkto_opt_out': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (washington.edu)'
    },
    'moove_gdpr_popup': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (endorfy.com)'
    },
    'notice_gdpr_prefs': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (flickr.com)'
    },
    'nrkno-cookie-information': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (nrk.no)'
    },
    'obiConsent': {'cat': CookieCategory.essential, 'prov': 'Consent (obi.de)'},
    'oil_data': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (tagesanzeiger.ch)'
    },
    'onleiheTracking': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (onleihe.de)'
    },
    'optout': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (indiatimes.com)'
    },
    'orange_cookieconsent_dismissed': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (orange.sn)'
    },
    'osano_consentmanager': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (wiley.com)'
    },
    'p': {'cat': CookieCategory.essential, 'prov': 'Consent (etsy.com)'},
    'paydirektCookieAllowed': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (paydirekt.de)'
    },
    'paydirektCookieAllowedPWS': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (paydirekt.de)'
    },
    'personalization_consent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (arbeitsagentur.de)'
    },
    'policy_level': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (skroutz.gr)'
    },
    'politica_cookie': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (dedeman.ro)'
    },
    'polityka15': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (nazwa.pl)'
    },
    'privacy': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (teamgroupinc.com)'
    },
    'privacySettings': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (deepl.com)'
    },
    'privacy_accepted': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (naslovi.net)'
    },
    'privacy_cookie': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bakecaincontrii.com)'
    },
    'purpose_cookie': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (telekom.sk)'
    },
    'pwaconsent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (mediamarkt.at)'
    },
    'receiver_cookie': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (telekom.sk)'
    },
    'request_consent_v': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (bahn.de)'
    },
    'sbrf.pers_notice': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (sberbank.ru)'
    },
    'sensitive_pixel_option': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (wordpress.com)'
    },
    'show_gdpr_consent_messaging': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (nbcnews.com)'
    },
    'site_cookie_info_i': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (intersport.mk)'
    },
    'sq': {'cat': CookieCategory.essential, 'prov': 'Consent (nike.com)'},
    'startsiden-gdpr-disclaimer': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (startsiden.no)'
    },
    'syno_confirm_v4_answer': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (synology.cn)'
    },
    'tp_privacy_base': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (tp-link.com)'
    },
    'tp_privacy_marketing': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (tp-link.com)'
    },
    'trackingconsent': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (abc.net.au)'
    },
    'tv2samtykke': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (tv2.no)'
    },
    'twtr_pixel_opt_in': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (twitter.com)'
    },
    'user_allowed_save_cookie': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (altex.ro)'
    },
    'uw_marketo_opt_in': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (washington.edu)'
    },
    'vfconsents': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (vodafone.cz)'
    },
    'viewed_cookie_policy': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (katalozi.net)'
    },
    'wa_cb': {
      'cat': CookieCategory.essential,
      'prov': 'Consent (whatsapp.com)'
    },
    'yleconsent': {'cat': CookieCategory.essential, 'prov': 'Consent (yle.fi)'},
    // --- Open Cookie Database (Jack Kwakman) ---
    '.ASPXANONYMOUS': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    '.ASPXAUTH': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    '.AspNetCore.Antiforgery.': {
      'cat': CookieCategory.essential,
      'prov': 'Microsoft'
    },
    '.AspNetCore.Mvc.CookieTempDataProvider': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    '.auth': {'cat': CookieCategory.functional, 'prov': 'AFAS'},
    '.secureclient': {'cat': CookieCategory.functional, 'prov': 'AFAS'},
    '.securesession': {'cat': CookieCategory.functional, 'prov': 'AFAS'},
    '.stateflags': {'cat': CookieCategory.functional, 'prov': 'AFAS'},
    'A': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'AADNonce.forms': {
      'cat': CookieCategory.functional,
      'prov': 'Microsoft Dynamics'
    },
    'AADSSO': {'cat': CookieCategory.functional, 'prov': 'Bing / Microsoft'},
    'ABSELB': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'ABTasty': {'cat': CookieCategory.analytics, 'prov': 'ABTasty'},
    'ABTastySession': {'cat': CookieCategory.analytics, 'prov': 'ABTasty'},
    'ACCOUNT_CHOOSER': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'ACL': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'ACLK_DATA': {'cat': CookieCategory.advertising, 'prov': 'Google AdSense'},
    'ACLUSR': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'ADKUID': {'cat': CookieCategory.advertising, 'prov': 'Adkernel'},
    'ADS_VISITOR_ID': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    'ADUSERCOOKIE': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'AFFICHE_W': {'cat': CookieCategory.analytics, 'prov': 'Weborama'},
    'AID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'AMP_': {'cat': CookieCategory.analytics, 'prov': 'Amplitude'},
    'AMP_MKTG_': {'cat': CookieCategory.analytics, 'prov': 'Amplitude'},
    'AMP_TEST': {'cat': CookieCategory.analytics, 'prov': 'Amplitude'},
    'AMP_TLDTEST': {'cat': CookieCategory.analytics, 'prov': 'Amplitude'},
    'AMP_TOKEN': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    'ANID': {'cat': CookieCategory.functional, 'prov': 'Google AdSense'},
    'ANON': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'APC': {
      'cat': CookieCategory.advertising,
      'prov': 'DoubleClick/Google Marketing'
    },
    'APID': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'APIDTS': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'ASLBSA': {'cat': CookieCategory.functional, 'prov': 'Azure / Microsoft'},
    'ASLBSACORS': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'ASP.NET_Sessio': {'cat': CookieCategory.functional, 'prov': 'Microsoft'},
    'ASP.NET_Sessio_Fallback': {
      'cat': CookieCategory.functional,
      'prov': 'Microsoft'
    },
    'ASPSESSIO': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'ATN': {'cat': CookieCategory.advertising, 'prov': 'Atlas'},
    'AUTH_SESSION_ID': {'cat': CookieCategory.functional, 'prov': 'Keycloak'},
    'AUTH_SESSION_ID_LEGACY': {
      'cat': CookieCategory.functional,
      'prov': 'Keycloak'
    },
    'AWSALBTG': {
      'cat': CookieCategory.functional,
      'prov': 'Amazon Web Services'
    },
    'AWSALBTGCORS': {
      'cat': CookieCategory.functional,
      'prov': 'Amazon Web Services'
    },
    'AWSELB': {'cat': CookieCategory.functional, 'prov': 'Amazon Web Services'},
    'AWSELBCORS': {
      'cat': CookieCategory.functional,
      'prov': 'Amazon Web Services'
    },
    'ActionSetHistory': {'cat': CookieCategory.analytics, 'prov': 'Qualtrics'},
    'AdID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'AlteonP': {'cat': CookieCategory.functional, 'prov': 'Alteon'},
    'AnalyticsSyncHistory': {
      'cat': CookieCategory.analytics,
      'prov': 'LinkedIn'
    },
    'ApplicationGatewayAffinity': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'ApplicationGatewayAffinityCORS': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'BAYEAX_BROWSER': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'BCPermissionLevel': {
      'cat': CookieCategory.functional,
      'prov': 'Blueconic.com'
    },
    'BCReferrerOverrule': {
      'cat': CookieCategory.advertising,
      'prov': 'Blueconic.com'
    },
    'BCRefusedObjectives': {
      'cat': CookieCategory.advertising,
      'prov': 'Blueconic.com'
    },
    'BCRevision': {'cat': CookieCategory.advertising, 'prov': 'Blueconic.com'},
    'BCSessionID': {'cat': CookieCategory.advertising, 'prov': 'Blueconic.com'},
    'BCTempID': {'cat': CookieCategory.advertising, 'prov': 'Blueconic.com'},
    'BCTracking': {'cat': CookieCategory.advertising, 'prov': 'Blueconic.com'},
    'BFB': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'BFBUSR': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'BIGipServer': {'cat': CookieCategory.functional, 'prov': 'f5 BIG-IP'},
    'BLUEID': {'cat': CookieCategory.advertising, 'prov': 'Blue'},
    'BSWtracker': {'cat': CookieCategory.advertising, 'prov': 'vmg.host'},
    'BVBRANDID': {'cat': CookieCategory.analytics, 'prov': 'Bazaar Voice'},
    'BVBRANDSID': {'cat': CookieCategory.analytics, 'prov': 'Bazaar Voice'},
    'BVID': {'cat': CookieCategory.advertising, 'prov': 'Bazaar Voice'},
    'BVSID': {'cat': CookieCategory.advertising, 'prov': 'Bazaar Voice'},
    'BizographicsOptOut': {
      'cat': CookieCategory.advertising,
      'prov': 'LinkedIn'
    },
    'BlurTime': {'cat': CookieCategory.analytics, 'prov': 'Qualtrics'},
    'BrowserId': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'BrowserId_sec': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'C': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'CAID': {'cat': CookieCategory.advertising, 'prov': 'Command Act'},
    'CAKEPHP': {'cat': CookieCategory.functional, 'prov': 'CakePHP'},
    'CC': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'CFFC': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'CGIC': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'CGISESSID': {'cat': CookieCategory.functional, 'prov': 'Perl'},
    'CM': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'CMID': {'cat': CookieCategory.advertising, 'prov': 'Casale Media'},
    'CMPRO': {'cat': CookieCategory.advertising, 'prov': 'Casale Media'},
    'CMPS': {'cat': CookieCategory.advertising, 'prov': 'Casale Media'},
    'CMSCookieLevel': {'cat': CookieCategory.functional, 'prov': 'Kentico'},
    'CMSCsrfCookie': {'cat': CookieCategory.essential, 'prov': 'Kentico'},
    'CMSLandingPageLoaded': {
      'cat': CookieCategory.analytics,
      'prov': 'Kentico'
    },
    'CMSPreferredCulture': {
      'cat': CookieCategory.functional,
      'prov': 'Kentico'
    },
    'CMST': {'cat': CookieCategory.advertising, 'prov': 'Casale Media'},
    'CMSUserPage': {'cat': CookieCategory.analytics, 'prov': 'Kentico'},
    'COKENBLD': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'COMPASS': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'COOKIELAW': {'cat': CookieCategory.functional, 'prov': 'Lightspeed'},
    'COOKIELAW_ADS': {'cat': CookieCategory.functional, 'prov': 'Lightspeed'},
    'COOKIELAW_SOCIAL': {
      'cat': CookieCategory.functional,
      'prov': 'Lightspeed'
    },
    'COOKIELAW_STATS': {'cat': CookieCategory.functional, 'prov': 'Lightspeed'},
    'CPSessID': {'cat': CookieCategory.analytics, 'prov': 'Qualtrics'},
    'CRAFT_CSRF_TOKEN': {'cat': CookieCategory.essential, 'prov': 'CraftCMS'},
    'CT': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'CTK': {'cat': CookieCategory.analytics, 'prov': 'Indeed'},
    'CX_': {'cat': CookieCategory.functional, 'prov': 'SurveyMonkey'},
    'Cart': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'ClickAndChange': {'cat': CookieCategory.functional, 'prov': 'Jimdo'},
    'Comp': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'Conversion': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    'CookieConsentBulkSetting-': {
      'cat': CookieCategory.functional,
      'prov': 'Cookiebot'
    },
    'CookieConsentPolicy': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'CookieControl': {'cat': CookieCategory.functional, 'prov': 'Civic'},
    'CookieLawInfoConsent': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'CookieScriptConsent': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Script'
    },
    'CraftSessionId': {'cat': CookieCategory.functional, 'prov': 'CraftCMS'},
    'CurrentContact': {'cat': CookieCategory.analytics, 'prov': 'Kentico'},
    'DEVICE_INFO': {'cat': CookieCategory.functional, 'prov': 'Youtube'},
    'DG_HID': {'cat': CookieCategory.advertising, 'prov': 'Funda'},
    'DG_IID': {'cat': CookieCategory.advertising, 'prov': 'Funda'},
    'DG_SID': {'cat': CookieCategory.advertising, 'prov': 'Funda'},
    'DG_UID': {'cat': CookieCategory.advertising, 'prov': 'Funda'},
    'DG_ZID': {'cat': CookieCategory.advertising, 'prov': 'Funda'},
    'DG_ZUID': {'cat': CookieCategory.advertising, 'prov': 'Funda'},
    'DISPATCHER': {'cat': CookieCategory.advertising, 'prov': 'Adxcore'},
    'DLBCTLYOXA': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'DPFQ': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'DPPIX_ON': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'DPSync': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'DSP_UID': {
      'cat': CookieCategory.advertising,
      'prov': 'Fidelity-media.com'
    },
    'DV': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'DYID': {'cat': CookieCategory.functional, 'prov': 'Dynamic Yield'},
    'DYSES': {'cat': CookieCategory.functional, 'prov': 'Dynamic Yield'},
    'Datadome': {'cat': CookieCategory.functional, 'prov': 'Datadome'},
    'DcLcid': {'cat': CookieCategory.functional, 'prov': 'Microsoft Dynamics'},
    'DotMetrics.DeviceKey': {
      'cat': CookieCategory.analytics,
      'prov': 'Dotmetrics'
    },
    'DotMetrics.SessionCookieTemp': {
      'cat': CookieCategory.analytics,
      'prov': 'Dotmetrics'
    },
    'DotMetrics.SessionCookieTempTimed': {
      'cat': CookieCategory.analytics,
      'prov': 'Dotmetrics'
    },
    'DotMetrics.UniqueUserIdentityCookie': {
      'cat': CookieCategory.analytics,
      'prov': 'Dotmetrics'
    },
    'DotomiSession_': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'DotomiStatus': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'DotomiSync': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'DotomiUser': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'EBFC': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'EBFCD': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'EE': {'cat': CookieCategory.advertising, 'prov': 'Nielsen'},
    'FDLBCAMPAIGNCDOM': {
      'cat': CookieCategory.functional,
      'prov': 'Command Act'
    },
    'FDLBCTLY': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'FDLBFIRST': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'FDLBFIRSTAPI': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'FDLBFIRSTCAMPAIGN': {
      'cat': CookieCategory.functional,
      'prov': 'Command Act'
    },
    'FDLBFIRSTCAMPAIGNEF': {
      'cat': CookieCategory.functional,
      'prov': 'Command Act'
    },
    'FDLBFIRSTCMP': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'FDLBFIRSTDATA': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'FDLBFIRSTEVENTS': {
      'cat': CookieCategory.functional,
      'prov': 'Command Act'
    },
    'FDLBFIRSTTMS': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'FLC': {
      'cat': CookieCategory.advertising,
      'prov': 'DoubleClick/Google Marketing'
    },
    'FPAU': {'cat': CookieCategory.advertising, 'prov': 'Google Analytics'},
    'FPGCLAW': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    'FPGCLDC': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'FPGCLGB': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    'FPGSID': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'FPID': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    'FPLC': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    'FPtrust': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'FedAuth': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'FocusTime': {'cat': CookieCategory.analytics, 'prov': 'Qualtrics'},
    'ForceFlashSite': {'cat': CookieCategory.functional, 'prov': 'Wix.com'},
    'FunctionalCookie': {'cat': CookieCategory.functional, 'prov': 'OneTrust'},
    'GCLB': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'GCM': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'GED_PLAYLIST_ACTIVITY': {
      'cat': CookieCategory.advertising,
      'prov': 'Google AdSense'
    },
    'GN_PREF': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'GPS': {'cat': CookieCategory.advertising, 'prov': 'Youtube'},
    'GRV_BHV_BRND_': {'cat': CookieCategory.advertising, 'prov': 'Groovinads'},
    'GRV_BHV_DATE': {'cat': CookieCategory.advertising, 'prov': 'Groovinads'},
    'GRV_BHV_IDCAT': {'cat': CookieCategory.advertising, 'prov': 'Groovinads'},
    'GRV_BHV_IDCC': {'cat': CookieCategory.advertising, 'prov': 'Groovinads'},
    'GRV_BHV_SKU': {'cat': CookieCategory.advertising, 'prov': 'Groovinads'},
    'GRV_BHV_UID': {'cat': CookieCategory.advertising, 'prov': 'Groovinads'},
    'GRV_IDU': {'cat': CookieCategory.advertising, 'prov': 'Groovinads'},
    'GRV_google': {'cat': CookieCategory.advertising, 'prov': 'Groovinads'},
    'GSLM_': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'GUC': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'G_AUTHUSER_H': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'Gdyn': {'cat': CookieCategory.analytics, 'prov': 'Gemius'},
    'GeoIP': {'cat': CookieCategory.analytics, 'prov': 'Wikimedia'},
    'GoogleAdServingTest': {
      'cat': CookieCategory.advertising,
      'prov': 'DoubleClick/Google Marketing'
    },
    'HAAPPLB': {'cat': CookieCategory.functional, 'prov': 'Civic'},
    'HACIVIC': {'cat': CookieCategory.functional, 'prov': 'Civic'},
    'HACIVICLB': {'cat': CookieCategory.functional, 'prov': 'Civic'},
    'HMACCOUNT': {'cat': CookieCategory.analytics, 'prov': 'Baidu'},
    'Hm_lpvt_': {'cat': CookieCategory.analytics, 'prov': 'Baidu'},
    'Hm_lvt_': {'cat': CookieCategory.analytics, 'prov': 'Baidu'},
    'Host-ERIC_PROD-': {'cat': CookieCategory.essential, 'prov': 'Salesforce'},
    'ID': {
      'cat': CookieCategory.advertising,
      'prov': 'DoubleClick/Google Marketing'
    },
    'IDSYNC': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'IMRID': {'cat': CookieCategory.advertising, 'prov': 'Nielsen'},
    'INDEED_CSRF_TOKEN': {'cat': CookieCategory.essential, 'prov': 'Indeed'},
    'INGRESSCOOKIE': {
      'cat': CookieCategory.functional,
      'prov': 'NGINX Ingresss'
    },
    'IRLD': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'JSESSIO': {'cat': CookieCategory.functional, 'prov': 'Oracle'},
    'KADUSERCOOKIE': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'KCCH': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'KC_AUTH_STATE': {'cat': CookieCategory.functional, 'prov': 'Keycloak'},
    'KC_RESTART': {'cat': CookieCategory.functional, 'prov': 'Keycloak'},
    'KC_START': {'cat': CookieCategory.functional, 'prov': 'Keycloak'},
    'KC_STATE_CHECKER': {'cat': CookieCategory.functional, 'prov': 'Keycloak'},
    'KEYCLOAK_IDENTITY': {'cat': CookieCategory.functional, 'prov': 'Keycloak'},
    'KEYCLOAK_LOCALE': {'cat': CookieCategory.functional, 'prov': 'Keycloak'},
    'KEYCLOAK_REMEMBER_ME': {
      'cat': CookieCategory.functional,
      'prov': 'Keycloak'
    },
    'KEYCLOAK_SESSION': {'cat': CookieCategory.functional, 'prov': 'Keycloak'},
    'KRTBCOOKIE_': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'KTPCACOOKIE': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'KelkooID': {'cat': CookieCategory.advertising, 'prov': 'Kelkoo'},
    'KievRPSAuth': {
      'cat': CookieCategory.functional,
      'prov': 'Bing / Microsoft'
    },
    'Kiyohnl': {'cat': CookieCategory.functional, 'prov': 'Kiyoh'},
    'LANG': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    'LANG_CHANGED': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    'LOGIN_INFO': {'cat': CookieCategory.functional, 'prov': 'Youtube'},
    'LSID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'LSOLH': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'MC0': {'cat': CookieCategory.functional, 'prov': 'Bing / Microsoft'},
    'MH': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'MONITOR_WEB_ID': {'cat': CookieCategory.advertising, 'prov': 'TikTok'},
    'MRM_UID': {'cat': CookieCategory.advertising, 'prov': 'FreeWheel'},
    'MS0': {'cat': CookieCategory.functional, 'prov': 'Bing / Microsoft'},
    'MSFPC': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'MSNRPSAuth': {
      'cat': CookieCategory.functional,
      'prov': 'Bing / Microsoft'
    },
    'MSO': {'cat': CookieCategory.functional, 'prov': 'Microsoft'},
    'MSPAuth': {'cat': CookieCategory.functional, 'prov': 'Bing / Microsoft'},
    'MSPProf': {'cat': CookieCategory.functional, 'prov': 'Bing / Microsoft'},
    'MSPTC': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'MicrosoftApplicationsTelemetryDeviceId': {
      'cat': CookieCategory.analytics,
      'prov': 'Microsoft'
    },
    'NAP': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'NEXT_LOCALE': {'cat': CookieCategory.functional, 'prov': 'Next'},
    'NOPCOMMERCE.AUTH': {
      'cat': CookieCategory.functional,
      'prov': 'nopCommerce'
    },
    'NPA': {'cat': CookieCategory.advertising, 'prov': 'Groovinads'},
    'NSC_': {'cat': CookieCategory.functional, 'prov': 'Citrix'},
    'NetWorkProbeLimit': {'cat': CookieCategory.analytics, 'prov': 'Wikimedia'},
    'Nop.customer': {'cat': CookieCategory.functional, 'prov': 'nopCommerce'},
    'NopCommerce.RecentlyViewedProducts': {
      'cat': CookieCategory.functional,
      'prov': 'nopCommerce'
    },
    'OAGEO': {'cat': CookieCategory.advertising, 'prov': 'openx.net'},
    'OAID': {'cat': CookieCategory.advertising, 'prov': 'openx.net'},
    'OGP': {'cat': CookieCategory.advertising, 'prov': 'Google Maps'},
    'OGPC': {'cat': CookieCategory.advertising, 'prov': 'Google Maps'},
    'OID': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'OIDI': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'OIDR': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'ORA_WWV_APP_': {'cat': CookieCategory.functional, 'prov': 'Oracle'},
    'OSID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'OTH': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'OTZ': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'OneTrustWPCCPAGoogleOptOut': {
      'cat': CookieCategory.functional,
      'prov': 'OneTrust'
    },
    'OptanonControl': {'cat': CookieCategory.functional, 'prov': 'OneTrust'},
    'PAIDCONTENT': {
      'cat': CookieCategory.advertising,
      'prov': 'Google Surveys'
    },
    'PID': {'cat': CookieCategory.advertising, 'prov': 'ComScore'},
    'PLAY_FLASH': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'PLAY_LANG': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'PLAY_SESSION': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'PLESKSESSID': {'cat': CookieCategory.functional, 'prov': 'Plesk'},
    'PMDTSHR': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'PMFREQ_ON': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'PPAuth': {'cat': CookieCategory.functional, 'prov': 'Bing / Microsoft'},
    'PUBMDCID': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'PUBRETARGET': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'PUBUIDSYNCUPFQ': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'P_': {'cat': CookieCategory.functional, 'prov': 'SurveyMonkey'},
    'PageReferrer': {'cat': CookieCategory.analytics, 'prov': 'Qualtrics'},
    'Pastease.passive.activated': {
      'cat': CookieCategory.analytics,
      'prov': 'Mopinion.com'
    },
    'Pastease.passive.chance': {
      'cat': CookieCategory.analytics,
      'prov': 'Mopinion.com'
    },
    'Pdomid': {'cat': CookieCategory.functional, 'prov': 'Smartadserver'},
    'Player': {'cat': CookieCategory.functional, 'prov': 'Vimeo'},
    'PreferredLanguage': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'PugT': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'Pwb': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'QCQQ': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'QSIPopUnder_PopUnderTarget_SI_': {
      'cat': CookieCategory.functional,
      'prov': 'Qualtrics'
    },
    'QSI_CT': {'cat': CookieCategory.functional, 'prov': 'Qualtrics'},
    'QSI_DATA': {'cat': CookieCategory.functional, 'prov': 'Qualtrics'},
    'QSI_HistorySession': {
      'cat': CookieCategory.analytics,
      'prov': 'Qualtrics'
    },
    'QSI_OptInIDsAndTargetOrigins': {
      'cat': CookieCategory.analytics,
      'prov': 'Qualtrics'
    },
    'QSI_OptInIDsAndWindowNames': {
      'cat': CookieCategory.analytics,
      'prov': 'Qualtrics'
    },
    'QSI_ReplaySession_Info_': {
      'cat': CookieCategory.analytics,
      'prov': 'Qualtrics'
    },
    'QSI_ReplaySession_SampledOut_': {
      'cat': CookieCategory.functional,
      'prov': 'Qualtrics'
    },
    'QSI_ReplaySession_Throttled_': {
      'cat': CookieCategory.functional,
      'prov': 'Qualtrics'
    },
    'QSI_SI_': {'cat': CookieCategory.analytics, 'prov': 'Qualtrics'},
    'QSI_S_': {'cat': CookieCategory.functional, 'prov': 'Qualtrics'},
    'QSI_TestSessions_': {'cat': CookieCategory.analytics, 'prov': 'Qualtrics'},
    'QST': {'cat': CookieCategory.functional, 'prov': 'Qualtrics'},
    'REPID_': {'cat': CookieCategory.functional, 'prov': 'SurveyMonkey'},
    'RE_': {'cat': CookieCategory.functional, 'prov': 'SurveyMonkey'},
    'RP_': {'cat': CookieCategory.functional, 'prov': 'SurveyMonkey'},
    'RRetURL': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'RT': {'cat': CookieCategory.functional, 'prov': 'Tripadvisor'},
    'RUL': {
      'cat': CookieCategory.advertising,
      'prov': 'DoubleClick/Google Marketing'
    },
    'RpsContextCookie': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'SAML_': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'SCM': {'cat': CookieCategory.advertising, 'prov': 'Smaato'},
    'SCMaps': {'cat': CookieCategory.advertising, 'prov': 'Smaato'},
    'SCMg': {'cat': CookieCategory.advertising, 'prov': 'Smaato'},
    'SCMinf': {'cat': CookieCategory.advertising, 'prov': 'Smaato'},
    'SCMo': {'cat': CookieCategory.advertising, 'prov': 'Smaato'},
    'SCMsovrn': {'cat': CookieCategory.advertising, 'prov': 'Smaato'},
    'SEARCH_SAMESITE': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'SERVERID': {'cat': CookieCategory.functional, 'prov': 'HAproxy'},
    'SEUNCY': {'cat': CookieCategory.advertising, 'prov': 'semasio.net'},
    'SIDCC': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'SISessID': {'cat': CookieCategory.analytics, 'prov': 'Qualtrics'},
    'SMSV': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'SNID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'SPugT': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'SR': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'SRM_B': {'cat': CookieCategory.functional, 'prov': 'Bing / Microsoft'},
    'SSPV': {'cat': CookieCategory.functional, 'prov': 'SiteSpect'},
    'SSPZ': {'cat': CookieCategory.advertising, 'prov': 'Adkernel'},
    'SSR-caching': {'cat': CookieCategory.functional, 'prov': 'Wix.com'},
    'SSRT': {'cat': CookieCategory.functional, 'prov': 'SiteSpect'},
    'SSSC': {'cat': CookieCategory.functional, 'prov': 'SiteSpect'},
    'SUCSP': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'SUPRM': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'SYNCUPPIX_ON': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'SearchTerm': {'cat': CookieCategory.analytics, 'prov': 'Qualtrics'},
    'Secret': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'Secure-YEC': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'SecureSessionID-': {'cat': CookieCategory.functional, 'prov': 'Intershop'},
    'Secure_customer_sig': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'ServerPool': {'cat': CookieCategory.advertising, 'prov': 'Tripadvisor'},
    'SetupDomainProbePassed': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'SiteReferrer': {'cat': CookieCategory.analytics, 'prov': 'Qualtrics'},
    'SnapABugHistory': {
      'cat': CookieCategory.advertising,
      'prov': 'SnapEngage'
    },
    'SnapABugRef': {'cat': CookieCategory.advertising, 'prov': 'SnapEngage'},
    'SnapABugUserAlias': {
      'cat': CookieCategory.functional,
      'prov': 'SnapEngage'
    },
    'SnapABugVisit': {'cat': CookieCategory.functional, 'prov': 'SnapEngage'},
    'SyncRTB': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'TADCID': {'cat': CookieCategory.advertising, 'prov': 'Tripadvisor'},
    'TAID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'TAReturnTo': {'cat': CookieCategory.analytics, 'prov': 'Tripadvisor'},
    'TATravelInfo': {'cat': CookieCategory.analytics, 'prov': 'Tripadvisor'},
    'TAUnique': {'cat': CookieCategory.analytics, 'prov': 'Tripadvisor'},
    'TCAUDIENCE': {'cat': CookieCategory.analytics, 'prov': 'Command Act'},
    'TCID': {'cat': CookieCategory.advertising, 'prov': 'Command Act'},
    'TCIPD': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'TCLANDINGURL': {'cat': CookieCategory.advertising, 'prov': 'Command Act'},
    'TCREDIRECT': {'cat': CookieCategory.advertising, 'prov': 'Command Act'},
    'TCREDIRECT_DEDUP': {
      'cat': CookieCategory.advertising,
      'prov': 'Command Act'
    },
    'TCSESSION': {'cat': CookieCategory.advertising, 'prov': 'Command Act'},
    'TC_CHECK_COOKIES_SUPPORT': {
      'cat': CookieCategory.functional,
      'prov': 'Command Act'
    },
    'TC_OUTPUT': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'TC_OUTPUT_categories': {
      'cat': CookieCategory.functional,
      'prov': 'Command Act'
    },
    'TC_PRIVACY_CENTER': {
      'cat': CookieCategory.functional,
      'prov': 'Command Act'
    },
    'TMS': {'cat': CookieCategory.advertising, 'prov': 'Command Act'},
    'TPC': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'TXCD': {'cat': CookieCategory.advertising, 'prov': 'Tappx'},
    'TXCSDMN_': {'cat': CookieCategory.advertising, 'prov': 'Tappx'},
    'TapAd_DID': {'cat': CookieCategory.advertising, 'prov': 'Tapad'},
    'TapAd_TS': {'cat': CookieCategory.advertising, 'prov': 'Tapad'},
    'TawkConnectionTime': {
      'cat': CookieCategory.functional,
      'prov': 'Tawk.to Chat'
    },
    'TawkCookie': {'cat': CookieCategory.functional, 'prov': 'Tawk.to Chat'},
    'TestIfCookie': {
      'cat': CookieCategory.advertising,
      'prov': 'Smartadserver'
    },
    'TestIfCookieP': {
      'cat': CookieCategory.advertising,
      'prov': 'Smartadserver'
    },
    'ToptOut': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'UID': {'cat': CookieCategory.advertising, 'prov': 'ComScore'},
    'UIDR': {'cat': CookieCategory.advertising, 'prov': 'ComScore'},
    'USCC': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'UTID': {'cat': CookieCategory.advertising, 'prov': 'Undertone'},
    'UTID_ENC': {'cat': CookieCategory.advertising, 'prov': 'Undertone'},
    'UULE': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'VID': {'cat': CookieCategory.analytics, 'prov': 'LinkedIn'},
    'VISITOR_PRIVACY_METADATA': {
      'cat': CookieCategory.advertising,
      'prov': 'Youtube'
    },
    'VfAccess': {'cat': CookieCategory.functional, 'prov': 'Viafoura'},
    'VfRefresh': {'cat': CookieCategory.functional, 'prov': 'Viafoura'},
    'VfSess': {'cat': CookieCategory.functional, 'prov': 'Viafoura'},
    'VisitorStatus': {'cat': CookieCategory.analytics, 'prov': 'Kentico'},
    'VisitorStorageGuid': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'WID': {'cat': CookieCategory.advertising, 'prov': 'Command Act'},
    'WLSSC': {'cat': CookieCategory.functional, 'prov': 'Bing / Microsoft'},
    'WMF-Last-Access': {'cat': CookieCategory.analytics, 'prov': 'Wikimedia'},
    'WRBlock': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    'WRIgnore': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    'WRUID': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    'WelcomePanel': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'X-AB': {'cat': CookieCategory.functional, 'prov': 'Snapchat'},
    'X-FD-FEATURES': {'cat': CookieCategory.analytics, 'prov': 'Microsoft'},
    'X-FD-Time': {'cat': CookieCategory.analytics, 'prov': 'Microsoft'},
    'X-Magento-Vary': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'X-PP-SILOVER': {'cat': CookieCategory.functional, 'prov': 'PayPal'},
    'XANDR_PANID': {'cat': CookieCategory.advertising, 'prov': 'Xandr'},
    'XID': {'cat': CookieCategory.advertising, 'prov': 'ComScore'},
    'ZCAMPAIGN_CSRF_TOKEN': {'cat': CookieCategory.essential, 'prov': 'ZOHO'},
    'ZD-buid': {'cat': CookieCategory.analytics, 'prov': 'Zendesk'},
    'ZD-launcherLabelRemoved': {
      'cat': CookieCategory.functional,
      'prov': 'Zendesk'
    },
    'ZD-settings': {'cat': CookieCategory.functional, 'prov': 'Zendesk'},
    'ZD-store': {'cat': CookieCategory.functional, 'prov': 'Zendesk'},
    'ZD-suid': {'cat': CookieCategory.analytics, 'prov': 'Zendesk'},
    'ZD-widgetOpen': {'cat': CookieCategory.functional, 'prov': 'Zendesk'},
    'ZD-zE_oauth': {'cat': CookieCategory.functional, 'prov': 'Zendesk'},
    '_ALGOLIA': {'cat': CookieCategory.analytics, 'prov': 'Algolia'},
    '_BEAMER_DATE_': {'cat': CookieCategory.advertising, 'prov': 'Beamer'},
    '_BEAMER_FILTER_BY_URL_': {
      'cat': CookieCategory.advertising,
      'prov': 'Beamer'
    },
    '_BEAMER_FIRST_VISIT_': {
      'cat': CookieCategory.advertising,
      'prov': 'Beamer'
    },
    '_BEAMER_LAST_POST_SHOWN_': {
      'cat': CookieCategory.advertising,
      'prov': 'Beamer'
    },
    '_BEAMER_USER_ID_': {'cat': CookieCategory.advertising, 'prov': 'Beamer'},
    '_Brochure_session': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_CEFT': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    '_CT_RS_': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_HPVN': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    '_KMPage': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    '_KnowledgePageDispatcher': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_KnowledgePageFilter': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_KnowledgePageFilterArticleArticleType': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_KnowledgePageFilterArticlePublishStatus': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_KnowledgePageFilterArticleValidationStatus': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_KnowledgePageFilterLanguage': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_KnowledgePageFilterMyDraftArticleType': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_KnowledgePageFilterMyDraftPublishStatus': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_KnowledgePageFilterMyDraftValidationStatus': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_KnowledgePageSortFieldArticle': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_KnowledgePageSortFieldMyDraft': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_RwBf': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    '_SUPERFLY_nosample': {
      'cat': CookieCategory.analytics,
      'prov': 'Chartbeat'
    },
    '_Secure-ENID': {'cat': CookieCategory.functional, 'prov': 'Google'},
    '_Secure-YEC': {'cat': CookieCategory.functional, 'prov': 'Google'},
    '_TCCookieSync': {'cat': CookieCategory.analytics, 'prov': 'Command Act'},
    '_UR': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    '__AntiXsrfToken': {
      'cat': CookieCategory.essential,
      'prov': 'Azure / Microsoft'
    },
    '__CT_Data': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '__Host-ERIC_PROD-': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '__Host-GAPS': {'cat': CookieCategory.functional, 'prov': 'Google'},
    '__Host-gist_user_session_same_site': {
      'cat': CookieCategory.functional,
      'prov': 'GitHub'
    },
    '__Host-next-auth.csrf-token': {
      'cat': CookieCategory.functional,
      'prov': 'NextAuth.js'
    },
    '__Host-user_session_same_site': {
      'cat': CookieCategory.functional,
      'prov': 'GitHub'
    },
    '__RequestVerificationToken': {
      'cat': CookieCategory.functional,
      'prov': 'Microsoft'
    },
    '__Secure-ENID': {'cat': CookieCategory.functional, 'prov': 'Google'},
    '__Secure-OSID': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    '__Secure-ROLLOUT_TOKEN': {
      'cat': CookieCategory.advertising,
      'prov': 'Youtube'
    },
    '__Secure-YNID': {'cat': CookieCategory.functional, 'prov': 'Google'},
    '__Secure-fgpt': {'cat': CookieCategory.functional, 'prov': 'OneTrust'},
    '__Secure-next-auth.callback-url': {
      'cat': CookieCategory.functional,
      'prov': 'NextAuth.js'
    },
    '___m_rec': {'cat': CookieCategory.analytics, 'prov': 'Marfeel'},
    '__adal_ca': {'cat': CookieCategory.advertising, 'prov': 'Adalyser.com'},
    '__adal_cw': {'cat': CookieCategory.advertising, 'prov': 'Adalyser.com'},
    '__adal_id': {'cat': CookieCategory.advertising, 'prov': 'Adalyser.com'},
    '__adal_ses': {'cat': CookieCategory.advertising, 'prov': 'Adalyser.com'},
    '__adm_ui': {'cat': CookieCategory.advertising, 'prov': 'Admatic'},
    '__adm_uiex': {'cat': CookieCategory.advertising, 'prov': 'Admatic'},
    '__adm_usyncc': {'cat': CookieCategory.advertising, 'prov': 'Admatic'},
    '__asc': {'cat': CookieCategory.analytics, 'prov': 'Trustpilot'},
    '__auc': {'cat': CookieCategory.analytics, 'prov': 'Trustpilot'},
    '__bid': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__cfduid': {'cat': CookieCategory.functional, 'prov': 'Cloudflare'},
    '__cfruid': {'cat': CookieCategory.functional, 'prov': 'Cloudflare'},
    '__cfseq': {'cat': CookieCategory.functional, 'prov': 'Cloudflare'},
    '__cfwaitingroom': {'cat': CookieCategory.functional, 'prov': 'CloudFlare'},
    '__cmpQQ_CookieConsent': {
      'cat': CookieCategory.essential,
      'prov': 'QookieQloud'
    },
    '__cmpQQ_consentID': {
      'cat': CookieCategory.essential,
      'prov': 'QookieQloud'
    },
    '__cmpQQ_usedCoookies': {
      'cat': CookieCategory.essential,
      'prov': 'QookieQloud'
    },
    '__cmpcc': {'cat': CookieCategory.functional, 'prov': 'Consentmanager.net'},
    '__cmpccc': {
      'cat': CookieCategory.functional,
      'prov': 'Consentmanager.net'
    },
    '__cmpccpausps': {
      'cat': CookieCategory.functional,
      'prov': 'Consentmanager.net'
    },
    '__cmpccx': {
      'cat': CookieCategory.functional,
      'prov': 'Consentmanager.net'
    },
    '__cmpconsent': {
      'cat': CookieCategory.functional,
      'prov': 'Consentmanager.net'
    },
    '__cmpcpc': {
      'cat': CookieCategory.functional,
      'prov': 'Consentmanager.net'
    },
    '__cmpcvc': {
      'cat': CookieCategory.functional,
      'prov': 'Consentmanager.net'
    },
    '__cmpfcc': {
      'cat': CookieCategory.functional,
      'prov': 'Consentmanager.net'
    },
    '__cmpiab': {
      'cat': CookieCategory.functional,
      'prov': 'Consentmanager.net'
    },
    '__cmpiuid': {
      'cat': CookieCategory.functional,
      'prov': 'Consentmanager.net'
    },
    '__cmpld': {'cat': CookieCategory.functional, 'prov': 'Consentmanager.net'},
    '__cmpwel': {
      'cat': CookieCategory.functional,
      'prov': 'Consentmanager.net'
    },
    '__code': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__cpmQQ_trackers': {
      'cat': CookieCategory.essential,
      'prov': 'QookieQloud'
    },
    '__cpmQQ_trackers_timestamp': {
      'cat': CookieCategory.essential,
      'prov': 'QookieQloud'
    },
    '__editor_layout': {'cat': CookieCategory.functional, 'prov': 'Codepen'},
    '__eea': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__exponea_etc__': {'cat': CookieCategory.advertising, 'prov': 'Exponea'},
    '__gpi_optout': {
      'cat': CookieCategory.advertising,
      'prov': 'Google AdSense'
    },
    '__hs_cookie_cat_pref': {
      'cat': CookieCategory.functional,
      'prov': 'HubSpot'
    },
    '__hs_do_not_track': {'cat': CookieCategory.functional, 'prov': 'Hubspot'},
    '__hs_gpc_banner_dismiss': {
      'cat': CookieCategory.functional,
      'prov': 'HubSpot'
    },
    '__hs_initial_opt_in': {
      'cat': CookieCategory.functional,
      'prov': 'Hubspot'
    },
    '__hs_notify_banner_dismiss': {
      'cat': CookieCategory.functional,
      'prov': 'HubSpot'
    },
    '__hs_opt_out': {'cat': CookieCategory.functional, 'prov': 'Hubspot'},
    '__hsmem': {'cat': CookieCategory.functional, 'prov': 'Hubspot'},
    '__idr': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__insp_dct': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__insp_norec_sess': {
      'cat': CookieCategory.analytics,
      'prov': 'Inspectlet'
    },
    '__insp_nv': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__insp_pad': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__insp_ref': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__insp_scpt': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__insp_sid': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__insp_slim': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__insp_targlpt': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__insp_targlpu': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__insp_uid': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__insp_wid': {'cat': CookieCategory.analytics, 'prov': 'Inspectlet'},
    '__kla_id': {'cat': CookieCategory.advertising, 'prov': 'Klaviyo'},
    '__lc_cid': {'cat': CookieCategory.functional, 'prov': 'Livechat'},
    '__lc_cst': {'cat': CookieCategory.functional, 'prov': 'Livechat'},
    '__livechat': {'cat': CookieCategory.functional, 'prov': 'Livechat'},
    '__lotl': {'cat': CookieCategory.analytics, 'prov': 'Lucky Orange'},
    '__lotr': {'cat': CookieCategory.analytics, 'prov': 'Lucky Orange'},
    '__pat': {'cat': CookieCategory.analytics, 'prov': 'Piano'},
    '__pid': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__pil': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__pls': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__pnahc': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__pvi': {'cat': CookieCategory.analytics, 'prov': 'Piano'},
    '__sqra': {'cat': CookieCategory.functional, 'prov': 'Sooqr'},
    '__sqrb': {'cat': CookieCategory.functional, 'prov': 'Sooqr'},
    '__sqrc': {'cat': CookieCategory.functional, 'prov': 'Sooqr'},
    '__ss': {'cat': CookieCategory.advertising, 'prov': 'Sharpspring'},
    '__ss_referrer': {'cat': CookieCategory.advertising, 'prov': 'Sharpspring'},
    '__ss_tk': {'cat': CookieCategory.advertising, 'prov': 'Sharpspring'},
    '__stid': {'cat': CookieCategory.analytics, 'prov': 'ShareThis'},
    '__stidv': {'cat': CookieCategory.advertising, 'prov': 'ShareThis'},
    '__stripe_mid': {'cat': CookieCategory.functional, 'prov': 'Stripe'},
    '__stripe_sid': {'cat': CookieCategory.functional, 'prov': 'Stripe'},
    '__tac': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__tawkuuid': {'cat': CookieCategory.functional, 'prov': 'Tawk.to Chat'},
    '__tlbcpv': {'cat': CookieCategory.functional, 'prov': 'Termly'},
    '__tltpl_': {'cat': CookieCategory.functional, 'prov': 'Termly'},
    '__tluid': {'cat': CookieCategory.functional, 'prov': 'Termly'},
    '__trf.src': {'cat': CookieCategory.advertising, 'prov': 'Amazon'},
    '__txn_': {'cat': CookieCategory.functional, 'prov': 'Auth0'},
    '__uin_bw': {'cat': CookieCategory.advertising, 'prov': 'Sonobi'},
    '__uin_mm': {'cat': CookieCategory.advertising, 'prov': 'Sonobi'},
    '__uin_rh': {'cat': CookieCategory.advertising, 'prov': 'Sonobi'},
    '__uir_bw': {'cat': CookieCategory.advertising, 'prov': 'Sonobi'},
    '__uir_mm': {'cat': CookieCategory.advertising, 'prov': 'Sonobi'},
    '__uir_rh': {'cat': CookieCategory.advertising, 'prov': 'Sonobi'},
    '__uis': {'cat': CookieCategory.advertising, 'prov': 'Sonobi'},
    '__ut': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__utmv': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmx': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utmxx': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '__utp': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    '__zlcmid': {'cat': CookieCategory.functional, 'prov': 'Zendesk'},
    '__zlcprivacy': {'cat': CookieCategory.functional, 'prov': 'Zendesk'},
    '_ab': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    '_answer_bot_service_session': {
      'cat': CookieCategory.functional,
      'prov': 'Zendesk'
    },
    '_bit': {'cat': CookieCategory.analytics, 'prov': 'Bit.ly'},
    '_biz_ABTestA': {'cat': CookieCategory.analytics, 'prov': 'Marketo'},
    '_biz_EventA': {'cat': CookieCategory.analytics, 'prov': 'Marketo'},
    '_biz_flagsA': {'cat': CookieCategory.analytics, 'prov': 'Marketo'},
    '_biz_nA': {'cat': CookieCategory.analytics, 'prov': 'Marketo'},
    '_biz_pendingA': {'cat': CookieCategory.analytics, 'prov': 'Marketo'},
    '_biz_su': {'cat': CookieCategory.analytics, 'prov': 'Marketo'},
    '_biz_uid': {'cat': CookieCategory.analytics, 'prov': 'Marketo'},
    '_cc_aud': {'cat': CookieCategory.advertising, 'prov': 'Lotame'},
    '_cc_domain': {'cat': CookieCategory.advertising, 'prov': 'Lotame'},
    '_ce.cch': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    '_ce.clock_data': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    '_ce.clock_event': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    '_ce.gtld': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    '_ce.irv': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    '_ce.s': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    '_ceir': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    '_cer.v': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    '_chartbeat': {'cat': CookieCategory.analytics, 'prov': 'Chartbeat'},
    '_cio': {'cat': CookieCategory.advertising, 'prov': 'Customer.io'},
    '_cioanonid': {'cat': CookieCategory.advertising, 'prov': 'Customer.io'},
    '_cioid': {'cat': CookieCategory.advertising, 'prov': 'Customer.io'},
    '_cmp_a': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    '_conv_r': {'cat': CookieCategory.functional, 'prov': 'Convert Insights'},
    '_conv_s': {'cat': CookieCategory.functional, 'prov': 'Convert Insights'},
    '_conv_v': {'cat': CookieCategory.functional, 'prov': 'Convert Insights'},
    '_cq_duid': {
      'cat': CookieCategory.functional,
      'prov': 'CHEQ AI Technologies'
    },
    '_cq_suid': {
      'cat': CookieCategory.functional,
      'prov': 'CHEQ AI Technologies'
    },
    '_crazyegg': {'cat': CookieCategory.advertising, 'prov': 'Crazy Egg'},
    '_cs_cvars': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_cs_debug': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_cs_ex': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_cs_id': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_cs_mk_aa': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_cs_mk_ga': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_cs_optout': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_cs_rl': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_cs_root-domain': {
      'cat': CookieCategory.analytics,
      'prov': 'ContentSquare'
    },
    '_cs_s': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_cs_same_site': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_cs_tld': {'cat': CookieCategory.analytics, 'prov': 'ContentSquare'},
    '_csrf': {'cat': CookieCategory.essential, 'prov': 'Stonly'},
    '_curtime': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    '_customer_account_shop_sessions': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    '_dbefe': {'cat': CookieCategory.advertising, 'prov': 'Pulsepoint'},
    '_dc_gtm_': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_dcid': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    '_derived_epik': {'cat': CookieCategory.advertising, 'prov': 'Pinterest'},
    '_device_id': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    '_distillery': {'cat': CookieCategory.functional, 'prov': 'Wistia'},
    '_dp': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Audience Manager'
    },
    '_dsp_uid': {'cat': CookieCategory.advertising, 'prov': 'Bidence'},
    '_dy_cs_cookie_items': {
      'cat': CookieCategory.advertising,
      'prov': 'Dynamic Yield'
    },
    '_dy_cs_storage_items': {
      'cat': CookieCategory.advertising,
      'prov': 'Dynamic Yield'
    },
    '_dy_csc_ses': {'cat': CookieCategory.analytics, 'prov': 'Dynamic Yield'},
    '_dy_df_geo': {'cat': CookieCategory.analytics, 'prov': 'Dynamic Yield'},
    '_dy_geo': {'cat': CookieCategory.analytics, 'prov': 'Dynamic Yield'},
    '_dy_lu_ses': {'cat': CookieCategory.functional, 'prov': 'Dynamic Yield'},
    '_dy_ses_load_seq': {
      'cat': CookieCategory.functional,
      'prov': 'Dynamic Yield'
    },
    '_dy_soct': {'cat': CookieCategory.functional, 'prov': 'Dynamic Yield'},
    '_dy_toffset': {'cat': CookieCategory.functional, 'prov': 'Dynamic Yield'},
    '_dycmc': {'cat': CookieCategory.analytics, 'prov': 'Dynamic Yield'},
    '_dycnst': {'cat': CookieCategory.functional, 'prov': 'Dynamic Yield'},
    '_dycst': {'cat': CookieCategory.analytics, 'prov': 'Dynamic Yield'},
    '_dyid': {'cat': CookieCategory.functional, 'prov': 'Dynamic Yield'},
    '_dyid_server': {'cat': CookieCategory.functional, 'prov': 'Dynamic Yield'},
    '_dyjsession': {'cat': CookieCategory.functional, 'prov': 'Dynamic Yield'},
    '_epik': {'cat': CookieCategory.advertising, 'prov': 'Pinterest'},
    '_flowbox': {'cat': CookieCategory.functional, 'prov': 'Flowbox'},
    '_form_fields': {'cat': CookieCategory.functional, 'prov': 'RD Station'},
    '_gac_': {'cat': CookieCategory.advertising, 'prov': 'Google Analytics'},
    '_gac_gb_': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    '_gaexp': {'cat': CookieCategory.functional, 'prov': 'Google Optimize'},
    '_gaexp_rc': {'cat': CookieCategory.analytics, 'prov': 'Google Optimize'},
    '_gali': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_gat_gtag_': {'cat': CookieCategory.analytics, 'prov': 'Google Analytics'},
    '_gat_pro': {'cat': CookieCategory.functional, 'prov': 'Snapwidget'},
    '_gcl_aw': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    '_gcl_dc': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    '_gcl_gb': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    '_gcl_gf': {'cat': CookieCategory.advertising, 'prov': 'Google Flights'},
    '_gcl_gs': {'cat': CookieCategory.advertising, 'prov': 'Google Ads'},
    '_gcl_ha': {'cat': CookieCategory.advertising, 'prov': 'Google Hotel Ads'},
    '_gh_ent': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    '_gh_sess': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    '_gigRefUid_': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    '_gig_': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    '_gig_APIProxy_enabled': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    '_gig_email': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    '_gig_llp': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    '_gig_llu': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    '_gig_lt': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    '_gig_shareUI_cb_': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    '_gig_shareUI_lastUID': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    '_global_lucky_opt_out': {
      'cat': CookieCategory.functional,
      'prov': 'Lucky Orange'
    },
    '_gtmeec': {'cat': CookieCategory.advertising, 'prov': 'Stape'},
    '_guid': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    '_help_center_session': {
      'cat': CookieCategory.functional,
      'prov': 'Zendesk'
    },
    '_hjCachedUserAttributes': {
      'cat': CookieCategory.analytics,
      'prov': 'Hotjar'
    },
    '_hjClosedSurveyInvites': {
      'cat': CookieCategory.analytics,
      'prov': 'Hotjar'
    },
    '_hjCookieTest': {'cat': CookieCategory.functional, 'prov': 'Hotjar'},
    '_hjDonePolls': {'cat': CookieCategory.analytics, 'prov': 'Hotjar'},
    '_hjDoneTestersWidgets': {
      'cat': CookieCategory.analytics,
      'prov': 'Hotjar'
    },
    '_hjHasCachedUserAttributes': {
      'cat': CookieCategory.analytics,
      'prov': 'Hotjar'
    },
    '_hjIncludedInPageviewSample': {
      'cat': CookieCategory.functional,
      'prov': 'Hotjar'
    },
    '_hjIncludedInSessionSample': {
      'cat': CookieCategory.functional,
      'prov': 'Hotjar'
    },
    '_hjLocalStorageTest': {'cat': CookieCategory.functional, 'prov': 'Hotjar'},
    '_hjMinimizedPolls': {'cat': CookieCategory.analytics, 'prov': 'Hotjar'},
    '_hjMinimizedTestersWidgets': {
      'cat': CookieCategory.analytics,
      'prov': 'Hotjar'
    },
    '_hjSessionRejected': {'cat': CookieCategory.functional, 'prov': 'Hotjar'},
    '_hjSessionResumed': {'cat': CookieCategory.functional, 'prov': 'Hotjar'},
    '_hjSessionStorageTest': {
      'cat': CookieCategory.functional,
      'prov': 'Hotjar'
    },
    '_hjSessionTooLarge': {'cat': CookieCategory.functional, 'prov': 'Hotjar'},
    '_hjShownFeedbackMessage': {
      'cat': CookieCategory.analytics,
      'prov': 'Hotjar'
    },
    '_hjTLDTest': {'cat': CookieCategory.functional, 'prov': 'Hotjar'},
    '_hjUserAttrbutesHash': {
      'cat': CookieCategory.analytics,
      'prov': 'ContentSquare'
    },
    '_hjUserAttributes': {
      'cat': CookieCategory.analytics,
      'prov': 'ContentSquare'
    },
    '_hjUserAttributesHash': {
      'cat': CookieCategory.functional,
      'prov': 'Hotjar'
    },
    '_hjasCachedUserAttributes': {
      'cat': CookieCategory.analytics,
      'prov': 'ContentSquare'
    },
    '_hjid': {'cat': CookieCategory.analytics, 'prov': 'Hotjar'},
    '_hjptid': {'cat': CookieCategory.functional, 'prov': 'Hotjar'},
    '_iub_cs-': {'cat': CookieCategory.functional, 'prov': 'Iubenda'},
    '_kuid_': {'cat': CookieCategory.advertising, 'prov': 'Salesforce'},
    '_landing_page': {'cat': CookieCategory.advertising, 'prov': 'Shopify'},
    '_lcc': {'cat': CookieCategory.advertising, 'prov': 'Adobe Advertising'},
    '_lfa': {'cat': CookieCategory.advertising, 'prov': 'Leadfeeder'},
    '_li_id': {'cat': CookieCategory.advertising, 'prov': 'Leadinfo'},
    '_li_ses': {'cat': CookieCategory.advertising, 'prov': 'Leadinfo'},
    '_ljtrtb_': {'cat': CookieCategory.advertising, 'prov': 'SOVRN'},
    '_lo_bn': {'cat': CookieCategory.functional, 'prov': 'Lucky Orange'},
    '_lo_cid': {'cat': CookieCategory.functional, 'prov': 'Lucky Orange'},
    '_lo_np_': {'cat': CookieCategory.functional, 'prov': 'Lucky Orange'},
    '_lo_rid': {'cat': CookieCategory.analytics, 'prov': 'Lucky Orange'},
    '_lo_uid': {'cat': CookieCategory.analytics, 'prov': 'Lucky Orange'},
    '_lo_v': {'cat': CookieCategory.analytics, 'prov': 'Lucky Orange'},
    '_lv': {'cat': CookieCategory.analytics, 'prov': 'Marfeel'},
    '_mailmunch_visitor_id': {
      'cat': CookieCategory.advertising,
      'prov': 'MailMunch'
    },
    '_mb': {'cat': CookieCategory.advertising, 'prov': 'Vuble'},
    '_mkto_trk': {'cat': CookieCategory.advertising, 'prov': 'OneTrust'},
    '_nrbi': {'cat': CookieCategory.analytics, 'prov': 'Marfeel'},
    '_octo': {'cat': CookieCategory.analytics, 'prov': 'GitHub'},
    '_omappvp': {'cat': CookieCategory.advertising, 'prov': 'Optinmonster'},
    '_omappvs': {'cat': CookieCategory.advertising, 'prov': 'Optinmonster'},
    '_opt_awcid': {'cat': CookieCategory.analytics, 'prov': 'Google Optimize'},
    '_opt_awgid': {'cat': CookieCategory.analytics, 'prov': 'Google Optimize'},
    '_opt_awkid': {'cat': CookieCategory.analytics, 'prov': 'Google Optimize'},
    '_opt_awmid': {'cat': CookieCategory.analytics, 'prov': 'Google Optimize'},
    '_opt_expid': {'cat': CookieCategory.analytics, 'prov': 'Google Optimize'},
    '_orig_referrer': {'cat': CookieCategory.advertising, 'prov': 'Shopify'},
    '_pangle': {'cat': CookieCategory.advertising, 'prov': 'Pangle'},
    '_parsely_session': {'cat': CookieCategory.functional, 'prov': 'Parse.ly'},
    '_parsely_slot_click': {
      'cat': CookieCategory.functional,
      'prov': 'Parse.ly'
    },
    '_parsely_tpa_blocked': {
      'cat': CookieCategory.functional,
      'prov': 'Parse.ly'
    },
    '_parsely_visitor': {'cat': CookieCategory.functional, 'prov': 'Parse.ly'},
    '_pbjs_userid_consent_data': {
      'cat': CookieCategory.functional,
      'prov': 'Prebid'
    },
    '_pin_unauth': {'cat': CookieCategory.advertising, 'prov': 'Pinterest'},
    '_pinterest_cm': {'cat': CookieCategory.functional, 'prov': 'Pinterest'},
    '_pinterest_ct': {'cat': CookieCategory.advertising, 'prov': 'Pinterest'},
    '_pinterest_ct_rt': {
      'cat': CookieCategory.advertising,
      'prov': 'Pinterest'
    },
    '_pk_cvar': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    '_pk_hsr': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    '_pk_id.': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    '_pk_ses.': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    '_pk_testcookie': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    '_rd_experiment_version': {
      'cat': CookieCategory.advertising,
      'prov': 'RD Station'
    },
    '_rd_wa_first_session': {
      'cat': CookieCategory.advertising,
      'prov': 'RD Station'
    },
    '_rd_wa_id': {'cat': CookieCategory.advertising, 'prov': 'RD Station'},
    '_rd_wa_ses_id': {'cat': CookieCategory.advertising, 'prov': 'RD Station'},
    '_rdlps_pp': {'cat': CookieCategory.advertising, 'prov': 'RD Station'},
    '_rdtrk': {'cat': CookieCategory.advertising, 'prov': 'RD Station'},
    '_routing_id': {'cat': CookieCategory.advertising, 'prov': 'Pinterest'},
    '_rp_uid': {'cat': CookieCategory.functional, 'prov': 'Adyen'},
    '_rxuuid': {'cat': CookieCategory.advertising, 'prov': '1rx.io'},
    '_s': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_schn': {'cat': CookieCategory.advertising, 'prov': 'Snapchat'},
    '_scid_r': {'cat': CookieCategory.advertising, 'prov': 'Snapchat'},
    '_secure_account_session_id': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    '_secure_session_id': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    '_shopify_country': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    '_shopify_d': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_shopify_essential': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    '_shopify_essential_': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    '_shopify_fs': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_shopify_ga': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_shopify_m': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    '_shopify_sa_p': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_shopify_sa_t': {'cat': CookieCategory.advertising, 'prov': 'Shopify'},
    '_shopify_tm': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    '_shopify_tw': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    '_shopify_u': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    '_shopify_uniq': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_shopify_visit': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_sid': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    '_simplex': {'cat': CookieCategory.functional, 'prov': 'Wistia'},
    '_sn_a': {'cat': CookieCategory.analytics, 'prov': 'Sleeknote'},
    '_sn_m': {'cat': CookieCategory.advertising, 'prov': 'Sleeknote'},
    '_sn_n': {'cat': CookieCategory.functional, 'prov': 'Sleeknote'},
    '_sp_id.': {'cat': CookieCategory.analytics, 'prov': 'Snowplow'},
    '_sp_root_domain_test_': {
      'cat': CookieCategory.advertising,
      'prov': 'RD Station'
    },
    '_sp_ses.': {'cat': CookieCategory.analytics, 'prov': 'Snowplow'},
    '_sp_wa_first_session': {
      'cat': CookieCategory.advertising,
      'prov': 'RD Station'
    },
    '_sp_wa_id': {'cat': CookieCategory.advertising, 'prov': 'RD Station'},
    '_sp_wa_ses_id': {'cat': CookieCategory.advertising, 'prov': 'RD Station'},
    '_splunk_rum_sid': {
      'cat': CookieCategory.functional,
      'prov': 'SurveyMonkey'
    },
    '_spring_KmMlAnyoneDraftArticlesList': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_spring_KmMlArchivedArticlesList': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_spring_KmMlMyDraftArticlesList': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_spring_KmMlMyDraftTranslationsList': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_spring_KmMlPublishedArticlesList': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_spring_KmMlPublishedTranslationsList': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    '_ssc': {'cat': CookieCategory.advertising, 'prov': 'Totvs'},
    '_ssp_update_time': {'cat': CookieCategory.advertising, 'prov': 'Bidence'},
    '_stg_optout': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    '_storefront_u': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    '_tb_sess_r': {'cat': CookieCategory.functional, 'prov': 'Taboola'},
    '_tb_t_ppg': {'cat': CookieCategory.advertising, 'prov': 'Taboola'},
    '_tmae': {'cat': CookieCategory.advertising, 'prov': 'Adobe Advertising'},
    '_tracking_consent': {'cat': CookieCategory.advertising, 'prov': 'Shopify'},
    '_ttp': {'cat': CookieCategory.advertising, 'prov': 'TikTok'},
    '_u': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    '_ut': {'cat': CookieCategory.analytics, 'prov': 'Marfeel'},
    '_vf_rd_test': {'cat': CookieCategory.functional, 'prov': 'Viafoura'},
    '_vfa': {'cat': CookieCategory.analytics, 'prov': 'Viafoura'},
    '_vfb': {'cat': CookieCategory.analytics, 'prov': 'Viafoura'},
    '_vfz': {'cat': CookieCategory.analytics, 'prov': 'Viafoura'},
    '_vis_opt_exp_': {
      'cat': CookieCategory.functional,
      'prov': 'Visual Website Optimizer'
    },
    '_vis_opt_s': {
      'cat': CookieCategory.functional,
      'prov': 'Visual Website Optimizer'
    },
    '_vis_opt_test_cookie': {
      'cat': CookieCategory.functional,
      'prov': 'Visual Website Optimizer'
    },
    '_vwo_referrer': {
      'cat': CookieCategory.analytics,
      'prov': 'Visual Website Optimizer'
    },
    '_vwo_sn': {
      'cat': CookieCategory.analytics,
      'prov': 'Visual Website Optimizer'
    },
    '_vwo_ssm': {
      'cat': CookieCategory.functional,
      'prov': 'Visual Website Optimizer'
    },
    '_vwo_uuid': {
      'cat': CookieCategory.functional,
      'prov': 'Visual Website Optimizer'
    },
    '_wepublishGa': {'cat': CookieCategory.analytics, 'prov': 'WePublish'},
    '_wepublishGa_gid': {'cat': CookieCategory.analytics, 'prov': 'WePublish'},
    '_wixCIDX': {'cat': CookieCategory.functional, 'prov': 'Wix.com'},
    '_wix_browser_sess': {'cat': CookieCategory.functional, 'prov': 'Wix.com'},
    '_y': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    '_yasc': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    '_ym_debug': {'cat': CookieCategory.functional, 'prov': 'Yandex.Metrica'},
    '_ym_hostIndex': {
      'cat': CookieCategory.functional,
      'prov': 'Yandex.Metrica'
    },
    '_ym_metrika_enabled': {
      'cat': CookieCategory.analytics,
      'prov': 'Yandex.Metrica'
    },
    '_ym_visorc_': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    '_zdsession_talk_embeddables_service': {
      'cat': CookieCategory.functional,
      'prov': 'Zendesk'
    },
    '_zdshared_user_session_analytics': {
      'cat': CookieCategory.analytics,
      'prov': 'Zendesk'
    },
    '_zendesk_authenticated': {
      'cat': CookieCategory.functional,
      'prov': 'Zendesk'
    },
    '_zendesk_cookie': {'cat': CookieCategory.functional, 'prov': 'Zendesk'},
    '_zendesk_nps_session': {
      'cat': CookieCategory.functional,
      'prov': 'Zendesk'
    },
    '_zendesk_session': {'cat': CookieCategory.functional, 'prov': 'Zendesk'},
    '_zendesk_shared_session': {
      'cat': CookieCategory.functional,
      'prov': 'Zendesk'
    },
    'aam_uuid': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Audience Manager'
    },
    'ab': {'cat': CookieCategory.advertising, 'prov': 'Neustar'},
    'ab._gd': {'cat': CookieCategory.functional, 'prov': 'Braze'},
    'ab.optOut': {'cat': CookieCategory.functional, 'prov': 'Braze'},
    'ab.storage.deviceId.': {'cat': CookieCategory.analytics, 'prov': 'Braze'},
    'ab.storage.sessionId.': {'cat': CookieCategory.analytics, 'prov': 'Braze'},
    'ab.storage.userId.': {'cat': CookieCategory.functional, 'prov': 'Braze'},
    'abLdr': {'cat': CookieCategory.analytics, 'prov': 'Taboola'},
    'abMbl': {'cat': CookieCategory.analytics, 'prov': 'Taboola'},
    'abiRedirect': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'ablyft_exps': {'cat': CookieCategory.analytics, 'prov': 'ABlyft'},
    'ablyft_queue': {'cat': CookieCategory.analytics, 'prov': 'ABlyft'},
    'ablyft_tracking_consent': {
      'cat': CookieCategory.analytics,
      'prov': 'ABlyft'
    },
    'ablyft_uvs': {'cat': CookieCategory.analytics, 'prov': 'ABlyft'},
    'aboutads_sessNNN': {
      'cat': CookieCategory.essential,
      'prov': 'Google AdSense'
    },
    'ac_L': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'ac_LD': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'ac_enable_tracking': {
      'cat': CookieCategory.advertising,
      'prov': 'Active Campaign'
    },
    'acalltracker': {'cat': CookieCategory.advertising, 'prov': 'Adcalls'},
    'acalltrackernumber': {
      'cat': CookieCategory.advertising,
      'prov': 'Adcalls'
    },
    'acalltrackerreferrer': {
      'cat': CookieCategory.analytics,
      'prov': 'Adcalls'
    },
    'acalltrackersession': {
      'cat': CookieCategory.functional,
      'prov': 'Adcalls'
    },
    'activeView': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'ad-id': {'cat': CookieCategory.advertising, 'prov': 'Amazon'},
    'ad-privacy': {'cat': CookieCategory.advertising, 'prov': 'Amazon'},
    'adaptv_unique_user_cookie': {
      'cat': CookieCategory.advertising,
      'prov': 'Yahoo'
    },
    'adcloud': {'cat': CookieCategory.advertising, 'prov': 'Adobe Advertising'},
    'adform_uid': {'cat': CookieCategory.advertising, 'prov': 'Adhese'},
    'adformfrpid': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'adheseCustomer': {'cat': CookieCategory.advertising, 'prov': 'Adhese'},
    'adrl': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'ads_prefs': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'adtrc': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'adx_ts': {'cat': CookieCategory.advertising, 'prov': 'Ortec'},
    'ahoy_visit': {'cat': CookieCategory.analytics, 'prov': 'Ahoy'},
    'ahoy_visitor': {'cat': CookieCategory.analytics, 'prov': 'Ahoy'},
    'ai_session': {
      'cat': CookieCategory.functional,
      'prov': 'Microsoft Azure App Insights'
    },
    'ai_user': {
      'cat': CookieCategory.functional,
      'prov': 'Microsoft Azure App Insights'
    },
    'ajs_group_id': {'cat': CookieCategory.analytics, 'prov': 'Trustpilot'},
    'aks': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'aksb': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'algoliasearch-client-js': {
      'cat': CookieCategory.functional,
      'prov': 'Twitch'
    },
    'all_u_b': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'alohaEpt': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'am-uid': {'cat': CookieCategory.advertising, 'prov': 'Admixer'},
    'am_tokens': {'cat': CookieCategory.advertising, 'prov': 'MediaVine'},
    'am_tokens_invalidate-verizon-pushes': {
      'cat': CookieCategory.advertising,
      'prov': 'MediaVine'
    },
    'amplitude_cookie_test': {
      'cat': CookieCategory.analytics,
      'prov': 'Amplitude'
    },
    'amplitude_id': {'cat': CookieCategory.advertising, 'prov': 'Trustpilot'},
    'amplitude_id_': {'cat': CookieCategory.analytics, 'prov': 'Amplitude'},
    'amplitude_test': {'cat': CookieCategory.analytics, 'prov': 'Amplitude'},
    'aniC': {'cat': CookieCategory.advertising, 'prov': 'Aniview'},
    'anj': {'cat': CookieCategory.advertising, 'prov': 'Xandr'},
    'apbct_': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'apbct_antibot': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'apbct_cookies_test': {
      'cat': CookieCategory.functional,
      'prov': 'CleanTalk'
    },
    'apex__EmailAddress': {
      'cat': CookieCategory.advertising,
      'prov': 'Salesforce'
    },
    'apiDomain_': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    'api_token': {'cat': CookieCategory.functional, 'prov': 'Twitch'},
    'apnxs': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'appLang': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'appName': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'app_manifest_token': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'app_ts': {'cat': CookieCategory.advertising, 'prov': 'Ortec'},
    'appnexus_uid': {'cat': CookieCategory.advertising, 'prov': 'Adhese'},
    'ar_debug': {
      'cat': CookieCategory.advertising,
      'prov': 'DoubleClick/Google Marketing'
    },
    'at_check': {
      'cat': CookieCategory.functional,
      'prov': 'Adobe Audience Manager'
    },
    'atidvisitor': {'cat': CookieCategory.analytics, 'prov': 'AT Internet'},
    'attribution_user_id': {
      'cat': CookieCategory.advertising,
      'prov': 'Typeform'
    },
    'atuserid': {'cat': CookieCategory.analytics, 'prov': 'AT Internet'},
    'audience': {'cat': CookieCategory.advertising, 'prov': 'SpotX'},
    'audit': {'cat': CookieCategory.advertising, 'prov': 'Magnite'},
    'audit_p': {'cat': CookieCategory.advertising, 'prov': 'Magnite'},
    'auid': {'cat': CookieCategory.advertising, 'prov': 'Acuity'},
    'aum': {'cat': CookieCategory.advertising, 'prov': 'Acuity'},
    'auraBrokenDefGraph': {
      'cat': CookieCategory.analytics,
      'prov': 'Salesforce'
    },
    'auth-token': {'cat': CookieCategory.functional, 'prov': 'Twitch'},
    'auth0': {'cat': CookieCategory.functional, 'prov': 'Auth0'},
    'auth0-mf': {'cat': CookieCategory.functional, 'prov': 'Auth0'},
    'auth0-mf_compat': {'cat': CookieCategory.functional, 'prov': 'Auth0'},
    'auth0_compat': {'cat': CookieCategory.functional, 'prov': 'Auth0'},
    'autocomplete': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'avcid-': {'cat': CookieCategory.advertising, 'prov': 'richAudience'},
    'aw_popup_viewed_page': {
      'cat': CookieCategory.functional,
      'prov': 'AWS Cookies Popup'
    },
    'aws-csds-token': {
      'cat': CookieCategory.functional,
      'prov': 'Amazon Web Services'
    },
    'aws-priv': {
      'cat': CookieCategory.functional,
      'prov': 'Amazon Web Services'
    },
    'aws_lang': {
      'cat': CookieCategory.functional,
      'prov': 'Amazon Web Services'
    },
    'axeptio_all_vendors': {
      'cat': CookieCategory.functional,
      'prov': 'Axeptio'
    },
    'axeptio_authorized_vendors': {
      'cat': CookieCategory.functional,
      'prov': 'Axeptio'
    },
    'axeptio_cookies': {'cat': CookieCategory.functional, 'prov': 'Axeptio'},
    'axids': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'bSession': {'cat': CookieCategory.functional, 'prov': 'Wix.com'},
    'bbcpsessionhash': {'cat': CookieCategory.functional, 'prov': 'vBulletin'},
    'bblastactivity': {'cat': CookieCategory.functional, 'prov': 'vBulletin'},
    'bblastvisit': {'cat': CookieCategory.functional, 'prov': 'vBulletin'},
    'bbnp_notices_displayed': {
      'cat': CookieCategory.functional,
      'prov': 'vBulletin'
    },
    'bbpassword': {'cat': CookieCategory.functional, 'prov': 'vBulletin'},
    'bbsessionhash': {'cat': CookieCategory.functional, 'prov': 'vBulletin'},
    'bbsitebuilder_active': {
      'cat': CookieCategory.functional,
      'prov': 'vBulletin'
    },
    'bbuserid': {'cat': CookieCategory.functional, 'prov': 'vBulletin'},
    'bc_tstgrp': {'cat': CookieCategory.advertising, 'prov': 'Blueconic.com'},
    'bdswch': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'be_lastLoginProvider': {'cat': CookieCategory.functional, 'prov': 'TYPO3'},
    'be_typo_user': {'cat': CookieCategory.functional, 'prov': 'TYPO3'},
    'belco-anonymous-id': {'cat': CookieCategory.functional, 'prov': 'Belco'},
    'belco-cookies': {'cat': CookieCategory.functional, 'prov': 'Belco'},
    'betweendigital.com': {
      'cat': CookieCategory.advertising,
      'prov': 'betweendigital.com'
    },
    'bh': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    'bito': {'cat': CookieCategory.advertising, 'prov': 'Beeswax'},
    'bitoIsSecure': {'cat': CookieCategory.advertising, 'prov': 'Beeswax'},
    'bkpa': {'cat': CookieCategory.advertising, 'prov': 'BlueKai'},
    'borlabs-cookie': {'cat': CookieCategory.functional, 'prov': 'Borlabs'},
    'bounceClientVisit': {'cat': CookieCategory.advertising, 'prov': 'Bouncex'},
    'brcap': {'cat': CookieCategory.functional, 'prov': 'Bing / Microsoft'},
    'browserupdateorg': {
      'cat': CookieCategory.functional,
      'prov': 'Browser-Update.org'
    },
    'brwsr': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'buid': {'cat': CookieCategory.functional, 'prov': 'Azure / Microsoft'},
    'c': {'cat': CookieCategory.advertising, 'prov': 'Magnite'},
    'c-plan': {'cat': CookieCategory.analytics, 'prov': 'CognitoForms'},
    'c-referrer': {'cat': CookieCategory.analytics, 'prov': 'CognitoForms'},
    'c-signup': {'cat': CookieCategory.analytics, 'prov': 'CognitoForms'},
    'cX_P': {'cat': CookieCategory.analytics, 'prov': 'Piano'},
    'caPanelState': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'calViewState': {'cat': CookieCategory.analytics, 'prov': 'Salesforce'},
    'callback': {'cat': CookieCategory.advertising, 'prov': 'ID5'},
    'camfreq_': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'campaign_click_url': {
      'cat': CookieCategory.advertising,
      'prov': 'Facebook'
    },
    'camptix_client_stats': {
      'cat': CookieCategory.analytics,
      'prov': 'WordPress'
    },
    'cap': {'cat': CookieCategory.advertising, 'prov': 'Adhese'},
    'car': {'cat': CookieCategory.advertising, 'prov': 'ID5'},
    'card_update_verification_id': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'cart_currency': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'cart_ts': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'cart_ver': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'cb-currency': {'cat': CookieCategory.functional, 'prov': 'Cookiebot'},
    'cc-': {'cat': CookieCategory.functional, 'prov': 'Intershop'},
    'ccec_user': {
      'cat': CookieCategory.advertising,
      'prov': 'CookieConsent.io'
    },
    'ccookie': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'cct': {'cat': CookieCategory.advertising, 'prov': 'adscale.de'},
    'ce_login': {'cat': CookieCategory.functional, 'prov': 'Crazy Egg'},
    'ce_sid': {'cat': CookieCategory.functional, 'prov': 'Crazy Egg'},
    'ce_signup_flow': {'cat': CookieCategory.functional, 'prov': 'Crazy Egg'},
    'ce_signup_partner': {
      'cat': CookieCategory.advertising,
      'prov': 'Crazy Egg'
    },
    'ce_successful_csp_check': {
      'cat': CookieCategory.analytics,
      'prov': 'Crazy Egg'
    },
    'ceac': {'cat': CookieCategory.functional, 'prov': 'Crazy Egg'},
    'cean': {'cat': CookieCategory.functional, 'prov': 'Crazy Egg'},
    'cean_assoc': {'cat': CookieCategory.functional, 'prov': 'Crazy Egg'},
    'cebs': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    'cebsp_': {'cat': CookieCategory.analytics, 'prov': 'Crazy Egg'},
    'cecu': {'cat': CookieCategory.functional, 'prov': 'Crazy Egg'},
    'ceft_variant_override': {
      'cat': CookieCategory.analytics,
      'prov': 'Crazy Egg'
    },
    'cehc': {'cat': CookieCategory.functional, 'prov': 'Crazy Egg'},
    'celi': {'cat': CookieCategory.functional, 'prov': 'Crazy Egg'},
    'centralnotice_bucket': {
      'cat': CookieCategory.analytics,
      'prov': 'Wikimedia'
    },
    'cf': {'cat': CookieCategory.advertising, 'prov': 'ID5'},
    'cf_chl_rc_i': {'cat': CookieCategory.functional, 'prov': 'CloudFlare'},
    'cf_chl_rc_m': {'cat': CookieCategory.functional, 'prov': 'CloudFlare'},
    'cf_chl_rc_ni': {'cat': CookieCategory.functional, 'prov': 'CloudFlare'},
    'cf_ob_info': {'cat': CookieCategory.functional, 'prov': 'CloudFlare'},
    'cf_use_ob': {'cat': CookieCategory.functional, 'prov': 'CloudFlare'},
    'cfid': {'cat': CookieCategory.functional, 'prov': 'Adobe ColdFusion'},
    'cftoken': {'cat': CookieCategory.functional, 'prov': 'Adobe ColdFusion'},
    'chat_rules_shown': {'cat': CookieCategory.functional, 'prov': 'Twitch'},
    'checkout_prefill': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'checkout_queue_token': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'checkout_session_lookup': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'checkout_session_token': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'checkout_session_token_': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'checkout_token': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'checkout_worker_session': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'childinfo': {
      'cat': CookieCategory.advertising,
      'prov': 'Bing / Microsoft'
    },
    'chk': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'chkSecSet': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'chp_token': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'ci_session': {'cat': CookieCategory.functional, 'prov': 'CodeIgniter'},
    'cid': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'cioFT': {'cat': CookieCategory.advertising, 'prov': 'Customer.io'},
    'cioLT': {'cat': CookieCategory.advertising, 'prov': 'Customer.io'},
    'cip': {'cat': CookieCategory.advertising, 'prov': 'ID5'},
    'cjae': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'ckid': {'cat': CookieCategory.advertising, 'prov': 'Blue'},
    'ckies_functional': {'cat': CookieCategory.functional, 'prov': 'Jimdo'},
    'ckies_marketing': {'cat': CookieCategory.functional, 'prov': 'Jimdo'},
    'ckies_necessary': {'cat': CookieCategory.functional, 'prov': 'Jimdo'},
    'ckies_performance': {'cat': CookieCategory.functional, 'prov': 'Jimdo'},
    'cky-action': {'cat': CookieCategory.functional, 'prov': 'CookieYes'},
    'cky-consent': {'cat': CookieCategory.functional, 'prov': 'CookieYes'},
    'cli_user_preference': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'client-session-bind': {
      'cat': CookieCategory.functional,
      'prov': 'Wix.com'
    },
    'clientSrc': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'client_bslstaid': {'cat': CookieCategory.analytics, 'prov': 'Beslist.nl'},
    'client_bslstmatch': {
      'cat': CookieCategory.analytics,
      'prov': 'Beslist.nl'
    },
    'client_bslstsid': {'cat': CookieCategory.analytics, 'prov': 'Beslist.nl'},
    'client_bslstuid': {'cat': CookieCategory.analytics, 'prov': 'Beslist.nl'},
    'cmp': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'cmplz_banner-status': {
      'cat': CookieCategory.functional,
      'prov': 'Complianz'
    },
    'cmplz_choice': {'cat': CookieCategory.functional, 'prov': 'Complianz'},
    'cmplz_consented_services': {
      'cat': CookieCategory.functional,
      'prov': 'Complianz'
    },
    'cmplz_functional': {'cat': CookieCategory.functional, 'prov': 'Complianz'},
    'cmplz_id': {'cat': CookieCategory.functional, 'prov': 'Complianz'},
    'cmplz_marketing': {'cat': CookieCategory.functional, 'prov': 'Complianz'},
    'cmplz_policy_id': {'cat': CookieCategory.functional, 'prov': 'Complianz'},
    'cmplz_preferences': {
      'cat': CookieCategory.functional,
      'prov': 'Complianz'
    },
    'cmplz_saved_categories': {
      'cat': CookieCategory.functional,
      'prov': 'Complianz'
    },
    'cmplz_saved_services': {
      'cat': CookieCategory.functional,
      'prov': 'Complianz'
    },
    'cmplz_statistics': {'cat': CookieCategory.functional, 'prov': 'Complianz'},
    'cmplz_stats': {'cat': CookieCategory.functional, 'prov': 'Complianz'},
    'cmplz_user_data': {'cat': CookieCategory.functional, 'prov': 'Complianz'},
    'cnac': {'cat': CookieCategory.advertising, 'prov': 'ID5'},
    'cnfq': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'codepen_session': {'cat': CookieCategory.functional, 'prov': 'Codepen'},
    'codepen_signup_referrer': {
      'cat': CookieCategory.functional,
      'prov': 'Codepen'
    },
    'codepen_signup_referrer_date': {
      'cat': CookieCategory.functional,
      'prov': 'Codepen'
    },
    'codexToken': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'codexUserId': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'codexUserName': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'cognito.organization': {
      'cat': CookieCategory.analytics,
      'prov': 'CognitoForms'
    },
    'cognito.services.a': {
      'cat': CookieCategory.analytics,
      'prov': 'CognitoForms'
    },
    'color_mode': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'comment_author_': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'comment_author_url_': {
      'cat': CookieCategory.functional,
      'prov': 'WordPress'
    },
    'compass_sid': {'cat': CookieCategory.analytics, 'prov': 'Marfeel'},
    'compass_uid': {'cat': CookieCategory.analytics, 'prov': 'Marfeel'},
    'complianz_consent_status': {
      'cat': CookieCategory.functional,
      'prov': 'Complianz'
    },
    'complianz_policy_id': {
      'cat': CookieCategory.functional,
      'prov': 'Complianz'
    },
    'componentStyle': {'cat': CookieCategory.functional, 'prov': 'Joomla!'},
    'componentType': {'cat': CookieCategory.functional, 'prov': 'Joomla!'},
    'connect.sid': {'cat': CookieCategory.functional, 'prov': 'Zendesk'},
    'consent-policy': {'cat': CookieCategory.functional, 'prov': 'Wix.com'},
    'cookie-consent-io': {
      'cat': CookieCategory.functional,
      'prov': 'CookieConsent.io'
    },
    'cookie-consent-io-gdpr': {
      'cat': CookieCategory.functional,
      'prov': 'CookieConsent.io'
    },
    'cookie-consent-io-timestamp': {
      'cat': CookieCategory.functional,
      'prov': 'CookieConsent.io'
    },
    'cookie.policy.banner.eu': {
      'cat': CookieCategory.functional,
      'prov': 'LinkedIn'
    },
    'cookie.policy.banner.nl': {
      'cat': CookieCategory.functional,
      'prov': 'LinkedIn'
    },
    'cookieJartestCookie': {
      'cat': CookieCategory.advertising,
      'prov': 'Outbrain'
    },
    'cookieSettingVerified': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'cookieconsent_level': {
      'cat': CookieCategory.functional,
      'prov': 'Maxlead'
    },
    'cookieconsent_page': {'cat': CookieCategory.functional, 'prov': 'Osano'},
    'cookieconsent_seen': {'cat': CookieCategory.functional, 'prov': 'Maxlead'},
    'cookieconsent_system': {
      'cat': CookieCategory.functional,
      'prov': 'Maxlead'
    },
    'cookieconsent_variant': {
      'cat': CookieCategory.functional,
      'prov': 'Maxlead'
    },
    'cookiefirst-consent': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie First'
    },
    'cookielawinfo-checkbox-advertisement': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'cookielawinfo-checkbox-analytics': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'cookielawinfo-checkbox-functional': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'cookielawinfo-checkbox-marketing': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'cookielawinfo-checkbox-necessary': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'cookielawinfo-checkbox-non-necessary': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'cookielawinfo-checkbox-others': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'cookielawinfo-checkbox-performance': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'cookielawinfo-checkbox-preferences': {
      'cat': CookieCategory.functional,
      'prov': 'Cookie Law Info'
    },
    'cookies-analytics': {'cat': CookieCategory.functional, 'prov': 'Enzuzo'},
    'cookies-functional': {'cat': CookieCategory.functional, 'prov': 'Enzuzo'},
    'cookies-marketing': {'cat': CookieCategory.functional, 'prov': 'Enzuzo'},
    'cookies-preferences': {'cat': CookieCategory.functional, 'prov': 'Enzuzo'},
    'cookieyes-advertisement': {
      'cat': CookieCategory.functional,
      'prov': 'CookieYes'
    },
    'cookieyes-analytics': {
      'cat': CookieCategory.functional,
      'prov': 'CookieYes'
    },
    'cookieyes-consent': {
      'cat': CookieCategory.functional,
      'prov': 'CookieYes'
    },
    'cookieyes-functional': {
      'cat': CookieCategory.functional,
      'prov': 'CookieYes'
    },
    'cookieyes-necessary': {
      'cat': CookieCategory.functional,
      'prov': 'CookieYes'
    },
    'cookieyes-performance': {
      'cat': CookieCategory.functional,
      'prov': 'CookieYes'
    },
    'cookieyesID': {'cat': CookieCategory.functional, 'prov': 'CookieYes'},
    'cookieyes_privacy_policy_generator_session': {
      'cat': CookieCategory.functional,
      'prov': 'CookieYes'
    },
    'cookieyes_session': {
      'cat': CookieCategory.functional,
      'prov': 'CookieYes'
    },
    'cordovaVersion': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'cqcid': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'cref': {'cat': CookieCategory.advertising, 'prov': 'Quantcast'},
    'criteo': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'cs': {'cat': CookieCategory.advertising, 'prov': 'GumGum'},
    'csfq': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'csm': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'csrf-canary': {'cat': CookieCategory.essential, 'prov': 'Trustpilot'},
    'csrf_same_site': {'cat': CookieCategory.essential, 'prov': 'X'},
    'csrf_same_site_set': {'cat': CookieCategory.essential, 'prov': 'X'},
    'csssid': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'csssid_Client': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'csync': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'ct_': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'ct_check_js': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'ct_fkp_timestamp': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'ct_has_scrolled': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'ct_pointer_data': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'ct_ps_timestamp': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'ct_sfw_': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'ct_timezone': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'ctkgen': {'cat': CookieCategory.analytics, 'prov': 'Indeed'},
    'customer_account_locale': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'customer_account_new_login': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'customer_account_preview': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'customer_payment_method': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'customer_shop_pay_agreement': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'd': {'cat': CookieCategory.advertising, 'prov': 'Quantcast'},
    'data-': {'cat': CookieCategory.advertising, 'prov': 'Media.net'},
    'datatricsDebugger': {
      'cat': CookieCategory.advertising,
      'prov': 'Datatrics'
    },
    'datatrics_customData': {
      'cat': CookieCategory.advertising,
      'prov': 'Datatrics'
    },
    'datatrics_optin': {'cat': CookieCategory.advertising, 'prov': 'Datatrics'},
    'dbln': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'dc': {'cat': CookieCategory.advertising, 'prov': 'BetweenDigital'},
    'ddid': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'demdex': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Audience Manager'
    },
    'denial-client-ip': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'denial-reason-code': {
      'cat': CookieCategory.functional,
      'prov': 'LinkedIn'
    },
    'deuxesse_uxid': {'cat': CookieCategory.advertising, 'prov': 'Twiago'},
    'devOverrideCsrfToken': {
      'cat': CookieCategory.essential,
      'prov': 'Salesforce'
    },
    'devicePixelRatio': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'device_id': {'cat': CookieCategory.functional, 'prov': 'Twitch'},
    'dextp': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Audience Manager'
    },
    'df_ts': {'cat': CookieCategory.analytics, 'prov': 'LinkedIn'},
    'dicbo_id': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'did': {'cat': CookieCategory.functional, 'prov': 'Auth0'},
    'did_compat': {'cat': CookieCategory.functional, 'prov': 'Auth0'},
    'didomi_token': {'cat': CookieCategory.functional, 'prov': 'Didomi'},
    'digitalAudience': {
      'cat': CookieCategory.advertising,
      'prov': 'Digital Audience'
    },
    'disco': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'discount_code': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'django_language': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'dm_last_page_view': {'cat': CookieCategory.analytics, 'prov': 'Duda'},
    'dm_last_visit': {'cat': CookieCategory.analytics, 'prov': 'Duda'},
    'dm_this_page_view': {'cat': CookieCategory.analytics, 'prov': 'Duda'},
    'dm_timezone_offset': {'cat': CookieCategory.analytics, 'prov': 'Duda'},
    'dm_total_visits': {'cat': CookieCategory.analytics, 'prov': 'Duda'},
    'dnt': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'done_redirects': {'cat': CookieCategory.advertising, 'prov': 'OnAudience'},
    'dotcom_user': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'dpm': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Audience Manager'
    },
    'ds_user_id': {'cat': CookieCategory.advertising, 'prov': 'Instagram'},
    'dst': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Audience Manager'
    },
    'dt': {'cat': CookieCategory.advertising, 'prov': 'Underdog Media'},
    'dtCookie': {'cat': CookieCategory.analytics, 'prov': 'Dynatrace'},
    'dtDisabled': {'cat': CookieCategory.analytics, 'prov': 'Dynatrace'},
    'dtLatC': {'cat': CookieCategory.analytics, 'prov': 'Dynatrace'},
    'dtPC': {'cat': CookieCategory.analytics, 'prov': 'Dynatrace'},
    'dtSa': {'cat': CookieCategory.analytics, 'prov': 'Dynatrace'},
    'dtValidationCookie': {
      'cat': CookieCategory.analytics,
      'prov': 'Dynatrace'
    },
    'dtm_gdpr_delete': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'dtm_gpc_optout': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'dtm_tcdata': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'dtm_tcdata_exp': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'dtm_token': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'dtm_token_exp': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'dtm_token_sc': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'dtm_user_id': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'dtm_user_id_sc': {'cat': CookieCategory.advertising, 'prov': 'Dotomi'},
    'duid_update_time': {'cat': CookieCategory.advertising, 'prov': 'Bidence'},
    'dy_fs_page': {'cat': CookieCategory.functional, 'prov': 'Dynamic Yield'},
    'dynamic_checkout_shown_on_cart': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'dyncdn': {'cat': CookieCategory.functional, 'prov': 'Smartadserver'},
    'easysize_button_loaded_for_user': {
      'cat': CookieCategory.functional,
      'prov': 'Easysize.me'
    },
    'edgebucket': {'cat': CookieCategory.advertising, 'prov': 'Reddit'},
    'edsid': {'cat': CookieCategory.advertising, 'prov': 'MercadoLibre'},
    'enable-compact-scene-listing': {
      'cat': CookieCategory.functional,
      'prov': 'Twitch'
    },
    'enforce_policy': {'cat': CookieCategory.functional, 'prov': 'PayPal'},
    'enterprise_trial_redirect_to': {
      'cat': CookieCategory.functional,
      'prov': 'GitHub'
    },
    'ep': {'cat': CookieCategory.advertising, 'prov': 'Emetric'},
    'esctx': {'cat': CookieCategory.functional, 'prov': 'Azure / Microsoft'},
    'esctx-': {'cat': CookieCategory.functional, 'prov': 'Microsoft'},
    'eu_cn': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'europe': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'ev_sync_ax': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_sync_bk': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_sync_dd': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_sync_fs': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_sync_ix': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_sync_nx': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_sync_ox': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_sync_pm': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_sync_rc': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_sync_tm': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_sync_yh': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'ev_tm': {'cat': CookieCategory.advertising, 'prov': 'Adobe Advertising'},
    'excludecalltracking': {
      'cat': CookieCategory.functional,
      'prov': 'Adcalls'
    },
    'expid_': {'cat': CookieCategory.advertising, 'prov': 'Salesforce'},
    'external_no_cache': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'external_referer': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'ezds': {'cat': CookieCategory.functional, 'prov': 'Ezoic'},
    'ezoab_': {'cat': CookieCategory.functional, 'prov': 'Ezoic'},
    'ezoadgid_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'ezoawesome_': {'cat': CookieCategory.functional, 'prov': 'Ezoic'},
    'ezohw': {'cat': CookieCategory.functional, 'prov': 'Ezoic'},
    'ezopvc_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'ezoref_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'ezostid_': {'cat': CookieCategory.functional, 'prov': 'Ezoic'},
    'ezosuigeneris': {'cat': CookieCategory.advertising, 'prov': 'Ezoic'},
    'ezouid_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'ezovid_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'ezovuuid_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'ezovuuidtime_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'ezux_et_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'ezux_ifep_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'ezux_lpl_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'ezux_tos_': {'cat': CookieCategory.analytics, 'prov': 'Ezoic'},
    'f_token': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'fastclick': {'cat': CookieCategory.functional, 'prov': 'Fastclick'},
    'fbm_': {'cat': CookieCategory.advertising, 'prov': 'Instagram'},
    'fcookie': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'fe_typo_user': {'cat': CookieCategory.functional, 'prov': 'TYPO3'},
    'fedops.logger.sessionId': {
      'cat': CookieCategory.functional,
      'prov': 'Wix.com'
    },
    'feed-sort': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'fid': {'cat': CookieCategory.analytics, 'prov': 'Adobe Analytics'},
    'fileTreeExpanded': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'first_snapshot_url': {
      'cat': CookieCategory.functional,
      'prov': 'Crazy Egg'
    },
    'fl_inst': {'cat': CookieCategory.advertising, 'prov': 'Platform161'},
    'fonts-loaded': {'cat': CookieCategory.functional, 'prov': 'Funda'},
    'force-proxy-stream': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'force-stream': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'form_key': {'cat': CookieCategory.essential, 'prov': 'Magento'},
    'fpc': {'cat': CookieCategory.functional, 'prov': 'Azure / Microsoft'},
    'fpestid': {'cat': CookieCategory.functional, 'prov': 'ShareThis'},
    'frontend': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'ftid': {'cat': CookieCategory.advertising, 'prov': 'MercadoLibre'},
    'g': {'cat': CookieCategory.advertising, 'prov': 'CreativeCDN'},
    'gTalkCollapsed': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'g_enabled_idps': {'cat': CookieCategory.functional, 'prov': 'Google'},
    'gac': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'gac_': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'gckp': {'cat': CookieCategory.advertising, 'prov': 'Piano'},
    'gcl': {'cat': CookieCategory.advertising, 'prov': 'Google'},
    'gdpr_status': {'cat': CookieCategory.advertising, 'prov': 'Media.net'},
    'ghcc': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'gid': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'gig_bootstrap_': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    'gig_canary': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'gig_canary_ver': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'gig_hasGmid': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    'gig_last_ver_': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'gig_loginToken_': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'gig_toggles': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'gist_oauth_csrf': {'cat': CookieCategory.essential, 'prov': 'GitHub'},
    'gist_user_session': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'glnk': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'glt_': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'gltexp_': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'gmid': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    'gpp': {'cat': CookieCategory.functional, 'prov': 'ID5'},
    'gst': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'gt': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'guest-view': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'guest_uuid_essential_': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'hasGmid': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    'has_js': {'cat': CookieCategory.functional, 'prov': 'Drupal CMS'},
    'has_recent_activity': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'hash': {'cat': CookieCategory.advertising, 'prov': 'Blue'},
    'help_center_data': {'cat': CookieCategory.functional, 'prov': 'Zendesk'},
    'hideDevelopmentTools': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'hideFilesWarningModal': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'hideIdentityDialog': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'hide_shopify_pay_for_checkout': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'hjViewportId': {'cat': CookieCategory.functional, 'prov': 'Hotjar'},
    'hj_visitor': {'cat': CookieCategory.analytics, 'prov': 'Hotjar'},
    'hs': {'cat': CookieCategory.functional, 'prov': 'Wix.com'},
    'hs-membership-csrf': {'cat': CookieCategory.essential, 'prov': 'Hubspot'},
    'hs-messages-hide-welcome-message': {
      'cat': CookieCategory.functional,
      'prov': 'Hubspot'
    },
    'hs-messages-is-open': {
      'cat': CookieCategory.functional,
      'prov': 'Hubspot'
    },
    'hs_ab_test': {'cat': CookieCategory.functional, 'prov': 'Hubspot'},
    'hs_langswitcher_choice': {
      'cat': CookieCategory.functional,
      'prov': 'Hubspot'
    },
    'html-classes': {'cat': CookieCategory.functional, 'prov': 'Funda'},
    'hu-consent': {'cat': CookieCategory.functional, 'prov': 'Hu-manity.co'},
    'hubspotapi': {'cat': CookieCategory.advertising, 'prov': 'Hubspot'},
    'hubspotapi-csrf': {'cat': CookieCategory.essential, 'prov': 'Hubspot'},
    'hubspotapi-prefs': {'cat': CookieCategory.functional, 'prov': 'Hubspot'},
    'i': {'cat': CookieCategory.advertising, 'prov': 'openx.net'},
    'i00': {'cat': CookieCategory.advertising, 'prov': 'infOnline'},
    'ick': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'icu': {'cat': CookieCategory.advertising, 'prov': 'Xandr'},
    'id_adcloud': {
      'cat': CookieCategory.advertising,
      'prov': 'Adobe Advertising'
    },
    'id_ts': {'cat': CookieCategory.advertising, 'prov': 'Ortec'},
    'idccsrf': {'cat': CookieCategory.essential, 'prov': 'Salesforce'},
    'ideaToggle': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'identity-state': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'identity-state-': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'identity_customer_account_number': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'idp': {'cat': CookieCategory.advertising, 'prov': 'Zeotap'},
    'idsync-bsw-uid-s': {
      'cat': CookieCategory.advertising,
      'prov': 'StreamTheWorld'
    },
    'ig_cb': {'cat': CookieCategory.advertising, 'prov': 'Instagram'},
    'ig_did': {'cat': CookieCategory.advertising, 'prov': 'Instagram'},
    'igodigitalst_': {'cat': CookieCategory.advertising, 'prov': 'Salesforce'},
    'igodigitalstdomain': {
      'cat': CookieCategory.advertising,
      'prov': 'Salesforce'
    },
    'improvedigital_uid': {'cat': CookieCategory.advertising, 'prov': 'Adhese'},
    'incap_ses_': {'cat': CookieCategory.functional, 'prov': 'Imperva'},
    'initref': {'cat': CookieCategory.advertising, 'prov': 'Reddit'},
    'inst': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'integration_type': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'intercom-device-id-': {
      'cat': CookieCategory.analytics,
      'prov': 'Intercom'
    },
    'intercom-id-': {'cat': CookieCategory.analytics, 'prov': 'Intercom'},
    'intercom-session-': {'cat': CookieCategory.analytics, 'prov': 'Intercom'},
    'interstitial_page_reg_oauth_url': {
      'cat': CookieCategory.analytics,
      'prov': 'LinkedIn'
    },
    'iotcontextsplashdisable': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'ipc': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'isFirstSession': {'cat': CookieCategory.functional, 'prov': 'Microsoft'},
    'is_gdpr': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    'is_gdpr_b': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    'iutk': {'cat': CookieCategory.advertising, 'prov': 'Issuu'},
    'ja_purity_ii_tpl': {'cat': CookieCategory.functional, 'prov': 'JoomlArt'},
    'ja_purity_tpl': {'cat': CookieCategory.functional, 'prov': 'JoomlArt'},
    'jasx_pool_id': {'cat': CookieCategory.analytics, 'prov': 'Indeed'},
    'jetpackState': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'jpp_math_pass': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'jpxumaster': {
      'cat': CookieCategory.advertising,
      'prov': 'justpremium.com'
    },
    'jpxumatched': {
      'cat': CookieCategory.advertising,
      'prov': 'justpremium.com'
    },
    'js_ver': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'kcdob': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'kcrelid': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'kcru': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'kdt': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'khaos_p': {'cat': CookieCategory.advertising, 'prov': 'Magnite'},
    'ki_r': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    'ki_s': {'cat': CookieCategory.advertising, 'prov': 'Qualaroo'},
    'ki_t': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    'ki_u': {'cat': CookieCategory.advertising, 'prov': 'Qualaroo'},
    'koitk': {'cat': CookieCategory.advertising, 'prov': 'Sharpspring'},
    'l_page': {'cat': CookieCategory.analytics, 'prov': 'LinkedIn'},
    'lantern': {'cat': CookieCategory.advertising, 'prov': 'Awin'},
    'last_visited_store': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'lastlist': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'lcsrc': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'lcsrd': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'lhc_ldep': {'cat': CookieCategory.functional, 'prov': 'Live helper chat'},
    'lhc_per': {'cat': CookieCategory.functional, 'prov': 'Live helper chat'},
    'lhc_ses': {'cat': CookieCategory.functional, 'prov': 'Live helper chat'},
    'li_a': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_alerts': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_apfcdc': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_cc': {'cat': CookieCategory.analytics, 'prov': 'LinkedIn'},
    'li_cu': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_ec': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_ep_auth_context': {
      'cat': CookieCategory.functional,
      'prov': 'LinkedIn'
    },
    'li_fat_id': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_feed_xray': {'cat': CookieCategory.analytics, 'prov': 'LinkedIn'},
    'li_gc': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_giant': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_gp': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_gpc': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_mc': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_oatml': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'li_odapfcc': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_referer': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_rm': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_theme': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'li_theme_set': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'liap': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'lidid': {'cat': CookieCategory.advertising, 'prov': 'LiveIntent'},
    'lihc_auth_': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'lil-lang': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'lissc': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'lists-state': {'cat': CookieCategory.functional, 'prov': 'Plesk'},
    'liveagent_invite_rejected_': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'liveagent_sid': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'ljt_reader': {
      'cat': CookieCategory.advertising,
      'prov': 'Federated Media Publishing'
    },
    'ljtrtb': {'cat': CookieCategory.advertising, 'prov': 'SOVRN'},
    'lkqdid': {'cat': CookieCategory.advertising, 'prov': 'Verve'},
    'lkqdidts': {'cat': CookieCategory.advertising, 'prov': 'Verve'},
    'lloopch_loid': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'lls-integration': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'lms_ads': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'lms_analytics': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'ln_or': {'cat': CookieCategory.analytics, 'prov': 'LinkedIn'},
    'local_storage_app_session_id': {
      'cat': CookieCategory.functional,
      'prov': 'Twitch'
    },
    'locale': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'locale_bar_accepted': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'localization': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'login': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'login_redirect': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'login_with_shop_finalize': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'loginnotify_prevlogins': {
      'cat': CookieCategory.functional,
      'prov': 'Wikimedia'
    },
    'lss_bundle_viewer': {'cat': CookieCategory.analytics, 'prov': 'LinkedIn'},
    'lu': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'lz_last_visit': {
      'cat': CookieCategory.functional,
      'prov': 'LiveZilla GmbH'
    },
    'lz_userid': {'cat': CookieCategory.functional, 'prov': 'LiveZilla GmbH'},
    'lz_visits': {'cat': CookieCategory.functional, 'prov': 'LiveZilla GmbH'},
    'm': {'cat': CookieCategory.functional, 'prov': 'Stripe'},
    'm_user': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'mage-banners-cache-storage': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'mage-cache-sessid': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'mage-cache-storage': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'mage-cache-storage-section-invalidation': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'mage-cache-timeout': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'mage-messages': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'mage-translation-file-version': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'mage-translation-storage': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'mailmunch_second_pageview': {
      'cat': CookieCategory.advertising,
      'prov': 'MailMunch'
    },
    'marketplace_repository_ids': {
      'cat': CookieCategory.functional,
      'prov': 'GitHub'
    },
    'marketplace_suggested_target_id': {
      'cat': CookieCategory.functional,
      'prov': 'GitHub'
    },
    'master_device_id': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'matchadform': {'cat': CookieCategory.advertising, 'prov': 'Roku'},
    'matomo_ignore': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    'matomo_sessid': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    'mc_cid': {'cat': CookieCategory.analytics, 'prov': 'Mailchimp'},
    'mc_eid': {'cat': CookieCategory.analytics, 'prov': 'Mailchimp'},
    'mc_landing_site': {'cat': CookieCategory.analytics, 'prov': 'Mailchimp'},
    'mdfrc': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'mics_lts': {'cat': CookieCategory.advertising, 'prov': 'Mediarithmics'},
    'mics_uaid': {'cat': CookieCategory.advertising, 'prov': 'Mediarithmics'},
    'mics_vid': {'cat': CookieCategory.advertising, 'prov': 'Mediarithmics'},
    'mid': {'cat': CookieCategory.functional, 'prov': 'Instagram'},
    'mnet_session_depth': {
      'cat': CookieCategory.advertising,
      'prov': 'Media.net'
    },
    'msToken': {'cat': CookieCategory.advertising, 'prov': 'TikTok'},
    'mt_misc': {'cat': CookieCategory.advertising, 'prov': 'MediaMath'},
    'mt_mop': {'cat': CookieCategory.advertising, 'prov': 'MediaMath'},
    'mtm_consent': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    'mtm_consent_removed': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    'mtm_cookie_consent': {'cat': CookieCategory.analytics, 'prov': 'Matomo'},
    'muc_ads': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'muxData': {'cat': CookieCategory.functional, 'prov': 'Wistia'},
    'mv_tokens': {'cat': CookieCategory.advertising, 'prov': 'MediaVine'},
    'mv_tokens_invalidate-verizon-pushes': {
      'cat': CookieCategory.advertising,
      'prov': 'MediaVine'
    },
    'n': {'cat': CookieCategory.advertising, 'prov': 'Tailtarget'},
    'nSGt-': {'cat': CookieCategory.functional, 'prov': 'Azure / Microsoft'},
    'nlbi_': {'cat': CookieCategory.functional, 'prov': 'Imperva'},
    'nmstat': {'cat': CookieCategory.analytics, 'prov': 'Siteimprove'},
    'nrid': {'cat': CookieCategory.functional, 'prov': 'Joomla! Engagebox'},
    'nsid': {'cat': CookieCategory.functional, 'prov': 'PayPal'},
    'obsessionid-': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'oid': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'oinfo': {'cat': CookieCategory.advertising, 'prov': 'Salesforce'},
    'oo': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'opout': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'opt_out': {'cat': CookieCategory.advertising, 'prov': 'Nativo'},
    'optimizelyDomainTestCookie': {
      'cat': CookieCategory.advertising,
      'prov': 'Optimizely'
    },
    'optimizelyOptOut': {
      'cat': CookieCategory.advertising,
      'prov': 'Optimizely'
    },
    'optimizelyRedirectData': {
      'cat': CookieCategory.advertising,
      'prov': 'Optimizely'
    },
    'org_transform_notice': {
      'cat': CookieCategory.functional,
      'prov': 'GitHub'
    },
    'oribi_cookie_test': {'cat': CookieCategory.analytics, 'prov': 'Oribi'},
    'oribi_user_guid': {'cat': CookieCategory.analytics, 'prov': 'Oribi'},
    'osano_consentmanager_expdate': {
      'cat': CookieCategory.functional,
      'prov': 'Osano'
    },
    'osano_consentmanager_uuid': {
      'cat': CookieCategory.functional,
      'prov': 'Osano'
    },
    'otsid': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'outbrain_dicbo_id': {
      'cat': CookieCategory.advertising,
      'prov': 'Outbrain'
    },
    'ozone_uid': {
      'cat': CookieCategory.advertising,
      'prov': 'The Ozone Project'
    },
    'pa_google_ts': {
      'cat': CookieCategory.advertising,
      'prov': 'Perfect Audience'
    },
    'pa_openx_ts': {
      'cat': CookieCategory.advertising,
      'prov': 'Perfect Audience'
    },
    'pa_rubicon_ts': {
      'cat': CookieCategory.advertising,
      'prov': 'Perfect Audience'
    },
    'pa_twitter_ts': {
      'cat': CookieCategory.advertising,
      'prov': 'Perfect Audience'
    },
    'pa_uid': {'cat': CookieCategory.advertising, 'prov': 'Perfect Audience'},
    'pa_user': {'cat': CookieCategory.analytics, 'prov': 'Piano'},
    'pa_yahoo_ts': {
      'cat': CookieCategory.advertising,
      'prov': 'Perfect Audience'
    },
    'panoramaId': {'cat': CookieCategory.advertising, 'prov': 'Lotame'},
    'panoramaId_expiry': {'cat': CookieCategory.advertising, 'prov': 'Lotame'},
    'panoramaId_expiry_exp': {
      'cat': CookieCategory.advertising,
      'prov': 'Lotame'
    },
    'partner-': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'pay_update_intent_id': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'pbw': {'cat': CookieCategory.analytics, 'prov': 'Smartadserver'},
    'pc-unit': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'pcfm': {'cat': CookieCategory.advertising, 'prov': 'Bing / Microsoft'},
    'pctrk': {'cat': CookieCategory.analytics, 'prov': 'Salesforce'},
    'pd': {'cat': CookieCategory.advertising, 'prov': 'openx.net'},
    'pdid': {'cat': CookieCategory.advertising, 'prov': 'richAudience'},
    'persistent_shopping_cart': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'pgid-org-': {'cat': CookieCategory.functional, 'prov': 'Intershop'},
    'phpMyAdmin': {'cat': CookieCategory.functional, 'prov': 'phpMyAdmin'},
    'pi': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'pi_opt_in': {'cat': CookieCategory.analytics, 'prov': 'Salesforce'},
    'picreel_new_price': {'cat': CookieCategory.analytics, 'prov': 'Picreel'},
    'picreel_tracker__first_visit': {
      'cat': CookieCategory.analytics,
      'prov': 'Picreel'
    },
    'picreel_tracker__page_views': {
      'cat': CookieCategory.analytics,
      'prov': 'Picreel'
    },
    'picreel_tracker__visited': {
      'cat': CookieCategory.analytics,
      'prov': 'Picreel'
    },
    'pid': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'pid_short': {'cat': CookieCategory.advertising, 'prov': 'Emetric'},
    'pid_signature': {'cat': CookieCategory.advertising, 'prov': 'Emetric'},
    'pl': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'pl_user_id': {'cat': CookieCategory.advertising, 'prov': 'PowerLinks'},
    'plek-list-type': {'cat': CookieCategory.functional, 'prov': 'Plesk'},
    'plesk-items-per-page': {'cat': CookieCategory.functional, 'prov': 'Plesk'},
    'plesk-sort-dir': {'cat': CookieCategory.functional, 'prov': 'Plesk'},
    'plesk-sort-field': {'cat': CookieCategory.functional, 'prov': 'Plesk'},
    'pll_language': {'cat': CookieCategory.functional, 'prov': 'Polylang'},
    'pluto': {'cat': CookieCategory.advertising, 'prov': 'Fastclick'},
    'pm_sess_NNN': {'cat': CookieCategory.functional, 'prov': 'Google AdSense'},
    'pmaAuth-': {'cat': CookieCategory.functional, 'prov': 'phpMyAdmin'},
    'pmaUser-': {'cat': CookieCategory.functional, 'prov': 'phpMyAdmin'},
    'pma_lang': {'cat': CookieCategory.functional, 'prov': 'phpMyAdmin'},
    'pnespsdk_pnespid': {'cat': CookieCategory.advertising, 'prov': 'Piano'},
    'pnespsdk_push_subscription_added': {
      'cat': CookieCategory.analytics,
      'prov': 'Piano'
    },
    'pnespsdk_ssn': {'cat': CookieCategory.functional, 'prov': 'Piano'},
    'pnespsdk_visitor': {'cat': CookieCategory.analytics, 'prov': 'Piano'},
    'pollN': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'pp': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'ppms_privacy_': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    'ppms_privacy_bar_': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    'presence': {'cat': CookieCategory.functional, 'prov': 'Facebook'},
    'preview_theme': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'previous_step': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'prism_': {'cat': CookieCategory.advertising, 'prov': 'Active Campaign'},
    'privacypillar-cookie-consent': {
      'cat': CookieCategory.functional,
      'prov': 'PrivacyPillar'
    },
    'privacypillar-google-consent': {
      'cat': CookieCategory.functional,
      'prov': 'PrivacyPillar'
    },
    'private_content_version': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'private_mode_user_session': {
      'cat': CookieCategory.functional,
      'prov': 'GitHub'
    },
    'product_data_storage': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'profile_preview_token': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'promptTestMod': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'pses': {'cat': CookieCategory.analytics, 'prov': 'Xandr'},
    'ptradtrt': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptran': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptrb': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptrbsw': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptrc': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptrcriteo': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptreps': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptropenx': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptrpp': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptrpub': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptrrc': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptrrhs': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'ptrt': {'cat': CookieCategory.advertising, 'prov': 'Yieldmo'},
    'pubconsent': {'cat': CookieCategory.functional, 'prov': 'ShareThis'},
    'pubfreq_': {'cat': CookieCategory.advertising, 'prov': 'PubMatic'},
    'pubmatic_uid': {'cat': CookieCategory.advertising, 'prov': 'Adhese'},
    'pubsyncexp': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'pubtime_': {'cat': CookieCategory.functional, 'prov': 'PubMatic'},
    'pushPermInfo': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'pushPermState': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'put_': {'cat': CookieCategory.advertising, 'prov': 'Magnite'},
    'pxcelBcnLcy': {'cat': CookieCategory.analytics, 'prov': 'ShareThis'},
    'pxcelPage': {'cat': CookieCategory.analytics, 'prov': 'ShareThis'},
    'pxid': {'cat': CookieCategory.functional, 'prov': 'Permutive'},
    'pxrc': {'cat': CookieCategory.advertising, 'prov': 'Rapleaf'},
    'queryString': {'cat': CookieCategory.analytics, 'prov': 'LinkedIn'},
    'rack.session': {'cat': CookieCategory.functional, 'prov': 'Rack'},
    'rai-pltn-pl-': {'cat': CookieCategory.advertising, 'prov': 'richAudience'},
    'rc': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'rdtrk': {'cat': CookieCategory.advertising, 'prov': 'RD Station'},
    'receive-cookie-deprecation': {
      'cat': CookieCategory.functional,
      'prov': 'Google'
    },
    'recent_history': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'recent_history_status': {
      'cat': CookieCategory.functional,
      'prov': 'LinkedIn'
    },
    'recently_compared_product': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'recently_compared_product_previous': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'recently_viewed_product': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'recently_viewed_product_previous': {
      'cat': CookieCategory.functional,
      'prov': 'Magento'
    },
    'recs': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'recs-': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'redirectionWarning': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'ref-': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'referrer_url': {'cat': CookieCategory.functional, 'prov': 'Twitch'},
    'rek_content': {'cat': CookieCategory.advertising, 'prov': 'rekmob.com'},
    'remember_checked_on': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'remember_me': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'renderCtx': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'renderid': {
      'cat': CookieCategory.functional,
      'prov': 'Adobe Audience Manager'
    },
    'rl_anonymous_id': {'cat': CookieCategory.analytics, 'prov': 'Rudderstack'},
    'rl_auth_token': {'cat': CookieCategory.analytics, 'prov': 'Rudderstack'},
    'rl_group_id': {'cat': CookieCategory.analytics, 'prov': 'Rudderstack'},
    'rl_group_trait': {'cat': CookieCategory.analytics, 'prov': 'Rudderstack'},
    'rl_page_init_referrer': {
      'cat': CookieCategory.analytics,
      'prov': 'Rudderstack'
    },
    'rl_page_init_referring_domain': {
      'cat': CookieCategory.analytics,
      'prov': 'Rudderstack'
    },
    'rl_session': {'cat': CookieCategory.analytics, 'prov': 'Rudderstack'},
    'rl_trait': {'cat': CookieCategory.analytics, 'prov': 'Rudderstack'},
    'rl_user_id': {'cat': CookieCategory.analytics, 'prov': 'Rudderstack'},
    'rpx': {'cat': CookieCategory.advertising, 'prov': 'Magnite'},
    'rsid': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'rtbData0': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'rtbh': {'cat': CookieCategory.advertising, 'prov': 'Underdog Media'},
    'rtc': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'rts': {'cat': CookieCategory.advertising, 'prov': 'Mediaplex'},
    'rubicon_uid': {'cat': CookieCategory.advertising, 'prov': 'Adhese'},
    'rweb_optin': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'rxVisitor': {'cat': CookieCategory.analytics, 'prov': 'Dynatrace'},
    'rxvt': {'cat': CookieCategory.analytics, 'prov': 'Dynatrace'},
    'rxx': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    's': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    's_tp': {'cat': CookieCategory.analytics, 'prov': 'Adobe Analytics'},
    'sailthru_content': {'cat': CookieCategory.advertising, 'prov': 'Sailthru'},
    'sailthru_pageviews': {
      'cat': CookieCategory.advertising,
      'prov': 'Sailthru'
    },
    'sailthru_visitor': {'cat': CookieCategory.advertising, 'prov': 'Sailthru'},
    'saml_csrf_token': {'cat': CookieCategory.essential, 'prov': 'GitHub'},
    'saml_return_to': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'saml_return_to_legacy': {
      'cat': CookieCategory.functional,
      'prov': 'GitHub'
    },
    'sasd': {'cat': CookieCategory.advertising, 'prov': 'Smartadserver'},
    'sat_track': {'cat': CookieCategory.functional, 'prov': 'Adobe Analytics'},
    'sbjs_current': {'cat': CookieCategory.analytics, 'prov': 'WooCommerce'},
    'sbjs_current_add': {
      'cat': CookieCategory.analytics,
      'prov': 'WooCommerce'
    },
    'sbjs_first': {'cat': CookieCategory.analytics, 'prov': 'WooCommerce'},
    'sbjs_first_add': {'cat': CookieCategory.analytics, 'prov': 'WooCommerce'},
    'sbjs_migrations': {'cat': CookieCategory.analytics, 'prov': 'WooCommerce'},
    'sbjs_session': {'cat': CookieCategory.analytics, 'prov': 'WooCommerce'},
    'sbjs_udata': {'cat': CookieCategory.analytics, 'prov': 'WooCommerce'},
    'sc-a-nonce': {'cat': CookieCategory.advertising, 'prov': 'Snapchat'},
    'sc_at': {'cat': CookieCategory.advertising, 'prov': 'Snapchat'},
    'schgtclose': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'sd_client_id': {'cat': CookieCategory.analytics, 'prov': 'Vimeo'},
    'sd_identity': {'cat': CookieCategory.analytics, 'prov': 'Vimeo'},
    'sdsc': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'searchReport-log': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'section_data_clean': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'section_data_ids': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'sentry_device_id': {'cat': CookieCategory.functional, 'prov': 'Twitch'},
    'server-session-bind': {
      'cat': CookieCategory.functional,
      'prov': 'Wix.com'
    },
    'server_session_id': {'cat': CookieCategory.functional, 'prov': 'Twitch'},
    'sessionFunnelEventLogged': {
      'cat': CookieCategory.advertising,
      'prov': 'Pinterest'
    },
    'session_storage_last_visited_twitch_url': {
      'cat': CookieCategory.functional,
      'prov': 'Twitch'
    },
    'session_unique_id': {'cat': CookieCategory.functional, 'prov': 'Twitch'},
    'sessionid': {'cat': CookieCategory.advertising, 'prov': 'Instagram'},
    'sfau': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'sfdc-stream': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'sharebox-suggestion': {
      'cat': CookieCategory.analytics,
      'prov': 'LinkedIn'
    },
    'sharing_': {'cat': CookieCategory.functional, 'prov': 'Crazy Egg'},
    'shbid': {'cat': CookieCategory.advertising, 'prov': 'Instagram'},
    'shbts': {'cat': CookieCategory.advertising, 'prov': 'Instagram'},
    'shop_analytics': {'cat': CookieCategory.analytics, 'prov': 'Shopify'},
    'shop_pay_accelerated': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'shopify-editor-unconfirmed-settings': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'shopify_pay': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'shopify_pay_redirect': {
      'cat': CookieCategory.functional,
      'prov': 'Shopify'
    },
    'showComments': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'showNewBuilderWarningMessage': {
      'cat': CookieCategory.functional,
      'prov': 'Salesforce'
    },
    'show_cookie_banner': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'sid_Client': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'sidebarPinned': {'cat': CookieCategory.unknown, 'prov': 'Salesforce'},
    'sites-active-list-state-collapsed': {
      'cat': CookieCategory.functional,
      'prov': 'Plesk'
    },
    'smSession': {'cat': CookieCategory.functional, 'prov': 'Wix.com'},
    'sm_ir': {'cat': CookieCategory.functional, 'prov': 'SurveyMonkey'},
    'sm_rec': {'cat': CookieCategory.functional, 'prov': 'SurveyMonkey'},
    'sp': {'cat': CookieCategory.analytics, 'prov': 'Snowplow'},
    'sp_landing': {'cat': CookieCategory.functional, 'prov': 'Spotify'},
    'sp_t': {'cat': CookieCategory.functional, 'prov': 'Spotify'},
    'spbc_cookies_test': {
      'cat': CookieCategory.functional,
      'prov': 'CleanTalk'
    },
    'spbc_firewall_pass_key': {
      'cat': CookieCategory.functional,
      'prov': 'CleanTalk'
    },
    'spbc_is_logged_in': {
      'cat': CookieCategory.functional,
      'prov': 'CleanTalk'
    },
    'spbc_log_id': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'spbc_timer': {'cat': CookieCategory.functional, 'prov': 'CleanTalk'},
    'spectroscopyId': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'spx_ts': {'cat': CookieCategory.advertising, 'prov': 'Ortec'},
    'sqzl_abs': {'cat': CookieCategory.advertising, 'prov': 'Squeezely'},
    'sqzl_consent': {'cat': CookieCategory.functional, 'prov': 'Squeezely'},
    'sqzl_session_id': {'cat': CookieCategory.advertising, 'prov': 'Squeezely'},
    'sqzl_vw': {'cat': CookieCategory.advertising, 'prov': 'Squeezely'},
    'sqzllocal': {'cat': CookieCategory.advertising, 'prov': 'Squeezely'},
    'ss': {'cat': CookieCategory.functional, 'prov': 'betweendigital.com'},
    'ssid': {'cat': CookieCategory.advertising, 'prov': 'Springserve'},
    'ssoCSRFCookie': {'cat': CookieCategory.functional, 'prov': 'Dynatrace'},
    'sso_user': {'cat': CookieCategory.functional, 'prov': 'SurveyMonkey'},
    'ssostartpage': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'sst': {'cat': CookieCategory.advertising, 'prov': 'Springserve'},
    'st_chc': {'cat': CookieCategory.advertising, 'prov': 'Seedtag'},
    'st_cnt': {'cat': CookieCategory.advertising, 'prov': 'Seedtag'},
    'st_cs': {'cat': CookieCategory.advertising, 'prov': 'Seedtag'},
    'st_csd': {'cat': CookieCategory.advertising, 'prov': 'Seedtag'},
    'st_optout': {'cat': CookieCategory.functional, 'prov': 'ShareThis'},
    'st_ssp': {'cat': CookieCategory.advertising, 'prov': 'Seedtag'},
    'st_uid': {'cat': CookieCategory.advertising, 'prov': 'Seedtag'},
    'stf': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'stg_externalReferrer': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    'stg_fired__': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    'stg_global_opt_out': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    'stg_last_interaction': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    'stg_pk_campaign': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    'stg_returning_visitor': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    'stg_traffic_source_priority': {
      'cat': CookieCategory.analytics,
      'prov': 'Piwik'
    },
    'stg_utm_campaign': {'cat': CookieCategory.analytics, 'prov': 'Piwik'},
    'stnojs': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'stopMobileRedirect': {
      'cat': CookieCategory.functional,
      'prov': 'Wikimedia'
    },
    'store': {'cat': CookieCategory.functional, 'prov': 'Magento'},
    'store_notice': {'cat': CookieCategory.functional, 'prov': 'WooCommerce'},
    'storefront_digest': {'cat': CookieCategory.functional, 'prov': 'Shopify'},
    'stsservicecookie': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'stx_user_id': {'cat': CookieCategory.advertising, 'prov': 'Sharethrough'},
    'svSession': {'cat': CookieCategory.advertising, 'prov': 'Wix.com'},
    'svid': {'cat': CookieCategory.advertising, 'prov': 'Mediaplex'},
    'swym-cu_ct': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-email': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-instrumentMap': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-o_s': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-ol_ct': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-pid': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-session-id': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-swymRegid': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-tpermts': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-u_pref': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-v-ckd': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'swym-weml': {'cat': CookieCategory.functional, 'prov': 'Swym'},
    'sync': {'cat': CookieCategory.advertising, 'prov': 'TripleLift'},
    'syndication_guest_id': {'cat': CookieCategory.advertising, 'prov': 'X'},
    't': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'tPHG-PS': {'cat': CookieCategory.advertising, 'prov': 'Partnerize'},
    't_gid': {'cat': CookieCategory.advertising, 'prov': 'Taboola'},
    't_pt_gid': {'cat': CookieCategory.functional, 'prov': 'Taboola'},
    'taboola_fp_td_user_id': {
      'cat': CookieCategory.functional,
      'prov': 'Taboola'
    },
    'taboola_select': {'cat': CookieCategory.functional, 'prov': 'Taboola'},
    'tawkUUID': {'cat': CookieCategory.analytics, 'prov': 'Tawk.to Chat'},
    'tb_click_param': {'cat': CookieCategory.analytics, 'prov': 'Taboola'},
    'tbla_id': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'tc_caids': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'tc_cj_ss': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'tc_sample_': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'tc_ss': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'tc_test_cookie': {'cat': CookieCategory.functional, 'prov': 'Command Act'},
    'tearsheet': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'test': {'cat': CookieCategory.functional, 'prov': 'Parse.ly'},
    'test_cookie': {
      'cat': CookieCategory.functional,
      'prov': 'DoubleClick/Google Marketing'
    },
    'test_rudder_cookie': {
      'cat': CookieCategory.analytics,
      'prov': 'Rudderstack'
    },
    'tf_respondent_cc': {'cat': CookieCategory.functional, 'prov': 'Typeform'},
    'tfw_exp': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'tix_view_token': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'tk_ai': {
      'cat': CookieCategory.functional,
      'prov': 'WooCommerce / Jetpack'
    },
    'tk_lr': {'cat': CookieCategory.advertising, 'prov': 'WordPress'},
    'tk_or': {'cat': CookieCategory.advertising, 'prov': 'WordPress'},
    'tk_qs': {'cat': CookieCategory.analytics, 'prov': 'WordPress'},
    'tk_tc': {'cat': CookieCategory.analytics, 'prov': 'WordPress'},
    'tluidp': {'cat': CookieCategory.advertising, 'prov': 'TripleLift'},
    'token': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'tp': {'cat': CookieCategory.advertising, 'prov': 'Bombora'},
    'trac_form_token': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'trac_session': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'tracked_start_checkout': {
      'cat': CookieCategory.analytics,
      'prov': 'Shopify'
    },
    'trc': {'cat': CookieCategory.advertising, 'prov': 'Platform161'},
    'trc_cookie_storage': {'cat': CookieCategory.advertising, 'prov': 'Yahoo'},
    'triplelift_uid': {'cat': CookieCategory.advertising, 'prov': 'Adhese'},
    'trk': {'cat': CookieCategory.advertising, 'prov': 'Tailtarget'},
    'trkCode': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'trkInfo': {'cat': CookieCategory.advertising, 'prov': 'LinkedIn'},
    'ts': {'cat': CookieCategory.functional, 'prov': 'PayPal'},
    'ts_c': {'cat': CookieCategory.functional, 'prov': 'PayPal'},
    'tsrce': {'cat': CookieCategory.functional, 'prov': 'PayPal'},
    'tsrvid': {'cat': CookieCategory.functional, 'prov': 'FeedbackCompany'},
    'tt_bluekai': {'cat': CookieCategory.advertising, 'prov': 'Teads'},
    'tt_exelate': {'cat': CookieCategory.advertising, 'prov': 'Teads'},
    'tt_liveramp': {'cat': CookieCategory.advertising, 'prov': 'Teads'},
    'tt_neustar': {'cat': CookieCategory.advertising, 'prov': 'Teads'},
    'tt_salesforce': {'cat': CookieCategory.advertising, 'prov': 'Teads'},
    'tt_viewer': {'cat': CookieCategory.advertising, 'prov': 'Teads'},
    'ttbprf': {'cat': CookieCategory.advertising, 'prov': 'Tailtarget'},
    'ttc': {'cat': CookieCategory.advertising, 'prov': 'Tailtarget'},
    'ttca': {'cat': CookieCategory.advertising, 'prov': 'Tailtarget'},
    'ttcsid': {'cat': CookieCategory.advertising, 'prov': 'TikTok'},
    'ttd': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'ttgcm': {'cat': CookieCategory.advertising, 'prov': 'Tailtarget'},
    'ttnprf': {'cat': CookieCategory.advertising, 'prov': 'Tailtarget'},
    'ttwid': {'cat': CookieCategory.advertising, 'prov': 'TikTok'},
    'tu': {'cat': CookieCategory.advertising, 'prov': 'adscale.de'},
    'tuuid': {'cat': CookieCategory.advertising, 'prov': 'Platform161'},
    'tuuid_lu': {'cat': CookieCategory.advertising, 'prov': 'bidswitch.net'},
    'tv_U': {'cat': CookieCategory.advertising, 'prov': 'Magnite'},
    'tv_spot_tracker': {'cat': CookieCategory.analytics, 'prov': 'Abovo Media'},
    'tvid': {'cat': CookieCategory.advertising, 'prov': 'Magnite'},
    'twid': {'cat': CookieCategory.advertising, 'prov': 'X'},
    'twitch.lohp.countryCode': {
      'cat': CookieCategory.functional,
      'prov': 'Twitch'
    },
    'tz': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'u': {'cat': CookieCategory.advertising, 'prov': 'Totvs'},
    'ua_': {'cat': CookieCategory.functional, 'prov': 'SAP'},
    'ucid': {'cat': CookieCategory.advertising, 'prov': 'SAP'},
    'ud': {'cat': CookieCategory.advertising, 'prov': 'Nielsen'},
    'udmts': {'cat': CookieCategory.advertising, 'prov': 'Underdog Media'},
    'udo': {'cat': CookieCategory.advertising, 'prov': 'Nielsen'},
    'uesign': {'cat': CookieCategory.functional, 'prov': 'ZOHO'},
    'uh': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'uid': {'cat': CookieCategory.advertising, 'prov': 'Adform'},
    'uid-bp-': {'cat': CookieCategory.advertising, 'prov': 'FreeWheel'},
    'uids': {'cat': CookieCategory.advertising, 'prov': 'Admatic'},
    'um': {'cat': CookieCategory.advertising, 'prov': 'Improve Digital'},
    'umeh': {'cat': CookieCategory.advertising, 'prov': 'Improve Digital'},
    'unifiedPixel': {'cat': CookieCategory.advertising, 'prov': 'Outbrain'},
    'unique_ad_source_impression': {
      'cat': CookieCategory.advertising,
      'prov': 'Yahoo'
    },
    'unique_id': {'cat': CookieCategory.functional, 'prov': 'Twitch'},
    'unique_id_durable': {'cat': CookieCategory.functional, 'prov': 'Twitch'},
    'univ_id': {'cat': CookieCategory.advertising, 'prov': 'openx.net'},
    'unruly_m': {'cat': CookieCategory.advertising, 'prov': 'Unrulymedia.com'},
    'usbls': {'cat': CookieCategory.advertising, 'prov': 'Usabilla'},
    'useStandbyUrl': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'user_session': {'cat': CookieCategory.functional, 'prov': 'GitHub'},
    'usersync': {'cat': CookieCategory.analytics, 'prov': 'Xandr'},
    'usida': {'cat': CookieCategory.advertising, 'prov': 'Facebook'},
    'usprivacy': {'cat': CookieCategory.functional, 'prov': 'ShareThis'},
    'usst': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    'utm_key': {'cat': CookieCategory.functional, 'prov': 'OneTrust'},
    'uu': {'cat': CookieCategory.advertising, 'prov': 'adscale.de'},
    'uuidc': {'cat': CookieCategory.advertising, 'prov': 'MediaMath'},
    'v_usr': {'cat': CookieCategory.advertising, 'prov': 'E-volution.ai'},
    'version': {'cat': CookieCategory.advertising, 'prov': 'Aniview'},
    'vfThirdpartyCookiesEnabled': {
      'cat': CookieCategory.functional,
      'prov': 'Viafoura'
    },
    'vglnk.Agent.p': {'cat': CookieCategory.advertising, 'prov': 'Disqus'},
    'vglnk.PartnerRfsh.p': {
      'cat': CookieCategory.advertising,
      'prov': 'Disqus'
    },
    'videoChat.notice_dismissed': {
      'cat': CookieCategory.functional,
      'prov': 'Twitch'
    },
    'vidoomy-uids': {'cat': CookieCategory.advertising, 'prov': 'Vidoomy'},
    'viewer': {'cat': CookieCategory.advertising, 'prov': 'Ortec'},
    'viewer_token': {
      'cat': CookieCategory.advertising,
      'prov': 'csync.loopme.me'
    },
    'visid_incap_': {'cat': CookieCategory.functional, 'prov': 'Imperva'},
    'visitor': {'cat': CookieCategory.advertising, 'prov': 'Nativo'},
    'visitor-id': {'cat': CookieCategory.advertising, 'prov': 'Media.net'},
    'visitor_id': {'cat': CookieCategory.advertising, 'prov': 'Salesforce'},
    'vs': {'cat': CookieCategory.analytics, 'prov': 'Smartadserver'},
    'vst': {'cat': CookieCategory.advertising, 'prov': 'GumGum'},
    'vuid': {'cat': CookieCategory.analytics, 'prov': 'Vimeo'},
    'wa_lang_pref': {'cat': CookieCategory.functional, 'prov': 'WhatsApp'},
    'wa_ul': {'cat': CookieCategory.functional, 'prov': 'WhatsApp'},
    'waveUserPrefFinderLeftNav': {
      'cat': CookieCategory.unknown,
      'prov': 'Salesforce'
    },
    'waveUserPrefFinderListView': {
      'cat': CookieCategory.unknown,
      'prov': 'Salesforce'
    },
    'webact': {'cat': CookieCategory.functional, 'prov': 'Salesforce'},
    'welcome-': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'wfivefivec': {'cat': CookieCategory.advertising, 'prov': 'Roku'},
    'wires': {'cat': CookieCategory.functional, 'prov': 'Processwire'},
    'wires_challenge': {
      'cat': CookieCategory.functional,
      'prov': 'Processwire'
    },
    'wistia': {'cat': CookieCategory.functional, 'prov': 'Wistia'},
    'wistia-video-progress-': {
      'cat': CookieCategory.functional,
      'prov': 'Wistia'
    },
    'wixLanguage': {'cat': CookieCategory.functional, 'prov': 'Wix.com'},
    'woocommerce_cart_hash': {
      'cat': CookieCategory.functional,
      'prov': 'WooCommerce'
    },
    'woocommerce_dismissed_suggestions__': {
      'cat': CookieCategory.functional,
      'prov': 'WooCommerce'
    },
    'woocommerce_items_in_cart': {
      'cat': CookieCategory.functional,
      'prov': 'WooCommerce'
    },
    'woocommerce_recently_viewed': {
      'cat': CookieCategory.functional,
      'prov': 'WooCommerce'
    },
    'woocommerce_snooze_suggestions__': {
      'cat': CookieCategory.functional,
      'prov': 'WooCommerce'
    },
    'wordpress_google_apps_login': {
      'cat': CookieCategory.functional,
      'prov': 'WP-Glogin'
    },
    'wordpress_logged_in_': {
      'cat': CookieCategory.functional,
      'prov': 'WordPress'
    },
    'wp-postpass_': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'wp-saving-post': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'wp-wpml_current_language': {
      'cat': CookieCategory.functional,
      'prov': 'WPML'
    },
    'wp_woocommerce_session_': {
      'cat': CookieCategory.functional,
      'prov': 'WooCommerce'
    },
    'wporg_locale': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'wporg_logged_in': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'wporg_sec': {'cat': CookieCategory.functional, 'prov': 'WordPress'},
    'wwepo': {'cat': CookieCategory.functional, 'prov': 'LinkedIn'},
    'wwwchannelme_z_sid': {
      'cat': CookieCategory.functional,
      'prov': 'Channel.me'
    },
    'x-ms-cpim-admin': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-cpim-cache': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-cpim-csrf': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-cpim-ctx': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-cpim-dc': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-cpim-geo': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-cpim-rc': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-cpim-rp': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-cpim-slice': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-cpim-sso': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-cpim-trans': {
      'cat': CookieCategory.functional,
      'prov': 'Azure / Microsoft'
    },
    'x-ms-routing-name': {
      'cat': CookieCategory.functional,
      'prov': 'Lightbox CDN'
    },
    'x-pp-s': {'cat': CookieCategory.functional, 'prov': 'PayPal'},
    'xf_consent': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_csrf': {'cat': CookieCategory.essential, 'prov': 'Xenforo'},
    'xf_dbWriteForced': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_emoji_usage': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_from_search': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_inline_mod_': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_language_id': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_ls': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_notice_dismiss': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_push_notice_dismiss': {
      'cat': CookieCategory.functional,
      'prov': 'Xenforo'
    },
    'xf_push_subscription_updated': {
      'cat': CookieCategory.functional,
      'prov': 'Xenforo'
    },
    'xf_session': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_style_id': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_tfa_trust': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_toggle': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'xf_user': {'cat': CookieCategory.functional, 'prov': 'Xenforo'},
    'yabs-sid': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    'yabs-vdrf': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    'yandexuid': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    'yashr': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    'yieldmo_id': {'cat': CookieCategory.analytics, 'prov': 'Yieldmo'},
    'yith_wcwl_session_': {
      'cat': CookieCategory.functional,
      'prov': 'Yithemes.com'
    },
    'ymex': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    'yuidss': {'cat': CookieCategory.analytics, 'prov': 'Yandex.Metrica'},
    'zc': {'cat': CookieCategory.advertising, 'prov': 'Zeotap'},
    'zc_consent': {'cat': CookieCategory.functional, 'prov': 'ZOHO'},
    'zc_cu_exp': {'cat': CookieCategory.functional, 'prov': 'ZOHO'},
    'zc_loc': {'cat': CookieCategory.advertising, 'prov': 'ZOHO'},
    'zc_show': {'cat': CookieCategory.advertising, 'prov': 'ZOHO'},
    'zendesk_thirdparty_test': {
      'cat': CookieCategory.functional,
      'prov': 'Zendesk'
    },
    'zi': {'cat': CookieCategory.advertising, 'prov': 'Zeotap'},
    'zsc': {'cat': CookieCategory.advertising, 'prov': 'Zeotap'},
    'zuc': {'cat': CookieCategory.advertising, 'prov': 'Zeotap'},
  };

  static CookieInfo analyze(String rawCookie, String source) {
    // Parse name and value, and handle attributes
    final parts = rawCookie.split(';');
    final pair = parts[0].split('=');
    final name = pair[0].trim();
    String value = pair.length > 1 ? pair.sublist(1).join('=') : '';

    String? domain;
    String? expires;
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
      } else if (lowerAttr == 'secure') {
        secure = true;
      } else if (lowerAttr == 'httponly') {
        httpOnly = true;
      }
    }

    Map<String, dynamic>? knownData = _knownCookies[name];
    if (knownData == null) {
      for (final prefix in _prefixKeys) {
        if (name.startsWith(prefix)) {
          knownData = _knownCookies[prefix];
          break;
        }
      }
    }

    // Wildcard consent detection - check if cookie name contains 'consent'
    if (knownData == null && name.toLowerCase().contains('consent')) {
      knownData = {
        'cat': CookieCategory.essential,
        'prov': 'Consent Manager'
      };
    }

    final known = knownData ?? {};

    return CookieInfo(
      name: name,
      value: value,
      domain: domain,
      expires: expires,
      secure: secure,
      httpOnly: httpOnly,
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
      if (name.isEmpty) continue;
      merged[name] = analyze(sc, 'Server');
    }

    final browserList = parseBrowserCookies(browserCookies);
    for (var bc in browserList) {
      if (merged.containsKey(bc.name)) {
        merged[bc.name] = CookieInfo(
            name: bc.name,
            value: bc.value,
            domain: bc.domain,
            expires: bc.expires,
            secure: bc.secure,
            httpOnly: bc.httpOnly,
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
