import 'package:html_unescape/html_unescape.dart';
import 'package:xml/xml.dart';
import 'dart:io';

class RssTemplateService {
  static final _unescape = HtmlUnescape();

  /// Determines if the given file content represents a valid RSS/Atom/XML feed
  /// that should be rendered with the RSS template.
  ///
  /// Explicitly excludes SVGs to prevent false positives.
  static bool isRssFeed(String filename, String content) {
    final name = filename.toLowerCase();
    final trimmedContent = content.trimLeft();

    // Fast fail for empty content
    if (trimmedContent.isEmpty) return false;

    // Fast fail for SVGs (extension or content)
    if (name.endsWith('.svg') ||
        trimmedContent.startsWith('<svg') ||
        trimmedContent.contains('<svg xmlns')) {
      return false;
    }

    // Also fast fail for HTML files that might be misidentified as XML
    if (name.endsWith('.html') ||
        name.endsWith('.htm') ||
        trimmedContent.startsWith('<!DOCTYPE html') ||
        trimmedContent.startsWith('<html')) {
      return false;
    }

    // Check for standard extensions
    if (name.endsWith('.rss') || name.endsWith('.atom')) {
      return true;
    }

    // Robust check for feed signatures
    if (trimmedContent.contains('<rss') ||
        trimmedContent.contains('<feed') ||
        trimmedContent.contains('<rdf:RDF') ||
        trimmedContent.contains('http://purl.org/rss/1.0/')) {
      // For ambiguous cases, try to parse as XML to be sure
      try {
        final doc = XmlDocument.parse(trimmedContent);
        return doc.findElements('rss').isNotEmpty ||
            doc.findAllElements('channel').isNotEmpty ||
            doc.findElements('feed').isNotEmpty ||
            doc.findElements('rdf:RDF').isNotEmpty;
      } catch (e) {
        // If it looks like a feed but doesn't parse as XML, it might be malformed but we still try
        return true;
      }
    }

    return false;
  }

  static String convertRssToHtml(String xmlContent, String feedUrl) {
    try {
      final document = XmlDocument.parse(xmlContent.trim());

      // Detect feed type
      final rssElement = document.findElements('rss').firstOrNull;
      final feedElement = document.findElements('feed').firstOrNull; // Atom
      final rdfElement =
          document.findElements('rdf:RDF').firstOrNull; // RSS 1.0

      if (rssElement != null || rdfElement != null) {
        return _renderRss(document, feedUrl);
      } else if (feedElement != null) {
        return _renderAtom(document, feedUrl);
      } else {
        // Try regex fallback even if XML parse succeeded but structure wasn't found
        // (Unlikely, but possible for some weird XML)
        return _parseWithRegex(xmlContent, feedUrl);
      }
    } catch (e) {
      // XML Parse failed, use Regex Fallback
      return _parseWithRegex(xmlContent, feedUrl);
    }
  }

  // ... (Existing XML Rendering Methods: _renderRss, _renderAtom, _parseItem, _parseEntry) ...
  // I will need to keep these, but since I'm rewriting the file to add fallback, I'll essentially paste the old code back with the new method.
  // Actually, I should use `replace_file_content` to append the new method and update `convertRssToHtml`.

  static String _renderRss(XmlDocument doc, String feedUrl) {
    final channel = doc.findAllElements('channel').firstOrNull ??
        doc.findAllElements('rss').firstOrNull;
    if (channel == null) {
      return _renderError("Invalid RSS Feed: No channel found");
    }

    final title = _getText(channel, 'title') ?? 'Untitled Feed';
    final description = _getText(channel, 'description') ?? '';
    final link = _getText(channel, 'link') ?? feedUrl;
    final image = channel
        .findElements('image')
        .firstOrNull
        ?.findElements('url')
        .firstOrNull
        ?.innerText;

    final items = doc.findAllElements('item').map((node) {
      return _parseItem(node);
    }).toList();

    return _generateHtml(title, description, link, image, items, 'RSS');
  }

