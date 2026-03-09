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
    'cX_G': {'cat': CookieCategory.analytics, 'prov': 'Piano (Cxense)'},
    'cx_P': {'cat': CookieCategory.analytics, 'prov': 'Piano (Cxense)'},
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
