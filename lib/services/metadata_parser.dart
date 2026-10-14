import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart' as xml;
import 'package:view_source_vibe/models/detection_evidence.dart';

/// Extract metadata from the file content
Future<Map<String, dynamic>> extractMetadataInIsolate(
    String html, String baseUrl,
    {Map<String, String>? headers}) async {
  return await compute(_extractMetadataInternal,
      {'html': html, 'baseUrl': baseUrl, 'headers': headers});
}

Map<String, dynamic> _extractMetadataInternal(Map<String, dynamic> args) {
  final html = args['html'] as String;
  final baseUrl = args['baseUrl'] as String;
  final headers = args['headers'] as Map<String, String>?;

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
    'structuredData': <Map<String, dynamic>>[],
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

  // Detect CMS and Frameworks (regex on full HTML + Headers)
  _detectTechnologies(html, metadata, headers);

  // Detect Services (Trackers, Fonts, etc.)
  _detectServices(html, metadata);

  // Extract info from JSON-LD
  // We need a doc for this. If we used XML parser, we might not have a html.Document.
  // But JSON-LD is usually in HTML.
  if (!isXml) {
    // Re-use the doc from earlier if possible, but we need to declare it outside
    // To avoid massive refactor, let's just parse it if we haven't or...
    // Actually, let's change how we call it.
    // The doc was created in lines 55 or 59.
    // But they are local variables in if/else blocks.

    // Let's refactor the flow slightly to expose doc?
    // Or just re-parse? Re-parsing is expensive.
    // Better: Move _extractJsonLdInfo call INTO _extractFromHtml.
  }

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
    if (src != null && src.isNotEmpty && src != 'about:blank') {
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
  // Extract info from JSON-LD
  _extractJsonLdInfo(doc, metadata);
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
void _extractJsonLdInfo(dom.Document doc, Map<String, dynamic> metadata) {
  final jsonLdScripts =
      doc.querySelectorAll('script[type="application/ld+json"]');

  for (final script in jsonLdScripts) {
    try {
      final jsonStr = script.text.trim();
      if (jsonStr.isEmpty) continue;

      // Parse JSON directly instead of regex
      // This is safer and more robust than regex on raw string
      final dynamic jsonData = jsonDecode(jsonStr);

      if (jsonData is Map<String, dynamic>) {
        metadata['structuredData'].add(jsonData);
        _processJsonLdObject(jsonData, metadata);
      } else if (jsonData is List) {
        for (final item in jsonData) {
          if (item is Map<String, dynamic>) {
            metadata['structuredData'].add(item);
            _processJsonLdObject(item, metadata);
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing JSON-LD: $e');
    }
  }
}

void _processJsonLdObject(
    Map<String, dynamic> json, Map<String, dynamic> metadata) {
  try {
    // Author
    if (metadata['article']['Author'] == null) {
      final author = json['author'];
      if (author is Map) {
        metadata['article']['Author'] = author['name'];
      } else if (author is String) {
        metadata['article']['Author'] = author;
      } else if (author is List && author.isNotEmpty) {
        final firstAuthor = author.first;
        if (firstAuthor is Map) {
          metadata['article']['Author'] = firstAuthor['name'];
        } else if (firstAuthor is String) {
          metadata['article']['Author'] = firstAuthor;
        }
      }
    }

    // Date Published
    if (metadata['article']['Published'] == null) {
      if (json['datePublished'] is String) {
        metadata['article']['Published'] = json['datePublished'];
      }
    }

    // Date Modified
    if (metadata['article']['Modified'] == null) {
      if (json['dateModified'] is String) {
        metadata['article']['Modified'] = json['dateModified'];
      }
    }

    // Publisher
    if (metadata['article']['Publisher'] == null) {
      final publisher = json['publisher'];
      if (publisher is Map) {
        metadata['article']['Publisher'] = publisher['name'];
      } else if (publisher is String) {
        metadata['article']['Publisher'] = publisher;
      }
    }
  } catch (e) {
    debugPrint('Error processing JSON-LD object: $e');
  }
}

/// Guess CMS and Frameworks based on patterns in the HTML and Headers
/// A hostname on its own in quotes (e.g. `"doubleclick.net"` in a JSON
/// config list) is data, not a resource being loaded.
bool _isQuotedBareHost(String html, Match match) {
  final text = match[0] ?? '';
  if (!RegExp(r'^[a-z0-9.-]+\.[a-z]{2,}$', caseSensitive: false)
      .hasMatch(text)) {
    return false;
  }
  // Extend to the full hostname around the match.
  var start = match.start, end = match.end;
  final hostChar = RegExp(r'[a-zA-Z0-9.-]');
  while (start > 0 && hostChar.hasMatch(html[start - 1])) {
    start--;
  }
  while (end < html.length && hostChar.hasMatch(html[end])) {
    end++;
  }
  const quotes = {'"', "'"};
  return start > 0 &&
      end < html.length &&
      quotes.contains(html[start - 1]) &&
      quotes.contains(html[end]);
}

/// Index ranges of HTML comments; code inside them is not active.
List<(int, int)> _commentRanges(String html) => [
      for (final m in RegExp(r'<!--[\s\S]*?-->').allMatches(html))
        (m.start, m.end)
    ];

/// Whether [index] is inside markup or script/style code, rather than in an
/// HTML comment or visible text (e.g. a cookie banner naming doubleclick.net).
bool _isActiveCode(String lowerHtml, int index, List<(int, int)> comments) {
  if (comments.any((c) => index >= c.$1 && index < c.$2)) return false;
  for (final tag in ['script', 'style']) {
    if (lowerHtml.lastIndexOf('<$tag', index) >
        lowerHtml.lastIndexOf('</$tag', index)) {
      return true;
    }
  }
  return lowerHtml.lastIndexOf('<', index) > lowerHtml.lastIndexOf('>', index);
}

void _detectTechnologies(
    String html, Map<String, dynamic> metadata, Map<String, String>? headers) {
  final Map<String, String> tech = {};
  final Map<String, List<Map<String, dynamic>>> evidence = {};
  // Evidence of matches since the last detection; a failed check discards it.
  var pending = <Map<String, dynamic>>[];

  // Comments count here: they often carry signatures ("optimized with Yoast").
  bool has(String needle) {
    final index = html.indexOf(needle);
    if (index < 0) {
      pending = [];
      return false;
    }
    pending.add(DetectionEvidence.htmlAt(html, index, match: needle).toMap());
    return true;
  }

  bool pattern(String regex) {
    final match = RegExp(regex, caseSensitive: false).firstMatch(html);
    if (match == null) {
      pending = [];
      return false;
    }
    pending.add(
        DetectionEvidence.htmlAt(html, match.start, match: match[0]).toMap());
    return true;
  }

  bool header(String name, String value, String needle) {
    if (!value.contains(needle)) return false;
    pending.add(DetectionEvidence(EvidenceKind.header, 'Response header $name',
            detail: '$name: $value')
        .toMap());
    return true;
  }

  void set(String key, String value) {
    tech[key] = value;
    evidence[key] = pending;
    pending = [];
  }

  // 1. Header-based Detection (Backend, Server, Caching)
  if (headers != null) {
    final server = headers['server'];
    final xPoweredBy = headers['x-powered-by'];
    final via = headers['via'];
    // Check Cookies only via Set-Cookie header if strictly needed,
    // but usually 'cookies' list is better if available (not passed here yet).
    // We can check Set-Cookie in headers if present as a single string or fallback.

    if (server != null) {
      if (header('Server', server, 'nginx')) set('Web Server', 'Nginx');
      if (header('Server', server, 'Apache')) set('Web Server', 'Apache');
      if (header('Server', server, 'Cloudflare')) set('CDN', 'Cloudflare');
      if (header('Server', server, 'Netlify')) set('CDN', 'Netlify');
      if (header('Server', server, 'Vercel')) set('Platform', 'Vercel');
      if (header('Server', server, 'GSE')) {
        set('Web Server', 'Google Servlet Engine');
      }
      if (header('Server', server, 'AmazonS3')) set('Storage', 'Amazon S3');
    }

    if (xPoweredBy != null) {
      if (header('X-Powered-By', xPoweredBy, 'PHP')) set('Backend', 'PHP');
      if (header('X-Powered-By', xPoweredBy, 'ASP.NET')) {
        set('Backend', 'ASP.NET');
      }
      if (header('X-Powered-By', xPoweredBy, 'Express')) {
        set('Backend', 'Express');
      }
      if (header('X-Powered-By', xPoweredBy, 'Next.js')) {
        set('Framework', 'Next.js');
      }
    }

    if (via != null) {
      if (header('Via', via, 'varnish')) set('Cache', 'Varnish');
    }
  }

  // 2. HTML-based Detection (Generator Meta Tag)
  final generator = metadata['otherMeta']['generator']?.toLowerCase() ?? '';
  final generatorTag =
      RegExp(r'<meta[^>]*generator[^>]*>', caseSensitive: false)
          .firstMatch(html);
  final generatorEvidence = generatorTag == null
      ? <Map<String, dynamic>>[]
      : [DetectionEvidence.htmlAt(html, generatorTag.start).toMap()];
  pending = List.of(generatorEvidence);
  if (generator.contains('wordpress')) {
    set('CMS', 'WordPress');
    _extractVersion(generator, 'WordPress', tech);
  } else if (generator.contains('typo3')) {
    set('CMS', 'TYPO3');
  } else if (generator.contains('joomla')) {
    set('CMS', 'Joomla');
    _extractVersion(generator, 'Joomla', tech);
  } else if (generator.contains('drupal')) {
    set('CMS', 'Drupal');
    _extractVersion(generator, 'Drupal', tech);
  } else if (generator.contains('prestashop')) {
    set('CMS', 'PrestaShop');
  } else if (generator.contains('ghost')) {
    set('CMS', 'Ghost');
    _extractVersion(generator, 'Ghost', tech);
  } else if (generator.contains('hugo')) {
    set('Static Site', 'Hugo');
    _extractVersion(generator, 'Hugo', tech);
  } else if (generator.contains('webflow')) {
    set('CMS', 'Webflow');
  } else if (generator.contains('wix')) {
    set('CMS', 'Wix');
  } else if (generator.contains('shopify')) {
    set('CMS', 'Shopify');
  } else if (generator.contains('bitrix')) {
    set('CMS', '1C-Bitrix');
  } else if (generator.contains('docusaurus')) {
    set('Static Site', 'Docusaurus');
  } else if (generator.contains('gatsby')) {
    set('Static Site', 'Gatsby');
    _extractVersion(generator, 'Gatsby', tech);
  } else if (generator.contains('astro')) {
    set('Static Site', 'Astro');
    _extractVersion(generator, 'Astro', tech);
  } else if (generator.contains('jekyll')) {
    set('Static Site', 'Jekyll');
    _extractVersion(generator, 'Jekyll', tech);
  }

  pending = [];

  // 3. Path and Pattern-based CMS detection
  if (tech['CMS'] == null && tech['Static Site'] == null) {
    if (has('wp-content') || has('wp-includes')) {
      set('CMS', 'WordPress');
    } else if (has('typo3conf/') || has('typo3temp/') || has('/typo3/')) {
      set('CMS', 'TYPO3');
    } else if (has('/templates/') &&
        (has('/media/jui/') || has('/media/system/'))) {
      set('CMS', 'Joomla');
    } else if (has('/sites/all/modules/') || has('/sites/default/files/')) {
      set('CMS', 'Drupal');
    } else if (has('/modules/') && (has('prestashop') || has('/themes/'))) {
      if (has('var prestashop =') || has('id_product_attribute')) {
        set('CMS', 'PrestaShop');
      }
    } else if (has('cdn.shopify.com') || has('shopify-payment-button')) {
      set('CMS', 'Shopify');
    } else if (has('static1.squarespace.com')) {
      set('CMS', 'Squarespace');
    } else if (has('data-wf-page')) {
      set('CMS', 'Webflow');
    } else if (has('contentful.com')) {
      set('CMS', 'Contentful');
    } else if (has('umbraco')) {
      set('CMS', 'Umbraco');
    } else if (has('sitecore')) {
      set('CMS', 'Sitecore');
    } else if (has('adobe-experience-manager') || has('aem')) {
      set('CMS', 'Adobe Experience Manager');
    } else if (has('strapi')) {
      set('CMS', 'Strapi');
    }
  }

  // 4. Plugin & Extension Detection
  final List<String> plugins = [];
  final List<Map<String, dynamic>> pluginEvidence = [];
  void addPlugin(String name) {
    plugins.add(name);
    pluginEvidence.addAll(pending);
    pending = [];
  }

  if (tech['CMS'] == 'WordPress') {
    if (has('woocommerce') || has('/plugins/woocommerce/')) {
      addPlugin('WooCommerce');
    }
    if (has('elementor') || has('elementor-section')) {
      addPlugin('Elementor');
    }
    if (has('Yoast SEO') || has('/plugins/wordpress-seo/')) {
      addPlugin('Yoast SEO');
    }
    if (has('Rank Math') || has('rank-math-')) {
      addPlugin('Rank Math');
    }
    if (has('wpcf7') || has('contact-form-7')) {
      addPlugin('Contact Form 7');
    }
    if (has('wp-rocket') || has('WP Rocket')) {
      addPlugin('WP Rocket');
    }
    if (has('W3 Total Cache') || has('/w3-total-cache/')) {
      addPlugin('W3 Total Cache');
    }
    if (has('js-composer') || has('wpb-js-composer')) {
      addPlugin('WPBakery Page Builder');
    }
    if (has('revslider') || has('Slider Revolution')) {
      addPlugin('Slider Revolution');
    }
  } else if (tech['CMS'] == 'Joomla') {
    if (has('com_virtuemart')) addPlugin('VirtueMart');
    if (has('com_rsform')) addPlugin('RSForm');
    if (has('com_jce')) addPlugin('JCE Editor');
    if (has('com_k2')) addPlugin('K2');
  } else if (tech['CMS'] == 'Drupal') {
    if (has('views-view')) addPlugin('Views');
    if (has('webform-client-form')) addPlugin('Webform');
  }

  if (plugins.isNotEmpty) {
    tech['Plugins'] = plugins.join(', ');
    evidence['Plugins'] = pluginEvidence;
  }

  // 5. Frameworks & Libraries (Expanded)
  if (pattern(r'''_next/static|__NEXT_DATA__''')) {
    set('Framework', 'Next.js');
  } else if (pattern(r'''__NUXT__''')) {
    set('Framework', 'Nuxt.js');
  } else if (pattern(r'''_sveltekit''')) {
    set('Framework', 'SvelteKit');
  } else if (pattern(r'''window\.__remixContext|__remixManifest''')) {
    set('Framework', 'Remix');
  } else if (pattern(r'''data-reactroot|_reactListening''')) {
    set('Library', 'React');
  } else if (pattern(r'''data-v-|v-if=|v-for=''')) {
    set('Library', 'Vue.js');
  } else if (pattern(r'''ng-version|ng-app''')) {
    set('Framework', 'Angular');
  } else if (pattern(r'''jquery(?:\.min)?\.js''')) {
    set('Library', 'jQuery');
  } else if (has('x-data=') || has('x-init=')) {
    set('Library', 'Alpine.js');
  } else if (has('hx-get=') || has('hx-post=')) {
    set('Library', 'HTMX');
  } else if (has('solid-js')) {
    set('Library', 'SolidJS');
  } else if (has('lit-html') || has('lit-element')) {
    set('Library', 'Lit');
  }

  // 6. CSS Frameworks
  if (pattern(
      r'''bootstrap(?:\.min)?\.css|class=["'][^"']*?\b(?:col-|btn-|navbar-)''')) {
    set('CSS Framework', 'Bootstrap');
  }
  if (pattern(
      r'''tailwind(?:\.min)?\.css|class=["'][^"']*?\b(?:text-|bg-|p-|m-|flex-|grid-)''')) {
    if (has('tailwind') ||
        pattern(r'''\b(?:sm:|md:|lg:|xl:|2xl:)[a-z]''') ||
        pattern(r'''class=["'][^"']*\btext-[^"']*\bbg-[^"']*''')) {
      set('CSS Framework', 'Tailwind CSS');
    }
  }
  if (has('bulma') || has('is-primary')) {
    set('CSS Framework', 'Bulma');
  } else if (has('uk-')) {
    set('CSS Framework', 'UIkit');
  } else if (has('foundation.min.css')) {
    set('CSS Framework', 'Foundation');
  } else if (has('mdc-')) {
    set('CSS Framework', 'Material Components');
  } else if (has('chakra-ui')) {
    set('CSS Framework', 'Chakra UI');
  }

  for (final key in tech.keys) {
    if (key.endsWith(' Version')) evidence[key] ??= generatorEvidence;
  }

  metadata['detectedTech'] = tech;
  metadata['techEvidence'] = evidence;
}

void _extractVersion(
    String generatorString, String techName, Map<String, String> tech) {
  // Try to extract version number from generator string e.g. "WordPress 6.4.2"
  final regex = RegExp('$techName\\s+([0-9]+\\.[0-9]+(?:\\.[0-9]+)?)',
      caseSensitive: false);
  final match = regex.firstMatch(generatorString);
  if (match != null) {
    tech['$techName Version'] = match.group(1)!;
  }
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
    'Privacy & Consent Management': <String>[],
  };

  final patterns = {
    'Analytics & Trackers': {
      'Google Analytics':
          r'google-analytics\.com|googletagmanager\.com/gtag/js|\bgtag\(',
      'Google Tag Manager': r'googletagmanager\.com/gtm\.js',
      'HubSpot Analytics': r'js\.hs-scripts\.com|js\.hs-analytics\.net',
      'Facebook Pixel': r'fbevents\.js|connect\.facebook\.net|fbq\(',
      'Hotjar': r'static\.hotjar\.com|hj\(',
      'Mixpanel': r'cdn\.mxpnl\.com|mixpanel\.init',
      'Segment': r'cdn\.segment\.com|analytics\.load\(',
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

  final evidence = <String, List<Map<String, dynamic>>>{};
  final comments = _commentRanges(html);
  final lowerHtml = html.toLowerCase();
  patterns.forEach((category, items) {
    items.forEach((name, pattern) {
      final match = RegExp(pattern, caseSensitive: false)
          .allMatches(html)
          .where((m) =>
              _isActiveCode(lowerHtml, m.start, comments) &&
              !_isQuotedBareHost(html, m))
          .firstOrNull;
      if (match != null) {
        services.putIfAbsent(category, () => <String>[]).add(name);
        evidence[name] = [
          DetectionEvidence.htmlAt(html, match.start, match: match[0]).toMap()
        ];
      }
    });
  });

  services.removeWhere((key, value) => value.isEmpty);
  metadata['detectedServices'] = services;
  metadata['serviceEvidence'] = evidence;
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
