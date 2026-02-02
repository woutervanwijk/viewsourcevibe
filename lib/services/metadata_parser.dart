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
    'otherMeta': <String, String>{},
    'icons': <String, String>{},
    'detectedTech': <String, String>{},
  };

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
        metadata['cssLinks'].add(absoluteHref);
      } else if (rel == 'alternate' &&
          (type?.contains('rss') == true || type?.contains('atom') == true)) {
        metadata['rssLinks'].add(absoluteHref);
      } else if (rel != null && rel.contains('icon')) {
        metadata['icons'][rel] = absoluteHref;
      }
    }
  }

  // Extract Script Tags
  final scriptTags =
      RegExp(r'''<script\s+[^>]*src=["'](.*?)["']''', caseSensitive: false)
          .allMatches(html);
  for (final match in scriptTags) {
    final attrStr = match.group(1) ?? '';
    final attrs = _parseAttributes(attrStr);
    final src = attrs['src'];
    if (src != null) {
      metadata['jsLinks'].add(_resolveUrl(src, baseUrl));
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
