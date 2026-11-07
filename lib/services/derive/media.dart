import 'dart:convert';
import 'dart:typed_data';

import '../../models/inspection/observed.dart';
import 'metadata_view.dart';
import 'page_size.dart';

/// Sanitizes SVG data by converting percentage coordinates to absolute values
/// based on the viewBox. This fixes 'Invalid double: 50%' errors.
Uint8List sanitizeSvgData(Uint8List bytes) {
  try {
    String content = utf8.decode(bytes, allowMalformed: true).trim();
    if (content.isEmpty) return bytes;

    // Check if dimensions are present
    final hasDim = content.contains(
        RegExp('\\b(width|height|viewBox)\\s*=', caseSensitive: false));

    if (!hasDim) {
      // Add a fallback viewBox if missing to prevent 'Bad state' error
      content = content.replaceFirst(
          RegExp('<svg\\b', caseSensitive: false), '<svg viewBox="0 0 24 24"');
    }

    // Find viewBox="x y w h" - allow commas as well as spaces
    final vbRegex = RegExp(
        'viewBox\\s*=\\s*["\']\\s*(-?\\d+\\.?\\d*)[,\\s]+(-?\\d+\\.?\\d*)[,\\s]+(-?\\d+\\.?\\d*)[,\\s]+(-?\\d+\\.?\\d*)\\s*["\']',
        caseSensitive: false);
    final viewBoxMatch = vbRegex.firstMatch(content);

    if (viewBoxMatch != null) {
      final double vbWidth = double.tryParse(viewBoxMatch.group(3)!) ?? 100.0;
      final double vbHeight = double.tryParse(viewBoxMatch.group(4)!) ?? 100.0;

      // Replace 50% / 100% in cx, cy, x, y, width, height, r, rx, ry
      final attrRegex = RegExp(
          '\\b(cx|cy|x|y|width|height|r|rx|ry)\\s*=\\s*["\']\\s*(\\d+\\.?\\d*)\\s*%\\s*["\']',
          caseSensitive: false);
      content = content.replaceAllMapped(attrRegex, (match) {
        final attr = match.group(1);
        final percentString = match.group(2);
        final percent = double.tryParse(percentString!) ?? 0.0;
        final base = (attr == 'cx' ||
                attr == 'x' ||
                attr == 'width' ||
                attr == 'r' ||
                attr == 'rx')
            ? vbWidth
            : vbHeight;
        final absolute = (percent / 100.0) * base;
        return '$attr="$absolute"';
      });
    }

    return utf8.encode(content);
  } catch (e) {
    // Unparseable: render the bytes as they are.
    return bytes;
  }
}

/// Normalize a URL for comparison by:
/// - Removing fragments (#...)
/// - Removing trailing slashes
/// - Removing default ports (80 for http, 443 for https)
/// - Removing common cache-busting query parameters
/// - Converting to lowercase for case-insensitive comparison
String normalizeMediaUrl(String url) {
  try {
    final uri = Uri.parse(url);

    // Remove fragment
    final withoutFragment = uri.removeFragment();

    // Remove cache-busting parameters
    final cleanParams =
        Map<String, String>.from(withoutFragment.queryParameters);
    const cacheBusters = {
      'v',
      'ver',
      'version',
      't',
      'ts',
      'timestamp',
      'hash',
      '_',
      'cache',
      'cachebuster',
      'cb',
      'nocache',
      'rev',
      'revision',
    };
    cleanParams
        .removeWhere((key, _) => cacheBusters.contains(key.toLowerCase()));

    // Rebuild the URI with the cleaned params. Removing every param must
    // drop the query: replace(queryParameters: null) would keep the old one.
    var normalized = Uri(
      scheme: withoutFragment.hasScheme ? withoutFragment.scheme : null,
      userInfo:
          withoutFragment.userInfo.isEmpty ? null : withoutFragment.userInfo,
      host: withoutFragment.hasAuthority ? withoutFragment.host : null,
      port: withoutFragment.hasPort ? withoutFragment.port : null,
      path: withoutFragment.path,
      queryParameters: cleanParams.isEmpty ? null : cleanParams,
    );

    // Remove default ports
    if ((normalized.scheme == 'http' && normalized.port == 80) ||
        (normalized.scheme == 'https' && normalized.port == 443)) {
      normalized = normalized.replace(port: null);
    }

    // Convert to string and remove trailing slash
    var result = normalized.toString();
    if (result.endsWith('/') && result.length > 1) {
      // Don't remove slash if it's just the root path
      final pathStart = result.indexOf('/', result.indexOf('://') + 3);
      if (pathStart != result.length - 1) {
        result = result.substring(0, result.length - 1);
      }
    }

    return result.toLowerCase();
  } catch (e) {
    // If URL parsing fails, return the original URL lowercased
    return url.toLowerCase();
  }
}

