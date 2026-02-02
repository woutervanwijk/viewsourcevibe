import 'package:flutter/foundation.dart';

/// Extract metadata from the file content
Future<Map<String, dynamic>> extractMetadataInIsolate(
    String html, String baseUrl) async {
  return await compute(
      _extractMetadataInternal, {'html': html, 'baseUrl': baseUrl});
}

Map<String, dynamic> _extractMetadataInternal(Map<String, String> args) {
  final html = args['html']!;
  final baseUrl = args['baseUrl']!;

  final Map<String, dynamic> metadata = {
    'openGraph': <String, String>{},
    'twitter': <String, String>{},
    'rssLinks': <String>[],
    'cssLinks': <String>[],
    'jsLinks': <String>[],
    'iframeLinks': <String>[],
    'externalCssLinks': <String>[],
    'externalJsLinks': <String>[],
    'externalIframeLinks': <String>[],
    'otherMeta': <String, String>{},
    'icons': <String, String>{},
    'detectedTech': <String, String>{},
    'detectedServices': <String, List<String>>{},
    'resourceHints': <String, List<String>>{},
    'pageConfig': <String, String>{},
  };

  // Extract Language from <html> tag
  final langMatch =
      RegExp(r'''<html[^>]*\s+lang=["'](.*?)["']''', caseSensitive: false)
          .firstMatch(html);
  if (langMatch != null) metadata['language'] = langMatch.group(1);

  // Extract Charset
  final charsetMatch =
      RegExp(r'''<meta[^>]*\s+charset=["'](.*?)["']''', caseSensitive: false)
          .firstMatch(html);
  if (charsetMatch != null) {
    metadata['charset'] = charsetMatch.group(1);
  } else {
    // Fallback to http-equiv
    final httpEquivMatch = RegExp(
            r'''<meta[^>]*http-equiv=["']Content-Type["'][^>]*content=["'](.*?charset=(.*?))["']''',
            caseSensitive: false)
        .firstMatch(html);
    if (httpEquivMatch != null) {
      metadata['charset'] = httpEquivMatch.group(2);
    }
  }

  // Extract Title
  final titleMatch =
      RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true, caseSensitive: false)
          .firstMatch(html);
  if (titleMatch != null) metadata['title'] = titleMatch.group(1)?.trim();

  // Extract Meta Tags
  final metaTags =
      RegExp(r'<meta\s+([^>]*?)>', caseSensitive: false).allMatches(html);
  for (final match in metaTags) {
    final attrStr = match.group(1) ?? '';
    final attrs = _parseAttributes(attrStr);

    final name =
        attrs['name']?.toLowerCase() ?? attrs['property']?.toLowerCase();
    final content = attrs['content'];

    if (name != null && content != null) {
      if (name.startsWith('og:')) {
        metadata['openGraph'][name] = content;
      } else if (name.startsWith('twitter:')) {
        metadata['twitter'][name] = content;
      } else if (name == 'description') {
        metadata['description'] = content;
      } else if (name == 'viewport' ||
          name == 'theme-color' ||
          name.startsWith('msapplication-')) {
        metadata['pageConfig'][name] = content;
      } else {
        metadata['otherMeta'][name] = content;
      }
    }
  }

  // Extract Link Tags (CSS, RSS, Favicon)
  final linkTags =
      RegExp(r'<link\s+([^>]*?)>', caseSensitive: false).allMatches(html);
  for (final match in linkTags) {
    final attrStr = match.group(1) ?? '';
    final attrs = _parseAttributes(attrStr);

    final rel = attrs['rel']?.toLowerCase();
    final href = attrs['href'];
    final type = attrs['type']?.toLowerCase();

    if (href != null) {
      final absoluteHref = _resolveUrl(href, baseUrl);
      if (rel == 'stylesheet' || type == 'text/css') {
        if (_isLocalResource(absoluteHref, baseUrl)) {
          metadata['cssLinks'].add(absoluteHref);
        } else {
          metadata['externalCssLinks'].add(absoluteHref);
        }
      } else if (rel == 'alternate' &&
          (type?.contains('rss') == true || type?.contains('atom') == true)) {
        metadata['rssLinks'].add(absoluteHref);
      } else if (rel != null && rel.contains('icon')) {
        metadata['icons'][rel] = absoluteHref;
      } else if (rel == 'canonical' || rel == 'manifest') {
        metadata['pageConfig'][rel!] = absoluteHref;
      } else if (rel == 'search' && type?.contains('opensearch') == true) {
        metadata['pageConfig']['opensearch'] = absoluteHref;
      } else if (rel == 'preload' ||
          rel == 'prefetch' ||
          rel == 'preconnect' ||
          rel == 'dns-prefetch') {
        metadata['resourceHints'].putIfAbsent(rel!, () => []).add(absoluteHref);
      }
    }
  }

  // Extract Script Tags
  final scriptTags =
      RegExp(r'''<script\s+[^>]*src=["'](.*?)["']''', caseSensitive: false)
          .allMatches(html);
  for (final match in scriptTags) {
    final src = match.group(1);
    if (src != null && src.isNotEmpty) {
      final absoluteSrc = _resolveUrl(src, baseUrl);
      if (_isLocalResource(absoluteSrc, baseUrl)) {
        metadata['jsLinks'].add(absoluteSrc);
      } else {
        metadata['externalJsLinks'].add(absoluteSrc);
      }
    }
  }

  // Extract Iframe Tags
  final iframeTags =
      RegExp(r'<iframe\s+([^>]*?)>', caseSensitive: false).allMatches(html);
  for (final match in iframeTags) {
    final attrStr = match.group(1) ?? '';
    final attrs = _parseAttributes(attrStr);
    final src = attrs['src'];
    if (src != null) {
      final absoluteSrc = _resolveUrl(src, baseUrl);
      if (_isLocalResource(absoluteSrc, baseUrl)) {
        metadata['iframeLinks'].add(absoluteSrc);
      } else {
        metadata['externalIframeLinks'].add(absoluteSrc);
      }
    }
  }

  // Refine Image/Favicon from OG/Meta
  metadata['image'] =
      metadata['openGraph']['og:image'] ?? metadata['twitter']['twitter:image'];
  metadata['favicon'] = metadata['icons']['apple-touch-icon'] ??
      metadata['icons']['icon'] ??
      metadata['icons']['shortcut icon'];

  // Detect CMS and Frameworks
  _detectTechnologies(html, metadata);

  // Detect Services (Trackers, Fonts, etc.)
  _detectServices(html, metadata);

  return metadata;
}

