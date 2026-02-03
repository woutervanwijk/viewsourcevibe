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

    final List<dynamic> images = metadata['media']['images'] ?? [];
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

    return ListView(
      primary: false,
      padding: const EdgeInsets.all(16),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
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
                painter: const CheckerboardPainter(),
                child: _buildImageContent(src, isInline, dataBytes),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                alt.isNotEmpty ? alt : 'No alt text',
                style: const TextStyle(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(String src, bool isInline, Uint8List? dataBytes) {
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
        ? SvgPicture.network(
            src,
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