/// Deduplicate media items based on normalized URLs
/// This catches duplicates that may have slipped through initial parsing
/// or have slight variations (e.g., different query parameters, fragments, etc.)
List<dynamic> deduplicateMedia(List<dynamic> items) {
  final seen = <String>{};
  final deduplicated = <dynamic>[];

  for (final item in items) {
    final src = item['src']?.toString() ?? '';
    if (src.isEmpty) continue;

    // For data URIs, use the full string as the key
    final key = src.startsWith('data:') ? src : normalizeMediaUrl(src);

    if (!seen.contains(key)) {
      seen.add(key);
      deduplicated.add(item);
    }
  }

  return deduplicated;
}

/// One image, video or font of the page.
class MediaItem {
  final String src;
  final String alt;
  final bool inline;

  /// Video provider (YouTube, ...), when known.
  final String? provider;

  /// "5 KB" (the transfer size for an image), "≈ 5 KB" for our own estimate,
  /// or "size unknown (reason)". Never "0 KB".
  final String sizeLabel;

  /// The size the list is sorted by; null = unknown (sorted last).
  final int? sizeBytes;

  /// Why the item cannot be opened or loaded (relative link in a local
  /// file); null for a link that resolves.
  final String? unresolvedNote;

  const MediaItem({
    required this.src,
    required this.alt,
    required this.inline,
    required this.provider,
    required this.sizeLabel,
    required this.sizeBytes,
    required this.unresolvedNote,
  });
}

/// The Media tab's data, from the extracted metadata.
class MediaModel {
  final DataSource docSource;
  final List<MediaItem> images;
  final List<MediaItem> inlineImages;
  final List<MediaItem> videos;
  final List<MediaItem> fonts;

  const MediaModel({
    required this.docSource,
    required this.images,
    required this.inlineImages,
    required this.videos,
    required this.fonts,
  });

  bool get isEmpty =>
      images.isEmpty && inlineImages.isEmpty && videos.isEmpty && fonts.isEmpty;
}

/// An image's size is what was transferred (WebKit's decoded size is a pixel
/// buffer); our own estimate is marked "≈".
String imageSizeLabel(Object? size, {required String unknownReason}) {
  if (size is Map) {
    final tx = size['transfer'] as int?;
    if (tx != null) {
      final text = formatSizePair(decoded: tx, transfer: tx)!;
      return size['estimated'] == true ? '≈ $text' : text;
    }
    final own = size['unknownReason'];
    if (own is String && own.isNotEmpty) return 'size unknown ($own)';
  }
  return 'size unknown ($unknownReason)';
}

int? _bytes(Object? size, String key) => size is Map ? size[key] as int? : null;

/// Images, videos and fonts of [m], deduplicated and sorted (inline images
/// last, largest first, unknown sizes after known ones, then by URL).
MediaModel deriveMedia(MetadataModel m) {
  final media = m.data['media'];
  List<dynamic> list(String key) =>
      media is Map && media[key] is List ? media[key] as List : const [];

  MediaItem item(dynamic raw, {required bool image}) {
    final map = raw as Map;
    final src = '${map['src'] ?? ''}';
    final size = map['size'];
    return MediaItem(
      src: src,
      alt: '${map['alt'] ?? ''}',
      inline: map['type'] == 'base64' || src.startsWith('data:'),
      provider: map['provider'] as String?,
      sizeLabel: image
          ? imageSizeLabel(size, unknownReason: m.sizeUnknownReason)
          : linkSizeLabel(size, unknownReason: m.sizeUnknownReason),
      sizeBytes: image ? _bytes(size, 'transfer') : _bytes(size, 'decoded'),
      unresolvedNote: src.startsWith('data:') ? null : m.unresolvedNote(src),
    );
  }

  int bySize(MediaItem a, MediaItem b) {
    final sa = a.sizeBytes ?? -1, sb = b.sizeBytes ?? -1;
    if (sa != sb) return sb.compareTo(sa);
    return a.src.toLowerCase().compareTo(b.src.toLowerCase());
  }

  final all = [
    for (final i in deduplicateMedia(list('images'))) item(i, image: true)
  ]..sort(bySize);
  final videos = [
    for (final v in deduplicateMedia(list('videos'))) item(v, image: false)
  ]..sort(bySize);
  final fonts = [
    for (final f in deduplicateMedia(list('fonts'))) item(f, image: false)
  ];
  return MediaModel(
    docSource: m.docSource,
    images: [
      for (final i in all)
        if (!i.inline) i
    ],
    inlineImages: [
      for (final i in all)
        if (i.inline) i
    ],
    videos: videos,
    fonts: fonts,
  );
}