/// Guess CMS and Frameworks based on patterns in the HTML
void _detectTechnologies(String html, Map<String, dynamic> metadata) {
  final Map<String, String> tech = {};

  // 1. Check Meta Generator
  final generator = metadata['otherMeta']['generator']?.toLowerCase() ?? '';
  if (generator.contains('wordpress')) {
    tech['CMS'] = 'WordPress';
  } else if (generator.contains('joomla')) {
    tech['CMS'] = 'Joomla';
  } else if (generator.contains('drupal')) {
    tech['CMS'] = 'Drupal';
  } else if (generator.contains('ghost')) {
    tech['CMS'] = 'Ghost';
  } else if (generator.contains('hugo')) {
    tech['Static Site'] = 'Hugo';
  } else if (generator.contains('webflow')) {
    tech['CMS'] = 'Webflow';
  } else if (generator.contains('wix')) {
    tech['CMS'] = 'Wix';
  }

  // 2. Check File Paths and Specific Tags
  if (tech['CMS'] == null) {
    if (html.contains('wp-content') || html.contains('wp-includes')) {
      tech['CMS'] = 'WordPress';
    } else if (html.contains('cdn.shopify.com') ||
        html.contains('shopify-payment-button')) {
      tech['CMS'] = 'Shopify';
    } else if (html.contains('static1.squarespace.com')) {
      tech['CMS'] = 'Squarespace';
    } else if (html.contains('data-wf-page')) {
      tech['CMS'] = 'Webflow';
    }
  }

  // 3. Detect Frontend Frameworks
  if (_hasPattern(html, r'''_next/static|__NEXT_DATA__''')) {
    tech['Framework'] = 'Next.js';
  } else if (_hasPattern(html, r'''__NUXT__''')) {
    tech['Framework'] = 'Nuxt.js';
  } else if (_hasPattern(html, r'''data-reactroot''')) {
    tech['Library'] = 'React';
  } else if (_hasPattern(html, r'''data-v-|v-if=|v-for=''')) {
    tech['Library'] = 'Vue.js';
  } else if (_hasPattern(html, r'''ng-version|ng-app''')) {
    tech['Framework'] = 'Angular';
  }

  // 4. Detect CSS Frameworks
  if (_hasPattern(html,
      r'''bootstrap(?:\.min)?\.css|class=["'][^"']*?\b(?:col-|btn-|navbar-)''')) {
    tech['CSS Framework'] = 'Bootstrap';
  }
  if (_hasPattern(html,
      r'''tailwind(?:\.min)?\.css|class=["'][^"']*?\b(?:text-|bg-|p-|m-|flex-|grid-)''')) {
    // More specific tailwind check to avoid false positives with generic utilities
    if (_hasPattern(html, r'''\b(?:sm:|md:|lg:|xl:|2xl:)[a-z]''')) {
      tech['CSS Framework'] = 'Tailwind CSS';
    }
  }

  metadata['detectedTech'] = tech;
}

