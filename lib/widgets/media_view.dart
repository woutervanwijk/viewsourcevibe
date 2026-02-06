import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:view_source_vibe/widgets/media_browser.dart';

class MediaView extends StatelessWidget {
  const MediaView({super.key});

  @override
  Widget build(BuildContext context) {
    final htmlService = Provider.of<HtmlService>(context);
    final metadata = htmlService.pageMetadata;

    if (metadata == null || metadata['media'] == null) {
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

    final List<dynamic> images = List.from(metadata['media']['images'] ?? [])
      ..sort((a, b) {
        final sizeA = (a as Map)['size']?['decoded'] ?? 0;
        final sizeB = (b as Map)['size']?['decoded'] ?? 0;
        if (sizeB != sizeA) {
          return (sizeB as num).compareTo(sizeA as num);
        }
        return (a['src'] ?? '')
            .toString()
            .compareTo((b['src'] ?? '').toString());
      });
    final List<dynamic> videos = metadata['media']['videos'] ?? [];

    if (images.isEmpty && videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.perm_media_outlined,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            const Text('No Images or Videos found'),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (videos.isNotEmpty) ...[
            _buildSectionTitle(context, 'Videos (${videos.length})'),
            const SizedBox(height: 8),
            ...videos.map((video) => _buildVideoItem(context, video)),
            const SizedBox(height: 24),
          ],
          if (images.isNotEmpty) ...[
            _buildSectionTitle(context, 'Images (${images.length})'),
            const SizedBox(height: 8),
            GridView.builder(
              primary: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:
                    200, // Responsive: more columns on wider screens
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) =>
                  _buildImageItem(context, images[index]),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)}${suffixes[i]}';
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
          htmlService.loadFromUrl(src, switchToTab: 0);
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
    if (isInline && src.startsWith('data:image/svg+xml;base64,')) {
      try {
        final base64String = src.split(',').last;
        dataBytes = base64Decode(base64String);
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
                htmlService.loadFromUrl(src, switchToTab: 0);
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
                      _formatBytes(image['size']['decoded']),
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
    if (isInline && dataBytes != null) {
      return SvgPicture.memory(
        dataBytes,
        fit: BoxFit.contain,
        placeholderBuilder: (context) =>
            const Center(child: CircularProgressIndicator()),
      );
    }

    // For inline SVGs that indicate base64 but failed to decode string
    if (isInline) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    return src.toLowerCase().endsWith('.svg')
        ? SafeNetworkSvg(
            url: src,
            fit: BoxFit.contain,
            placeholderBuilder: (context) =>
                const Center(child: CircularProgressIndicator()),
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
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
          );
  }
}

class SafeNetworkSvg extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final WidgetBuilder placeholderBuilder;

  const SafeNetworkSvg({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    required this.placeholderBuilder,
  });

  @override
  State<SafeNetworkSvg> createState() => _SafeNetworkSvgState();
}

class _SafeNetworkSvgState extends State<SafeNetworkSvg> {
  Future<Uint8List?>? _loadingFuture;

  @override
  void initState() {
    super.initState();
    _loadingFuture = _loadSvg();
  }

  Future<Uint8List?> _loadSvg() async {
    try {
      // Use HtmlService's platform-agnostic HTTP client if possible, but for simple
      // check we can stick to basic logic or use the existing HtmlService from context if I could access it.
      // But creating a new Client is safer for isolation.
      // Note: We need to import http package
      // Since I cannot easily add imports in this tool call without replacing the top,
      // I will assume I can add the import in a separate call or use a workaround.
      // Actually, I should add the import first.

      // Since I can't add import here, I will depend on HtmlService helper?
      // No, HtmlService doesn't expose a simple "getBytes" for arbitrary URL easily without side effects.

      // I'll assume standard http GET for now and fix imports in next step.
      // Or I can use NetworkAssetBundle which is available in Flutter.

      final bundle = NetworkAssetBundle(Uri.parse(widget.url));
      final data = await bundle.load("");
      final bytes = data.buffer.asUint8List();

      // Simple validation to prevent HTML parsing
      // Check first 1KB for <html or <!DOCTYPE htmlTags
      final head = String.fromCharCodes(
        bytes.sublist(0, bytes.length < 1024 ? bytes.length : 1024),
      ).toLowerCase();

      if (head.contains('<html') || head.contains('<!doctype html')) {
        debugPrint(
            'SVG Validation Failed: Content looks like HTML for ${widget.url}');
        return null; // Invalid SVG
      }

      return bytes;
    } catch (e) {
      debugPrint('Error loading SVG: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _loadingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholderBuilder(context);
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const Center(
              child: Icon(Icons.broken_image, color: Colors.grey));
        }

        return SvgPicture.memory(
          snapshot.data!,
          fit: widget.fit,
          placeholderBuilder: widget.placeholderBuilder,
        );
      },
    );
  }
}
