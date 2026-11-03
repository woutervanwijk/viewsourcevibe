import 'package:view_source_vibe/services/detection/engine.dart';
import 'package:view_source_vibe/services/probe_service.dart';

/// One loaded file/asset with the sizes reported by the browser.
class ResourceSize {
  final String url;
  final int transfer;
  final int decoded;

  /// One of: script, style, image, document, other.
  final String type;

  /// The HTML document of the inspected page itself.
  final bool isPage;

  /// Third-party services this file is loaded from.
  final List<Entity> services;

  const ResourceSize({
    required this.url,
    required this.transfer,
    required this.decoded,
    required this.type,
    this.isPage = false,
    this.services = const [],
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

  /// File name of the page document, `index` for root URLs.
  String get pageName {
    final uri = Uri.tryParse(url);
    final hasPath = uri?.pathSegments.any((s) => s.isNotEmpty) ?? false;
    return hasPath ? fileName : 'index';
  }

  String get host => Uri.tryParse(url)?.host ?? '';
}

/// URL without fragment and trailing slash, for comparing page URLs.
String _normalizeUrl(String url) {
  final noFragment = url.split('#').first;
  return noFragment.endsWith('/')
      ? noFragment.substring(0, noFragment.length - 1)
      : noFragment;
}

/// Converts browser resource-timing entries (`name`/`transfer`/`decoded`)
/// into a list sorted by size, largest first. Inline `data:` URIs are left
/// out (they're part of their parent file) and duplicate URLs are merged,
/// keeping the largest reported size.
List<ResourceSize> resourcesBySize(
    Iterable<Map<String, dynamic>> resources, String pageUrl) {
  final page = _normalizeUrl(pageUrl);
  final byUrl = <String, ResourceSize>{};
  for (final r in resources) {
    final url = r['name'] as String? ?? '';
    if (url.isEmpty || url.startsWith('data:')) continue;
    final isPage = page.isNotEmpty && _normalizeUrl(url) == page;
    final entry = ResourceSize(
      url: url,
      transfer: (r['transfer'] as num? ?? 0).toInt(),
      decoded: (r['decoded'] as num? ?? 0).toInt(),
      type: isPage ? 'document' : ProbeService.categorizeResource(url, pageUrl),
      isPage: isPage,
      services: externalServicesForUrl(url, pageUrl),
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