/// Detect commonly used services (Trackers, Fonts, Ads, Cloud)
void _detectServices(String html, Map<String, dynamic> metadata) {
  final Map<String, List<String>> services = {
    'Analytics & Trackers': [],
    'Fonts & Icons': [],
    'Advertising': [],
    'Cloud & Infrastructure': [],
    'Social & Widgets': [],
  };

  final patterns = {
    'Analytics & Trackers': {
      'Google Analytics':
          r'google-analytics\.com|googletagmanager\.com/gtag/js|_ga|_gid',
      'Google Tag Manager': r'googletagmanager\.com/gtm\.js',
      'HubSpot Analytics': r'js\.hs-scripts\.com|js\.hs-analytics\.net',
      'Facebook Pixel': r'fbevents\.js|connect\.facebook\.net|fbq\(',
      'Hotjar': r'static\.hotjar\.com|hj\(',
      'Mixpanel': r'cdn\.mxpnl\.com|mixpanel\.init',
      'Segment': r'cdn\.segment\.com|analytics\.js',
      'Crazy Egg': r'script\.crazyegg\.com',
      'Plausible': r'plausible\.io/js/script\.js',
      'Fathom': r'cdn\.usefathom\.com',
      'Mouseflow': r'cdn\.mouseflow\.com',
      'FullStory': r'fullstory\.com/s/fs\.js',
      'Amplitude': r'cdn\.amplitude\.com',
      'Klaviyo': r'static\.klaviyo\.com',
      'Microsoft Clarity': r'www\.clarity\.ms/tag/',
      'Matomo': r'matomo\.js|piwik\.js',
      'Yandex Metrica': r'mc\.yandex\.ru/metrika',
    },
    'Marketing & CRM': {
      'Intercom': r'widget\.intercom\.io',
      'Zendesk': r'static\.zdassets\.com',
      'Drift': r'js\.driftt\.com',
      'Mailchimp': r'chimpstatic\.com',
      'Marketo': r'munchkin\.marketo\.net',
      'Pardot': r'pi\.pardot\.com',
      'Salesforce': r'force\.com',
      'HubSpot CRM': r'js\.hs-scripts\.com',
      'ActiveCampaign': r'trackcmp\.net',
    },
    'Fonts & Icons': {
      'Google Fonts': r'fonts\.googleapis\.com|fonts\.gstatic\.com',
      'Adobe Fonts (Typekit)': r'use\.typekit\.net',
      'Font Awesome': r'font-awesome|fontawesome',
      'Typeform': r'embed\.typeform\.com',
      'Ionicons': r'ionicons\.com',
      'Boxicons': r'boxicons\.com',
    },
    'E-commerce': {
      'Shopify': r'cdn\.shopify\.com|shopify-payment-button',
      'WooCommerce': r'woocommerce\.min\.js|wc-ajax',
      'Magento': r'/mage/|mage-data-init',
      'BigCommerce': r'bigcommerce\.com',
      'BigCartel': r'bigcartel\.com',
      'Stripe': r'js\.stripe\.com',
      'PayPal': r'paypal\.com/sdk/js',
    },
    'Advertising': {
      'Taboola': r'taboola\.com',
      'Google AdSense/DoubleClick':
          r'googlesyndication\.com|adsbygoogle|doubleclick\.net',
      'Outbrain': r'outbrain\.com',
      'Criteo': r'criteo\.com',
      'Pinterest Tag': r'assets\.pinterest\.com/js/pinit\.js|pintrk\(',
      'TikTok Pixel': r'analytics\.tiktok\.com/i18n/pixel/sdk\.js',
      'LinkedIn Insight':
          r'snap\.licdn\.com/li\.lms-analytics/insight\.min\.js',
      'Amazon Advertising': r'amazon-adsystem\.com',
      'Snap Pixel': r'sc-static\.net/scevent\.min\.js',
      'Reddit Pixel': r'redditstatic\.com/ads/pixel\.js',
    },
    'Cloud, CDN & Infrastructure': {
      'Amazon Web Services (AWS)':
          r'amazonaws\.com|aws\.amazon\.com|s3\.amazonaws\.com',
      'Firebase': r'firebasejs|firebase\.google\.com',
      'Microsoft Azure': r'azure\.com|windows\.net',
      'Cloudflare': r'cloudflare\.com|/cdn-cgi/|cloudflare-static',
      'Vercel': r'vercel\.app|vercel\.com',
      'Netlify': r'netlify\.app|netlify\.com',
      'Fastly': r'fastly\.net',
      'Akamai': r'akamai\.net',
      'DigitalOcean': r'digitalocean\.com',
      'Heroku': r'herokuapp\.com',
      'BunnyCDN': r'bunnycdn\.com',
    },
    'Social & Widgets': {
      'Twitter/X': r'platform\.twitter\.com',
      'LinkedIn': r'platform\.linkedin\.com',
      'Instagram': r'instagram\.com/embed',
      'YouTube': r'youtube\.com/embed|ytimg\.com',
      'Disqus': r'disqus\.com',
      'WhatsApp': r'wa\.me',
      'Telegram': r't\.me',
      'Facebook Chat': r'connect\.facebook\.net/.*xfbml\.customerchat\.js',
      'Spotify': r'open\.spotify\.com/embed',
      'Apple Music': r'embed\.music\.apple\.com',
    }
  };

  patterns.forEach((category, items) {
    items.forEach((name, pattern) {
      if (_hasPattern(html, pattern)) {
        services[category]!.add(name);
      }
    });
  });

  // Remove empty categories
  services.removeWhere((key, value) => value.isEmpty);

  metadata['detectedServices'] = services;
}

