import 'package:view_source_vibe/services/probe_service.dart';

/// One loaded file/asset with the sizes reported by the browser.
class ResourceSize {
  final String url;
  final int transfer;
  final int decoded;

  /// One of: script, style, image, document, other.
  final String type;

  const ResourceSize({
    required this.url,
    required this.transfer,
    required this.decoded,
    required this.type,
  });

  /// Uncompressed size, falling back to transfer size when unknown.
  int get size => decoded > 0 ? decoded : transfer;

  /// Last path segment, or the host for root URLs.
  String get fileName {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    if (segments.isNotEmpty) return Uri.decodeComponent(segments.last);
    return uri.host.isNotEmpty ? uri.host : url;
  }

  String get host => Uri.tryParse(url)?.host ?? '';
}

/// Converts browser resource-timing entries (`name`/`transfer`/`decoded`)
/// into a list sorted by size, largest first. Inline `data:` URIs are left
/// out (they're part of their parent file) and duplicate URLs are merged,
/// keeping the largest reported size.
List<ResourceSize> resourcesBySize(
    Iterable<Map<String, dynamic>> resources, String pageUrl) {
  final byUrl = <String, ResourceSize>{};
  for (final r in resources) {
    final url = r['name'] as String? ?? '';
    if (url.isEmpty || url.startsWith('data:')) continue;
    final entry = ResourceSize(
      url: url,
      transfer: (r['transfer'] as num? ?? 0).toInt(),
      decoded: (r['decoded'] as num? ?? 0).toInt(),
      type: ProbeService.categorizeResource(url, pageUrl),
    );
    final existing = byUrl[url];
    if (existing == null || entry.size > existing.size) byUrl[url] = entry;
  }
  return byUrl.values.toList()
    ..sort((a, b) {
      final bySize = b.size.compareTo(a.size);
      return bySize != 0 ? bySize : a.url.compareTo(b.url);
    });
}
