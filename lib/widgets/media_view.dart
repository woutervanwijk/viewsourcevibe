import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:view_source_vibe/widgets/media_browser.dart';
import 'package:view_source_vibe/widgets/safe_network_svg.dart';
import '../utils/format_utils.dart';
import '../utils/font_url.dart';

class MediaView extends StatelessWidget {
  const MediaView({super.key});

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);
    final metadata = htmlService.pageMetadata;

    // Show loading indicator only if we're still loading or extracting metadata
    if (htmlService.isLoading ||
        htmlService.isWebViewLoading ||
        htmlService.isExtractingMetadata) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show message if no media detected or metadata is not available
    if (metadata == null || metadata['media'] == null) {
      // For XML files, we should never show progress - they don't have media
      if (htmlService.isXml) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.perm_media_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 16),
              const Text('No Media Detected'),
              const SizedBox(height: 8),
              const Text('Media is not available for XML content.',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.perm_media_outlined,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            const Text('No Media Detected'),
            const SizedBox(height: 8),
            const Text('Load an HTML page to view detected media.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Deduplicate images based on normalized URLs
    final List<dynamic> images = _deduplicateMedia(
      List.from(metadata['media']['images'] ?? []),
    )..sort((a, b) {
        final mapA = a as Map;
        final mapB = b as Map;

        // Highest Priority: Move inline SVGs (base64) to the bottom
        final isInlineA = mapA['type'] == 'base64' ||
            (mapA['src'] as String? ?? '').startsWith('data:');
        final isInlineB = mapB['type'] == 'base64' ||
            (mapB['src'] as String? ?? '').startsWith('data:');
        if (isInlineA != isInlineB) {
          return isInlineA ? 1 : -1;
        }

        final sizeA = mapA['size']?['decoded'] ?? 0;
        final sizeB = mapB['size']?['decoded'] ?? 0;

        // Secondary: Sort by file size descending
        if (sizeB != sizeA) {
          return (sizeB as num).compareTo(sizeA as num);
        }

        return (mapA['src'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((mapB['src'] ?? '').toString().toLowerCase());
      });

    bool isInline(dynamic i) =>
        i['type'] == 'base64' ||
        (i['src'] as String? ?? '').startsWith('data:');
    final inlineImages = images.where(isInline).toList();
    images.removeWhere(isInline);

    // Deduplicate videos and sort by size desc, then alphabet
    final List<dynamic> videos = _deduplicateMedia(
      List.from(metadata['media']['videos'] ?? []),
    )..sort((a, b) {
        final mapA = a as Map;
        final mapB = b as Map;

        final sizeA = mapA['size']?['decoded'] ?? 0;
        final sizeB = mapB['size']?['decoded'] ?? 0;

        // Sort by file size descending
        if (sizeB != sizeA) {
          return (sizeB as num).compareTo(sizeA as num);
        }

        return (mapA['src'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((mapB['src'] ?? '').toString().toLowerCase());
      });

    final List<dynamic> fonts = _deduplicateMedia(
      List.from(metadata['media']['fonts'] ?? []),
    );

    if (images.isEmpty &&
        inlineImages.isEmpty &&
        videos.isEmpty &&
        fonts.isEmpty) {
      // Since we already checked for loading states at the beginning,
      // we can directly show the empty state message
      return ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.perm_media_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: 16),
              const Text('No Images, Videos or Fonts found'),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
        child: SingleChildScrollView(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (videos.isNotEmpty) ...[
              _buildSectionTitle(context, 'Videos (${videos.length})'),
              const SizedBox(height: 8),
              ...videos.map((video) => _buildVideoItem(context, video)),
              const SizedBox(height: 24),
            ],
            if (fonts.isNotEmpty) ...[
              _buildSectionTitle(context, 'Fonts (${fonts.length})'),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, constraints) {
                const gap = 8.0;
                final cols = (constraints.maxWidth / 360).floor().clamp(1, 4);
                final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  children: [
                    for (final font in fonts)
                      SizedBox(width: w, child: _FontItem(font: font)),
                  ],
                );
              }),
              const SizedBox(height: 24),
            ],
            if (images.isNotEmpty) ...[
              _buildSectionTitle(context, 'Images (${images.length})'),
              const SizedBox(height: 8),
              _buildImageGrid(context, images),
              const SizedBox(height: 24),
            ],
            if (inlineImages.isNotEmpty) ...[
              _buildSectionTitle(
                  context, 'Inline images (${inlineImages.length})'),
              const SizedBox(height: 8),
              _buildImageGrid(context, inlineImages),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    ));
  }

  /// Deduplicate media items based on normalized URLs
  /// This catches duplicates that may have slipped through initial parsing
  /// or have slight variations (e.g., different query parameters, fragments, etc.)
  List<dynamic> _deduplicateMedia(List<dynamic> items) {
    final seen = <String>{};
    final deduplicated = <dynamic>[];

    for (final item in items) {
      final src = item['src']?.toString() ?? '';
      if (src.isEmpty) continue;

      // For data URIs, use the full string as the key
      final key = src.startsWith('data:') ? src : _normalizeUrl(src);

      if (!seen.contains(key)) {
        seen.add(key);
        deduplicated.add(item);
      }
    }

    return deduplicated;
  }

  /// Normalize a URL for comparison by:
  /// - Removing fragments (#...)
  /// - Removing trailing slashes
  /// - Removing default ports (80 for http, 443 for https)
  /// - Removing common cache-busting query parameters
  /// - Converting to lowercase for case-insensitive comparison
  String _normalizeUrl(String url) {
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

      // Rebuild URI without fragment and with cleaned params
      var normalized = withoutFragment.replace(
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

  Widget _buildImageGrid(BuildContext context, List<dynamic> items) {
    return GridView.builder(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200, // Responsive: more columns on wider screens
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildImageItem(context, items[index]),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildVideoItem(BuildContext context, Map<String, dynamic> video) {
    final src = video['src'] ?? 'Unknown Source';
    final provider = video['provider'];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          provider != null ? Icons.play_circle_fill : Icons.videocam,
          color: provider != null ? Colors.red : Colors.blue,
        ),
        title: Text(
          provider != null ? '$provider Video' : 'Direct Video',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          src,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
        trailing: const Icon(Icons.open_in_new, size: 16),
        onTap: () {
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          htmlService.loadFromUrl(src, switchToTab: HtmlService.viewerTab);
        },
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: src));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL copied to clipboard')),
          );
        },
      ),
    );
  }

  Widget _buildImageItem(BuildContext context, Map<String, dynamic> image) {
    final src = image['src'] ?? '';
    final alt = image['alt'] ?? '';
    final type = image['type'];
    final isInline = type == 'base64' || src.startsWith('data:');

    // Decode data URI if present
    Uint8List? dataBytes;
    if (isInline && src.contains('image/svg+xml')) {
      try {
        if (src.contains(';base64,')) {
          final base64String = src.split(',').last;
          dataBytes = base64Decode(base64String.trim());
        } else {
          // Handle percent-encoded SVG
          final encoded = src.split(',').last;
          final decoded = Uri.decodeComponent(encoded);
          dataBytes = utf8.encode(decoded);
        }
      } catch (e) {
        debugPrint('Error decoding SVG data URI: $e');
      }
    }

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        // Disable tap for inline images as requested
        onTap: isInline
            ? null
            : () {
                final htmlService =
                    Provider.of<HtmlService>(context, listen: false);
                htmlService.loadFromUrl(src,
                    switchToTab: HtmlService.viewerTab);
              },
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: src));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image Source copied to clipboard')),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CustomPaint(
                painter: CheckerboardPainter(
                  color1: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]!
                      : const Color(0xFFE0E0E0),
                  color2: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]!
                      : const Color(0xFFFFFFFF),
                ),
                child: _buildImageContent(src, isInline, dataBytes),
              ),
            ),
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    alt.isNotEmpty ? alt : 'No alt text',
                    style: const TextStyle(fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (image['size'] != null &&
                      (image['size']['decoded'] ?? 0) > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      FormatUtils.formatBytesWithTransfer(
                          Map<String, dynamic>.from(image['size'] as Map)),
                      style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(String src, bool isInline, Uint8List? dataBytes) {
    // If the image has a transparent background, the checkerboard shows through.
    // The text is separate (in a Column), so it shouldn't be obscured by the image itself.
    // However, if the aspect ratio is tight, the text might be pushed off or clipped.
    // We already use Expanded for the image, so it should shrink to fit available space.
    if (isInline && dataBytes != null && dataBytes.isNotEmpty) {
      final header = String.fromCharCodes(
          dataBytes.take(dataBytes.length < 100 ? dataBytes.length : 100));
      final isSvg = src.contains('image/svg+xml') ||
          header.toLowerCase().contains('<svg');

      if (isSvg) {
        final sanitizedData = sanitizeSvgData(dataBytes);
        if (sanitizedData.isEmpty) {
          return const Center(
              child: Icon(Icons.broken_image, color: Colors.grey));
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            double w =
                constraints.hasBoundedWidth ? constraints.maxWidth : 100.0;
            double h =
                constraints.hasBoundedHeight ? constraints.maxHeight : 100.0;
            if (w.isNaN || w.isInfinite) w = 100.0;
            if (h.isNaN || h.isInfinite) h = 100.0;
            return Center(
              child: SvgPicture.memory(
                sanitizedData,
                width: w,
                height: h,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('SVG Render Error (inline): $error');
                  return const Icon(Icons.broken_image, color: Colors.grey);
                },
              ),
            );
          },
        );
      }
    }

    // For inline SVGs that indicate base64 but failed to decode string
    if (isInline) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    return Center(
      child: src.toLowerCase().endsWith('.svg')
          ? SafeNetworkSvg(
              url: src,
              fit: BoxFit.contain,
              placeholderBuilder: (context) =>
                  const CircularProgressIndicator(),
            )
          : Image.network(
              src,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                );
              },
            ),
    );
  }
}