bool _hasPattern(String text, String pattern) {
  return RegExp(pattern, caseSensitive: false).hasMatch(text);
}

Map<String, String> _parseAttributes(String attrStr) {
  final Map<String, String> attrs = {};
  // Regex to match attributes like name="value" or property="value" or rel='value'
  final regExp =
      RegExp(r'''([a-zA-Z0-9:-]+)\s*=\s*["'](.*?)["']''', caseSensitive: false);
  for (final match in regExp.allMatches(attrStr)) {
    attrs[match.group(1)!] = match.group(2)!;
  }
  return attrs;
}

bool _isLocalResource(String url, String baseUrl) {
  if (url.isEmpty || baseUrl.isEmpty) return true;
  try {
    final uri = Uri.parse(url);
    final base = Uri.parse(baseUrl);

    // If it's a relative URL or has no host, it's local
    if (!uri.hasAuthority || uri.host.isEmpty) return true;

    final resourceHost = uri.host.toLowerCase();
    final baseHost = base.host.toLowerCase();

    if (resourceHost == baseHost) return true;

    // Check if it's a subdomain
    if (resourceHost.endsWith('.$baseHost')) return true;

    return false;
  } catch (e) {
    return true; // Assume local on parse error
  }
}

String _resolveUrl(String url, String baseUrl) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (baseUrl.isEmpty) return url;
  try {
    final base = Uri.parse(baseUrl);
    return base.resolve(url).toString();
  } catch (e) {
    return url;
  }
}
