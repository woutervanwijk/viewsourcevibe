import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart' as xml;

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
    'openGraph': <String, dynamic>{},
    'twitter': <String, dynamic>{},
    'rssLinks': <dynamic>[],
    'cssLinks': <dynamic>[],
    'jsLinks': <dynamic>[],
    'iframeLinks': <dynamic>[],
    'externalCssLinks': <dynamic>[],
    'externalJsLinks': <dynamic>[],
    'externalIframeLinks': <dynamic>[],
    'otherMeta': <String, dynamic>{},
    'icons': <String, dynamic>{},
    'detectedTech': <String, dynamic>{},
    'detectedServices': <String, List<String>>{},
    'resourceHints': <String, List<String>>{},
    'pageConfig': <String, dynamic>{},
    'media': {
      'images': <Map<String, dynamic>>[],
      'videos': <Map<String, dynamic>>[],
    },
    'article': <String, dynamic>{},
  };

  // Determine if we should use HTML or XML parser
  // Simple heuristic: if it looks like SVG or specific XML, use XML parser
  final lowerHtml = html.trimLeft().toLowerCase();
  final isXml = lowerHtml.startsWith('<?xml') || lowerHtml.startsWith('<svg');

  if (isXml) {
    try {
      final doc = xml.XmlDocument.parse(html);
      _extractFromXml(doc, metadata, baseUrl);
    } catch (e) {
      debugPrint(
          'MetadataParser: XML parsing failed, falling back to HTML: $e');
      final doc = html_parser.parse(html);
      _extractFromHtml(doc, metadata, baseUrl);
    }
  } else {
    final doc = html_parser.parse(html);
    _extractFromHtml(doc, metadata, baseUrl);
  }

  // Refine Image/Favicon from OG/Meta
  metadata['image'] =
      metadata['openGraph']['og:image'] ?? metadata['twitter']['twitter:image'];
  metadata['favicon'] = metadata['icons']['apple-touch-icon'] ??
      metadata['icons']['icon'] ??
      metadata['icons']['shortcut icon'];

  // Detect CMS and Frameworks (regex on full HTML still useful for quick checks)
  _detectTechnologies(html, metadata);

  // Detect Services (Trackers, Fonts, etc.)
  _detectServices(html, metadata);

  // Extract info from JSON-LD
  _extractJsonLdInfo(html, metadata);

  return metadata;
}