  static String _renderAtom(XmlDocument doc, String feedUrl) {
    final feed = doc.findElements('feed').firstOrNull;
    if (feed == null) return _renderError("Invalid Atom Feed");

    final title = _getText(feed, 'title') ?? 'Untitled Feed';
    final subtitle = _getText(feed, 'subtitle');

    // Atom links
    XmlElement? linkNode;
    try {
      linkNode = feed.findElements('link').firstWhere(
            (e) =>
                e.getAttribute('rel') == 'alternate' ||
                e.getAttribute('rel') == null,
          );
    } catch (e) {
      linkNode = feed.findElements('link').firstOrNull;
    }

    final link = linkNode?.getAttribute('href') ?? feedUrl;
    final logo = _getText(feed, 'logo') ?? _getText(feed, 'icon');

    final entries = doc.findAllElements('entry').map((node) {
      return _parseEntry(node);
    }).toList();

    return _generateHtml(title, subtitle ?? '', link, logo, entries, 'Atom');
  }

  static Map<String, String> _parseItem(XmlElement node) {
    String? title = _getText(node, 'title');
    String? link = _getText(node, 'link');
    String? description = _getText(node, 'description');
    String? content =
        _getText(node, 'content:encoded') ?? _getText(node, 'content');
    String? pubDate = _getText(node, 'pubDate') ?? _getText(node, 'dc:date');
    String? author = _getText(node, 'author') ?? _getText(node, 'dc:creator');

    // Try to extract an image from enclosure or description/content
    String? image;
    final enclosure = node.findElements('enclosure').firstOrNull;
    if (enclosure != null &&
        (enclosure.getAttribute('type')?.startsWith('image') ?? false)) {
      image = enclosure.getAttribute('url');
    }

    // If no enclosure, try media:content
    if (image == null) {
      final media = node.findElements('media:content').firstOrNull ??
          node
              .findElements('media:group')
              .firstOrNull
              ?.findElements('media:content')
              .firstOrNull;
      if (media != null &&
          (media.getAttribute('medium') == 'image' ||
              (media.getAttribute('type')?.startsWith('image') ?? false))) {
        image = media.getAttribute('url');
      }
    }

    // Fallback: extract from HTML content
    if (image == null && (content != null || description != null)) {
      final html = content ?? description!;
      final imgMatch = RegExp(r'<img[^>]+src="([^">]+)"').firstMatch(html);
      if (imgMatch != null) {
        image = imgMatch.group(1);
      }
    }

    return {
      'title': title ?? 'Untitled',
      'link': link ?? '#',
      'description': description ?? '',
      'content': content ?? description ?? '',
      'date': _formatDate(pubDate),
      'author': author ?? '',
      'image': image ?? '',
    };
  }

  static Map<String, String> _parseEntry(XmlElement node) {
    String? title = _getText(node, 'title');

    XmlElement? linkNode;
    try {
      linkNode = node.findElements('link').firstWhere(
            (e) =>
                e.getAttribute('rel') == 'alternate' ||
                e.getAttribute('rel') == null,
          );
    } catch (e) {
      // No match found
    }

    String? link = linkNode?.getAttribute('href');

    String? summary = _getText(node, 'summary');
    String? content = _getText(node, 'content');
    String? updated = _getText(node, 'updated') ?? _getText(node, 'published');
    String? author = node
        .findElements('author')
        .firstOrNull
        ?.findElements('name')
        .firstOrNull
        ?.innerText;

    // Image extraction logic similar to RSS...
    String? image;
    // ... (Atom logic implies looking for links with rel=enclosure/image type)

    if ((content != null || summary != null)) {
      final html = content ?? summary!;
      final imgMatch = RegExp(r'<img[^>]+src="([^">]+)"').firstMatch(html);
      if (imgMatch != null) {
        image = imgMatch.group(1);
      }
    }

    return {
      'title': title ?? 'Untitled',
      'link': link ?? '#',
      'description': summary ?? '',
      'content': content ?? summary ?? '',
      'date': _formatDate(updated),
      'author': author ?? '',
      'image': image ?? '',
    };
  }