/// Font file card: downloads the font, registers it under a unique family
/// and renders a sample. Falls back to name-only if the format can't be loaded
/// (e.g. WOFF2 on some native platforms).
class _FontItem extends StatefulWidget {
  final Map font;
  const _FontItem({required this.font});

  @override
  State<_FontItem> createState() => _FontItemState();
}

class _FontItemState extends State<_FontItem> {
  static int _counter = 0;
  late final String _src = widget.font['src'].toString();
  final String _family = 'vsv_font_${_counter++}';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await NetworkAssetBundle(Uri.parse(_src)).load('');
      final loader = FontLoader(_family)..addFont(Future.value(data));
      await loader.load();
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      debugPrint('Font preview unavailable for $_src: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (name, format) = describeFontUrl(_src);
    final size = widget.font['size'];
    final hasSize = size is Map && (size['decoded'] ?? 0) > 0;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Clipboard.setData(ClipboardData(text: _src));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Font URL copied to clipboard')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loaded)
                Text(
                  'Aa Bb Cc 0123 — The quick brown fox',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: _family, fontSize: 24),
                ),
              if (_loaded) const SizedBox(height: 8),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                [
                  if (format.isNotEmpty) format,
                  if (hasSize)
                    FormatUtils.formatBytesWithTransfer(
                        Map<String, dynamic>.from(size)),
                ].join(' · '),
                style: TextStyle(
                    fontSize: 11,
                    color: scheme.primary,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                _src,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
