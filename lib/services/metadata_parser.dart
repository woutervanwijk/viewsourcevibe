import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart' as xml;
import 'package:view_source_vibe/services/detection/engine.dart';

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

  // Services, trackers and technologies in the source and headers. The
  // browser's requests and cookies are added later (HtmlService.detections).
  metadata['detections'] = [
    for (final d in scanSource(html: html, headers: headers, pageUrl: baseUrl))
      d.toMap()
  ];

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