  static String? _getText(XmlElement parent, String tagName) {
    final element = parent.findElements(tagName).firstOrNull;
    return element?.innerText.trim();
  }

  static String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      DateTime date;
      // Handle RFC 822 (RSS)
      if (dateStr.contains(',')) {
        date = HttpDate.parse(dateStr); // works for RFC 1123/822 mostly
      } else {
        date = DateTime.parse(dateStr); // works for ISO 8601
      }
      // Simple formatting without intl
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }

  // --------------------------------------------------------------------------
  // REGEX FALLBACK PARSER
  // --------------------------------------------------------------------------
  static String _parseWithRegex(String content, String feedUrl) {
    // 1. Basic Metadata
    final titleMatch =
        RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true).firstMatch(content);

    // Link: Find all link tags, pick the best one
    String link = feedUrl;
    final linkMatches =
        RegExp(r'<link([^>]+)>', dotAll: true).allMatches(content);
    for (final m in linkMatches) {
      final attrs = m.group(1) ?? '';
      final href = _extractAttribute(attrs, 'href');
      final rel = _extractAttribute(attrs, 'rel');
      // Prefer alternate or no rel (RSS content)
      if (href != null && (rel == null || rel == 'alternate')) {
        link = href;
        break;
      }
      // Fallback for RSS <link>url</link>
      if (href == null && !attrs.contains('=')) {
        // Maybe it's <link>url</link> style which the RegExp didn't fully capture in group 1 if > was limit?
        // Actually my regex <link([^>]+)> captures attributes.
        // RSS <link>url</link> is different.
      }
    }
    // RSS Link fallback
    if (link == feedUrl) {
      final rssLinkMatch =
          RegExp(r'<link>(.*?)</link>', dotAll: true).firstMatch(content);
      if (rssLinkMatch != null) link = rssLinkMatch.group(1)!.trim();
    }

    // feed description or subtitle
    final descMatch =
        RegExp(r'<(description|subtitle)[^>]*>(.*?)</\1>', dotAll: true)
            .firstMatch(content);

    final title = titleMatch?.group(1) != null
        ? _cleanXmlText(titleMatch!.group(1)!)
        : 'Untitled Feed';
    final description =
        descMatch?.group(2) != null ? _cleanXmlText(descMatch!.group(2)!) : '';

    // Logo/Icon
    final imageMatch = RegExp(r'<(logo|icon|url)[^>]*>(.*?)</\1>', dotAll: true)
        .firstMatch(content);
    final image = imageMatch?.group(2)?.trim();

    // 2. Identify Item Blocks (item or entry)
    final items = <Map<String, String>>[];

    // Match <entry>...</entry> OR <item>...</item>
    final itemRegex = RegExp(r'<(item|entry)[^>]*>(.*?)</\1>', dotAll: true);
    final matches = itemRegex.allMatches(content);

    for (final match in matches) {
      final itemContent = match.group(2) ?? '';
      items.add(_parseItemRegex(itemContent));
    }

    // Use lowercase check for type
    final type = content.toLowerCase().contains('<feed') ||
            content.contains('http://www.w3.org/2005/Atom')
        ? 'Atom (Fallback)'
        : 'RSS (Fallback)';

    return _generateHtml(title, description, link, image, items, type);
  }

  static Map<String, String> _parseItemRegex(String content) {
    final title = _extractRegex(content, r'<title[^>]*>(.*?)</title>');

    // Link: Robust attribute parsing
    String? link;
    final linkMatches =
        RegExp(r'<link([^>]+)>', dotAll: true).allMatches(content);
    for (final m in linkMatches) {
      final attrs = m.group(1) ?? '';
      final href = _extractAttribute(attrs, 'href');
      final rel = _extractAttribute(attrs, 'rel');
      if (href != null && (rel == null || rel == 'alternate')) {
        link = href;
        break;
      }
    }
    // RSS style link
    link ??= _extractRegex(content, r'<link>(.*?)</link>');

    final description =
        _extractRegex(content, r'<description[^>]*>(.*?)</description>') ??
            _extractRegex(content, r'<summary[^>]*>(.*?)</summary>');

    final contentText = _extractRegex(
            content, r'<content:encoded[^>]*>(.*?)</content:encoded>') ??
        _extractRegex(content, r'<content[^>]*>(.*?)</content>');

    final rawDate =
        _extractRegex(content, r'<(pubDate|published|updated)>(.*?)</\1>');
    final author = _extractRegex(content,
        r'<(author|dc:creator)>(.*?)</\1>'); // naive, author might be nested

    // Image extraction
    String? image;
    // Enclosure
    final enclosureMatch = RegExp(
                r'<enclosure[^>]+url="([^"]+)"[^>]*type="image',
                caseSensitive: false)
            .firstMatch(content) ??
        RegExp(r'<enclosure[^>]+type="image[^"]+"[^>]*url="([^"]+)"',
                caseSensitive: false)
            .firstMatch(content);

    if (enclosureMatch != null) image = enclosureMatch.group(1);

    // Media thumbnail/content
    if (image == null) {
      final mediaMatch = RegExp(r'<media:(content|thumbnail)[^>]+url="([^"]+)"')
          .firstMatch(content);
      if (mediaMatch != null) image = mediaMatch.group(2);
    }

    // HTML image fallback
    if (image == null) {
      final fullText = (contentText ?? '') + (description ?? '');
      final imgMatch = RegExp(r'<img[^>]+src="([^">]+)"').firstMatch(fullText);
      if (imgMatch != null) image = imgMatch.group(1);
    }

    return {
      'title': title != null ? _cleanXmlText(title) : 'Untitled',
      'link': link ?? '#',
      'description': description != null ? _cleanXmlText(description) : '',
      'content': contentText ?? description ?? '',
      'date': _formatDate(rawDate),
      'author': author != null ? _cleanXmlText(author) : '',
      'image': image ?? '',
    };
  }

  static String? _extractRegex(String source, String pattern) {
    final match = RegExp(pattern, dotAll: true).firstMatch(source);
    return match?.group(1);
  }

  static String? _extractAttribute(String source, String attrName) {
    final match = RegExp('$attrName="([^"]+)"').firstMatch(source) ??
        RegExp("$attrName='([^']+)'").firstMatch(source);
    return match?.group(1);
  }

  static String _cleanXmlText(String text) {
    // Remove CDATA
    var cleaned = text.replaceAll('<![CDATA[', '').replaceAll(']]>', '');
    return cleaned.trim();
    // Note: We don't unescape HTML entities here because the HTML renderer will handle standard entities,
    // and _stripHtml handles the rest.
  }

  static String _generateHtml(String title, String description, String link,
      String? image, List<Map<String, String>> items, String type) {
    final buffer = StringBuffer();

    buffer.writeln('''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        :root {
            --primary: #2563eb;
            --bg: #f8fafc;
            --card-bg: #ffffff;
            --text-main: #1e293b;
            --text-muted: #64748b;
            --border: #e2e8f0;
        }
        
        @media (prefers-color-scheme: dark) {
            :root {
                --primary: #60a5fa;
                --bg: #0f172a;
                --card-bg: #1e293b;
                --text-main: #f1f5f9;
                --text-muted: #94a3b8;
                --border: #334155;
            }
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--bg);
            color: var(--text-main);
            margin: 0;
            padding: 20px;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
        }

        a { color: var(--primary); text-decoration: none; }
        a:hover { text-decoration: underline; }

        .header {
            text-align: center;
            margin-bottom: 40px;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border);
        }

        .feed-logo {
            width: 64px;
            height: 64px;
            border-radius: 12px;
            margin-bottom: 16px;
            object-fit: cover;
            background-color: var(--card-bg);
            border: 1px solid var(--border);
        }

        h1 { margin: 0 0 10px 0; font-size: 24px; }
        .feed-desc { color: var(--text-muted); font-size: 16px; margin: 0; }
        .feed-meta { font-size: 12px; color: var(--text-muted); margin-top: 8px; text-transform: uppercase; letter-spacing: 1px; }

        .item-card {
            background: var(--card-bg);
            border-radius: 16px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.05);
            border: 1px solid var(--border);
            transition: transform 0.2s ease;
        }
        
        .item-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }

        .item-title {
            margin: 0 0 8px 0;
            font-size: 20px;
            line-height: 1.3;
        }

        .item-meta {
            font-size: 13px;
            color: var(--text-muted);
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .item-image {
            width: 100%;
            height: 200px;
            object-fit: cover;
            border-radius: 8px;
            margin-bottom: 16px;
            background-color: var(--bg);
        }

        .item-desc {
            font-size: 15px;
            color: var(--text-main);
            overflow-wrap: break-word;
        }
        
        /* Clean up embedded content in descriptions */
        .item-desc img { max-width: 100%; height: auto; border-radius: 4px; display: none; /* Hide embedded images in description if we show a hero image, or just show them? Let's hide to be clean if we extracted one */ }
        .item-desc iframe { max-width: 100%; }

        .read-more {
            display: inline-block;
            margin-top: 16px;
            font-weight: 600;
            font-size: 14px;
        }
        
        .parsing-note {
            text-align: center;
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 40px;
            opacity: 0.6;
        }
    </style>
</head>
<body>
    <div class="header">
        ${image != null ? '<img src="$image" class="feed-logo" onError="this.style.display=\'none\'" />' : ''}
        <h1><a href="$link">$title</a></h1>
        <p class="feed-desc">$description</p>
        <div class="feed-meta">$type Feed</div>
    </div>
    
    <div class="items">
    ''');

    for (var item in items) {
      final hasImage = item['image']?.isNotEmpty ?? false;

      buffer.write('''
        <article class="item-card">
            ${hasImage ? '<img src="${item['image']}" class="item-image" loading="lazy" />' : ''}
            <h2 class="item-title"><a href="${item['link']}">${item['title']}</a></h2>
            <div class="item-meta">
                ${item['date']!.isNotEmpty ? '<span>📅 ${item['date']}</span>' : ''}
                ${item['author']!.isNotEmpty ? '<span>✍️ ${item['author']}</span>' : ''}
            </div>
            <div class="item-desc">
                ${_stripHtml(item['description']!, limit: 300)}...
            </div>
            <a href="${item['link']}" class="read-more">Read Article →</a>
        </article>
        ''');
    }

    buffer.writeln('''
    </div>
    ${type.contains('Fallback') ? '<div class="parsing-note">Rendered using Robust Mode (Regex) due to XML parsing issues.</div>' : ''}
</body>
</html>
    ''');

    return buffer.toString();
  }

  static String _stripHtml(String html, {int limit = 200}) {
    // 1. Unescape first (e.g. &lt;h4&gt; -> <h4>)
    var text = _unescape.convert(html);

    // 2. Strip tags
    text =
        text.replaceAll(RegExp(r'<[^>]*>', multiLine: true, dotAll: true), '');

    // 3. Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.length > limit) {
      return text.substring(0, limit);
    }
    return text;
  }

  static String _renderError(String message) {
    return '''
     <html>
     <body style="font-family: system-ui; padding: 20px; color: #ef4444; background: #fff1f2;">
        <h2>RSS Rendering Error</h2>
        <p>$message</p>
     </body>
     </html>
     ''';
  }
}