void _extractFromHtml(
    dom.Document doc, Map<String, dynamic> metadata, String baseUrl) {
  int imageOrder = 0;

  final Set<String> seenCssUrls = {};
  final Set<String> seenJsUrls = {};
  final Set<String> seenImageKeys = {};
  final Set<String> seenContentKeys = {};

  // Language from <html>
  final htmlTag = doc.querySelector('html');
  if (htmlTag != null) {
    metadata['language'] = htmlTag.attributes['lang'];
  }

  // Charset from <meta charset> or <meta http-equiv>
  final metaCharset = doc.querySelector('meta[charset]');
  if (metaCharset != null) {
    metadata['charset'] = metaCharset.attributes['charset'];
  } else {
    final httpEquiv = doc.querySelector('meta[http-equiv="Content-Type"]');
    if (httpEquiv != null) {
      final content = httpEquiv.attributes['content'];
      if (content != null && content.contains('charset=')) {
        metadata['charset'] = content.split('charset=').last.trim();
      }
    }
  }

  // Title
  final title = doc.querySelector('title');
  if (title != null) {
    metadata['title'] = title.text.trim();
  }

  // Meta Tags
  final metas = doc.querySelectorAll('meta');
  for (final meta in metas) {
    final name = meta.attributes['name']?.toLowerCase() ??
        meta.attributes['property']?.toLowerCase() ??
        meta.attributes['itemprop']?.toLowerCase();
    final content = meta.attributes['content'];

    if (name != null && content != null) {
      if (name.startsWith('og:')) {
        metadata['openGraph'][name] = content;
        if (name == 'og:article:author' || name == 'article:author') {
          metadata['article']['Author'] = content;
        } else if (name == 'og:article:published_time' ||
            name == 'article:published_time') {
          metadata['article']['Published'] = content;
        } else if (name == 'og:article:modified_time' ||
            name == 'article:modified_time') {
          metadata['article']['Modified'] = content;
        }
      } else if (name.startsWith('twitter:')) {
        metadata['twitter'][name] = content;
        if (name == 'twitter:creator') {
          metadata['article']['Twitter Creator'] = content;
        }
      } else if (name == 'description') {
        metadata['description'] = content;
      } else if (name == 'author') {
        metadata['article']['Author'] = content;
      } else if (name == 'keywords') {
        metadata['article']['Keywords'] = content;
      } else if ([
        'publish-date',
        'pubdate',
        'date',
        'datepublished',
        'dc.date.issued'
      ].contains(name)) {
        metadata['article']['Published'] = content;
      } else if ([
        'datemodified',
        'revised',
        'last-modified',
        'dc.date.modified'
      ].contains(name)) {
        metadata['article']['Modified'] = content;
      } else if (name == 'viewport' ||
          name == 'theme-color' ||
          name.startsWith('msapplication-')) {
        metadata['pageConfig'][name] = content;
      } else {
        metadata['otherMeta'][name] = content;
      }
    }
  }

  // Link Tags (CSS, RSS, Favicon)
  final links = doc.querySelectorAll('link');
  for (final link in links) {
    final rel = link.attributes['rel']?.toLowerCase();
    final href = link.attributes['href'];
    final type = link.attributes['type']?.toLowerCase();

    if (href != null) {
      final absoluteHref = _resolveUrl(href, baseUrl);
      if (rel == 'stylesheet' || type == 'text/css') {
        final normalizationKey = _normalizeUrl(absoluteHref);
        if (!seenCssUrls.contains(normalizationKey)) {
          seenCssUrls.add(normalizationKey);
          if (_isLocalResource(absoluteHref, baseUrl)) {
            metadata['cssLinks'].add(absoluteHref);
          } else {
            metadata['externalCssLinks'].add(absoluteHref);
          }
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
      } else if (['preload', 'prefetch', 'preconnect', 'dns-prefetch']
          .contains(rel)) {
        metadata['resourceHints']
            .putIfAbsent(rel!, () => <String>[])
            .add(absoluteHref);
      }
    }
  }

  // Scripts
  final scripts = doc.querySelectorAll('script[src]');
  for (final script in scripts) {
    final src = script.attributes['src'];
    if (src != null && src.isNotEmpty) {
      final absoluteSrc = _resolveUrl(src, baseUrl);
      final normalizationKey = _normalizeUrl(absoluteSrc);
      if (!seenJsUrls.contains(normalizationKey)) {
        seenJsUrls.add(normalizationKey);
        if (_isLocalResource(absoluteSrc, baseUrl)) {
          metadata['jsLinks'].add(absoluteSrc);
        } else {
          metadata['externalJsLinks'].add(absoluteSrc);
        }
      }
    }
  }

  // Iframes
  final iframes = doc.querySelectorAll('iframe');
  for (final iframe in iframes) {
    final src = iframe.attributes['src'];
    if (src != null && src.isNotEmpty) {
      final absoluteSrc = _resolveUrl(src, baseUrl);
      if (_isLocalResource(absoluteSrc, baseUrl)) {
        metadata['iframeLinks'].add(absoluteSrc);
      } else {
        metadata['externalIframeLinks'].add(absoluteSrc);
        final lowerSrc = absoluteSrc.toLowerCase();
        if (lowerSrc.contains('youtube.com/embed') ||
            lowerSrc.contains('player.vimeo.com/video')) {
          metadata['media']['videos'].add({
            'src': absoluteSrc,
            'type': 'iframe',
            'provider': lowerSrc.contains('youtube') ? 'YouTube' : 'Vimeo',
          });
        }
      }
    }
  }

  // Images
  final imgs = doc.querySelectorAll('img');
  for (final img in imgs) {
    final attrs = img.attributes;

    final candidates = [
      attrs['data-src'],
      attrs['data-lazy-src'],
      attrs['data-original'],
      attrs['data-fallback-src'],
      attrs['src'],
    ];

    String? finalSrc;
    for (final candidate in candidates) {
      if (candidate != null &&
          candidate.isNotEmpty &&
          !candidate.startsWith('data:image')) {
        finalSrc = candidate;
        break;
      }
    }

    finalSrc ??= attrs['src'];

    // Handle srcset
    String? srcset = attrs['data-srcset'] ?? attrs['srcset'];
    if ((finalSrc == null ||
            finalSrc.isEmpty ||
            finalSrc.startsWith('data:')) &&
        srcset != null) {
      try {
        final candidateUrls = srcset
            .split(',')
            .map((s) => s.trim().split(' ').first)
            .where((s) => s.isNotEmpty);
        if (candidateUrls.isNotEmpty) {
          finalSrc = candidateUrls.last;
        }
      } catch (e) {
        debugPrint('Error parsing srcset: $e');
      }
    }

    if (finalSrc != null && finalSrc.isNotEmpty) {
      if (finalSrc.startsWith('data:')) {
        // Deduplicate data URIs by content fingerprint
        if (!seenContentKeys.contains(finalSrc)) {
          seenContentKeys.add(finalSrc);
          metadata['media']['images'].add({
            'src': finalSrc,
            'alt': attrs['alt'] ?? 'Embedded Image',
            'title': attrs['title'] ?? '',
            'type': 'base64',
            'order': imageOrder++,
          });
        }
      } else {
        final absoluteSrc = _resolveUrl(finalSrc, baseUrl);
        final normalizationKey = _normalizeUrl(absoluteSrc);

        if (!seenImageKeys.contains(normalizationKey)) {
          seenImageKeys.add(normalizationKey);
          metadata['media']['images'].add({
            'src': absoluteSrc,
            'alt': attrs['alt'] ?? '',
            'title': attrs['title'] ?? '',
            'order': imageOrder++,
          });
        }
      }
    }
  }

  // Inline SVGs
  final svgs = doc.querySelectorAll('svg');
  for (final svg in svgs) {
    try {
      final fullSvg = svg.outerHtml;
      // Use the raw HTML as the content key for SVGs
      // This catches duplicates even if they are embedded differently
      if (seenContentKeys.contains(fullSvg)) continue;
      seenContentKeys.add(fullSvg);

      final encoded = base64Encode(utf8.encode(fullSvg));
      metadata['media']['images'].add({
        'src': 'data:image/svg+xml;base64,$encoded',
        'alt': 'Inline SVG Code',
        'title': 'Extracted from <svg> tag',
        'type': 'base64',
        'order': imageOrder++,
      });
    } catch (e) {
      debugPrint('Error encoding inline SVG: $e');
    }
  }

  // Videos
  final videos = doc.querySelectorAll('video');
  for (final video in videos) {
    final src = video.attributes['src'];
    if (src != null && src.isNotEmpty) {
      metadata['media']['videos'].add({
        'src': _resolveUrl(src, baseUrl),
        'type': 'video-tag',
      });
    }
  }

  final sources = doc.querySelectorAll('source');
  for (final source in sources) {
    final src = source.attributes['src'];
    if (src != null && src.isNotEmpty) {
      metadata['media']['videos'].add({
        'src': _resolveUrl(src, baseUrl),
        'type': 'source-tag',
        'mimeType': source.attributes['type'] ?? '',
      });
    }
  }
}

String _normalizeUrl(String url) {
  if (url.startsWith('data:')) return url;
  try {
    final uri = Uri.parse(url);
    if (uri.queryParameters.isEmpty) return url;

    final cleanParams = Map<String, String>.from(uri.queryParameters);
    const cacheBusters = {'v', 'ver', 't', 'hash', 'version', '_', 'ts'};
    bool changed = false;
    cleanParams.removeWhere((key, _) {
      if (cacheBusters.contains(key.toLowerCase())) {
        changed = true;
        return true;
      }
      return false;
    });

    if (!changed) return url;

    return uri
        .replace(
          queryParameters: cleanParams.isEmpty ? null : cleanParams,
        )
        .toString();
  } catch (_) {
    return url;
  }
}

void _extractFromXml(
    xml.XmlDocument doc, Map<String, dynamic> metadata, String baseUrl) {
  // Very basic XML extraction for now, mainly for SVGs being viewed as XML
  final svg = doc.findAllElements('svg').firstOrNull;
  if (svg != null) {
    try {
      final fullSvg = svg.toXmlString();
      final encoded = base64Encode(utf8.encode(fullSvg));
      metadata['media']['images'].add({
        'src': 'data:image/svg+xml;base64,$encoded',
        'alt': 'XML SVG Content',
        'title': 'Extracted from XML root',
        'type': 'base64',
      });
    } catch (e) {
      debugPrint('Error encoding XML SVG: $e');
    }
  }

  // RSS/Atom specific extraction could be added here if needed,
  // but they are usually handled by the BrowserView's RSS rendering logic.
}

/// Extract info from JSON-LD script tags
void _extractJsonLdInfo(String html, Map<String, dynamic> metadata) {
  final jsonLdTags = RegExp(
          r'''<script[^>]+type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>''',
          caseSensitive: false)
      .allMatches(html);

  for (final match in jsonLdTags) {
    try {
      final jsonStr = match.group(1)?.trim() ?? '';
      if (jsonStr.isEmpty) continue;

      // Basic regex-based extraction to avoid full JSON parsing issues in simple regex parser
      final authorMatch = RegExp(
              r'"author"\s*:\s*(?:{\s*"name"\s*:\s*"([^"]+)"|"[^"]+")',
              caseSensitive: false)
          .firstMatch(jsonStr);
      if (authorMatch != null) {
        final author = authorMatch.group(1) ??
            authorMatch.group(0)!.split(':').last.replaceAll('"', '').trim();
        if (author.isNotEmpty && metadata['article']['Author'] == null) {
          metadata['article']['Author'] = author;
        }
      }

      final datePublishedMatch =
          RegExp(r'"datePublished"\s*:\s*"([^"]+)"', caseSensitive: false)
              .firstMatch(jsonStr);
      if (datePublishedMatch != null &&
          metadata['article']['Published'] == null) {
        metadata['article']['Published'] = datePublishedMatch.group(1);
      }

      final dateModifiedMatch =
          RegExp(r'"dateModified"\s*:\s*"([^"]+)"', caseSensitive: false)
              .firstMatch(jsonStr);
      if (dateModifiedMatch != null &&
          metadata['article']['Modified'] == null) {
        metadata['article']['Modified'] = dateModifiedMatch.group(1);
      }

      final publisherMatch = RegExp(
              r'"publisher"\s*:\s*(?:{\s*"name"\s*:\s*"([^"]+)"|"[^"]+")',
              caseSensitive: false)
          .firstMatch(jsonStr);
      if (publisherMatch != null) {
        final publisher = publisherMatch.group(1) ??
            publisherMatch.group(0)!.split(':').last.replaceAll('"', '').trim();
        if (publisher.isNotEmpty) {
          metadata['article']['Publisher'] = publisher;
        }
      }
    } catch (e) {
      debugPrint('Error parsing JSON-LD: $e');
    }
  }
}

/// Guess CMS and Frameworks based on patterns in the HTML
void _detectTechnologies(String html, Map<String, dynamic> metadata) {
  final Map<String, String> tech = {};

  final generator = metadata['otherMeta']['generator']?.toLowerCase() ?? '';
  if (generator.contains('wordpress')) {
    tech['CMS'] = 'WordPress';
  } else if (generator.contains('joomla')) {
    tech['CMS'] = 'Joomla';
  } else if (generator.contains('drupal')) {
    tech['CMS'] = 'Drupal';
  } else if (generator.contains('prestashop')) {
    tech['CMS'] = 'PrestaShop';
  } else if (generator.contains('ghost')) {
    tech['CMS'] = 'Ghost';
  } else if (generator.contains('hugo')) {
    tech['Static Site'] = 'Hugo';
  } else if (generator.contains('webflow')) {
    tech['CMS'] = 'Webflow';
  } else if (generator.contains('wix')) {
    tech['CMS'] = 'Wix';
  } else if (generator.contains('shopify')) {
    tech['CMS'] = 'Shopify';
  } else if (generator.contains('prestashop')) {
    tech['CMS'] = 'PrestaShop';
  } else if (generator.contains('bitrix')) {
    tech['CMS'] = '1C-Bitrix';
  } else if (generator.contains('docusaurus')) {
    tech['Static Site'] = 'Docusaurus';
  } else if (generator.contains('gatsby')) {
    tech['Static Site'] = 'Gatsby';
  } else if (generator.contains('astro')) {
    tech['Static Site'] = 'Astro';
  }

  // Path and Pattern-based CMS detection
  if (tech['CMS'] == null && tech['Static Site'] == null) {
    if (html.contains('wp-content') || html.contains('wp-includes')) {
      tech['CMS'] = 'WordPress';
    } else if (html.contains('/templates/') &&
        (html.contains('/media/jui/') || html.contains('/media/system/'))) {
      tech['CMS'] = 'Joomla';
    } else if (html.contains('/sites/all/modules/') ||
        html.contains('/sites/default/files/')) {
      tech['CMS'] = 'Drupal';
    } else if (html.contains('/modules/') &&
        (html.contains('prestashop') || html.contains('/themes/'))) {
      // PrestaShop often has themes/[theme]/assets/ or modules/[module]
      if (html.contains('var prestashop =') ||
          html.contains('id_product_attribute')) {
        tech['CMS'] = 'PrestaShop';
      }
    } else if (html.contains('cdn.shopify.com') ||
        html.contains('shopify-payment-button')) {
      tech['CMS'] = 'Shopify';
    } else if (html.contains('static1.squarespace.com')) {
      tech['CMS'] = 'Squarespace';
    } else if (html.contains('data-wf-page')) {
      tech['CMS'] = 'Webflow';
    } else if (html.contains('contentful.com')) {
      tech['CMS'] = 'Contentful';
    } else if (html.contains('umbraco')) {
      tech['CMS'] = 'Umbraco';
    } else if (html.contains('sitecore')) {
      tech['CMS'] = 'Sitecore';
    } else if (html.contains('adobe-experience-manager') ||
        html.contains('aem')) {
      tech['CMS'] = 'Adobe Experience Manager';
    }
  }

  // Plugin & Extension Detection
  final List<String> plugins = [];
  if (tech['CMS'] == 'WordPress') {
    if (html.contains('woocommerce') ||
        html.contains('/plugins/woocommerce/')) {
      plugins.add('WooCommerce');
    }
    if (html.contains('elementor') || html.contains('elementor-section')) {
      plugins.add('Elementor');
    }
    if (html.contains('Yoast SEO') ||
        html.contains('/plugins/wordpress-seo/')) {
      plugins.add('Yoast SEO');
    }
    if (html.contains('Rank Math') || html.contains('rank-math-')) {
      plugins.add('Rank Math');
    }
    if (html.contains('wpcf7') || html.contains('contact-form-7')) {
      plugins.add('Contact Form 7');
    }
    if (html.contains('wp-rocket') || html.contains('WP Rocket')) {
      plugins.add('WP Rocket');
    }
    if (html.contains('W3 Total Cache') || html.contains('/w3-total-cache/')) {
      plugins.add('W3 Total Cache');
    }
    if (html.contains('js-composer') || html.contains('wpb-js-composer')) {
      plugins.add('WPBakery Page Builder');
    }
    if (html.contains('revslider') || html.contains('Slider Revolution')) {
      plugins.add('Slider Revolution');
    }
  } else if (tech['CMS'] == 'Joomla') {
    if (html.contains('com_virtuemart')) plugins.add('VirtueMart');
    if (html.contains('com_rsform')) plugins.add('RSForm');
    if (html.contains('com_jce')) plugins.add('JCE Editor');
    if (html.contains('com_k2')) plugins.add('K2');
  } else if (tech['CMS'] == 'Drupal') {
    if (html.contains('views-view')) plugins.add('Views');
    if (html.contains('webform-client-form')) plugins.add('Webform');
  }

  if (plugins.isNotEmpty) {
    tech['Plugins'] = plugins.join(', ');
  }

  // Frameworks & Libraries
  if (_hasPattern(html, r'''_next/static|__NEXT_DATA__''')) {
    tech['Framework'] = 'Next.js';
  } else if (_hasPattern(html, r'''__NUXT__''')) {
    tech['Framework'] = 'Nuxt.js';
  } else if (_hasPattern(html, r'''_sveltekit''')) {
    tech['Framework'] = 'SvelteKit';
  } else if (_hasPattern(html, r'''data-reactroot''')) {
    tech['Library'] = 'React';
  } else if (_hasPattern(html, r'''data-v-|v-if=|v-for=''')) {
    tech['Library'] = 'Vue.js';
  } else if (_hasPattern(html, r'''ng-version|ng-app''')) {
    tech['Framework'] = 'Angular';
  } else if (_hasPattern(html, r'''jquery(?:\.min)?\.js''')) {
    tech['Library'] = 'jQuery';
  } else if (html.contains('x-data=') || html.contains('x-init=')) {
    tech['Library'] = 'Alpine.js';
  } else if (html.contains('hx-get=') || html.contains('hx-post=')) {
    tech['Library'] = 'HTMX';
  }

  // CSS Frameworks
  if (_hasPattern(html,
      r'''bootstrap(?:\.min)?\.css|class=["'][^"']*?\b(?:col-|btn-|navbar-)''')) {
    tech['CSS Framework'] = 'Bootstrap';
  }
  if (_hasPattern(html,
      r'''tailwind(?:\.min)?\.css|class=["'][^"']*?\b(?:text-|bg-|p-|m-|flex-|grid-)''')) {
    if (_hasPattern(html, r'''\b(?:sm:|md:|lg:|xl:|2xl:)[a-z]''')) {
      tech['CSS Framework'] = 'Tailwind CSS';
    }
  }
  if (html.contains('bulma') || html.contains('is-primary')) {
    tech['CSS Framework'] = 'Bulma';
  } else if (html.contains('uk-')) {
    tech['CSS Framework'] = 'UIkit';
  } else if (html.contains('foundation.min.css')) {
    tech['CSS Framework'] = 'Foundation';
  } else if (html.contains('mdc-')) {
    tech['CSS Framework'] = 'Material Components';
  }

  metadata['detectedTech'] = tech;
}

/// Detect commonly used services (Trackers, Fonts, Ads, Cloud)
void _detectServices(String html, Map<String, dynamic> metadata) {
  final Map<String, List<String>> services = {
    'Analytics & Trackers': <String>[],
    'Marketing & CRM': <String>[],
    'Fonts & Icons': <String>[],
    'E-commerce': <String>[],
    'Advertising': <String>[],
    'Cloud, CDN & Infrastructure': <String>[],
    'Social & Widgets': <String>[],
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
      'Smartlook': r'cdn\.smartlook\.com',
      'Lucky Orange': r'cdn\.luckyorange\.com',
      'Heap': r'heapanalytics\.com',
    },
    'Marketing & CRM': {
      'Intercom': r'widget\.intercom\.io',
      'Zendesk': r'static\.zdassets\.com',
      'Drift': r'js\.driftt\.com',
      'Crisp': r'client\.crisp\.chat',
      'Tawk.to': r'embed\.tawk\.to',
      'Chatwoot': r'chatwoot\.js',
      'Mailchimp': r'chimpstatic\.com',
      'Marketo': r'munchkin\.marketo\.net',
      'Pardot': r'pi\.pardot\.com',
      'Salesforce': r'force\.com',
      'HubSpot CRM': r'js\.hs-scripts\.com',
      'ActiveCampaign': r'trackcmp\.net',
    },
    'Privacy & Consent Management': {
      'Cookiebot': r'cookiebot\.com',
      'OneTrust': r'onetrust\.com|otSDKStub\.js',
      'Usercentrics': r'usercentrics\.eu|app\.usercentrics\.eu',
      'TrustArc': r'trustarc\.com',
      'CookieYes': r'cookieyes\.com',
      'Osano': r'osano\.com',
      'Cassie': r'cassie\.eu',
    },
    'Fonts & Icons': {
      'Google Fonts': r'fonts\.googleapis\.com|fonts\.gstatic\.com',
      'Adobe Fonts (Typekit)': r'use\.typekit\.net',
      'Font Awesome': r'font-awesome|fontawesome',
      'Typeform': r'embed\.typeform\.com',
      'Ionicons': r'ionicons\.com',
      'Boxicons': r'boxicons\.com',
      'Feather Icons': r'feathericons\.com',
    },
    'E-commerce': {
      'Shopify': r'cdn\.shopify\.com|shopify-payment-button',
      'WooCommerce': r'woocommerce\.min\.js|wc-ajax',
      'Magento': r'/mage/|mage-data-init',
      'BigCommerce': r'bigcommerce\.com',
      'BigCartel': r'bigcartel\.com',
      'Stripe': r'js\.stripe\.com',
      'PayPal': r'paypal\.com/sdk/js',
      'Klarna': r'klarnacdn\.net',
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
      'AdRoll': r'adroll\.com',
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
      'StackPath': r'stackpathcdn\.com',
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
      'AddThis': r'addthis\.com',
      'ShareThis': r'sharethis\.com',
    }
  };

  patterns.forEach((category, items) {
    items.forEach((name, pattern) {
      if (_hasPattern(html, pattern)) {
        services[category]!.add(name);
      }
    });
  });

  services.removeWhere((key, value) => value.isEmpty);
  metadata['detectedServices'] = services;
}

bool _hasPattern(String text, String pattern) {
  return RegExp(pattern, caseSensitive: false).hasMatch(text);
}

bool _isLocalResource(String url, String baseUrl) {
  if (url.isEmpty || baseUrl.isEmpty) return true;
  try {
    final uri = Uri.parse(url);
    final base = Uri.parse(baseUrl);
    if (!uri.hasAuthority || uri.host.isEmpty) return true;
    final resourceHost = uri.host.toLowerCase();
    final baseHost = base.host.toLowerCase();
    if (resourceHost == baseHost) return true;
    if (resourceHost.endsWith('.$baseHost')) return true;
    return false;
  } catch (e) {
    return true;
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
