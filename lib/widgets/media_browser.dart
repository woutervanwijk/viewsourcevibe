import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:view_source_vibe/models/html_file.dart';

// Conditional import for web-specific features
import 'package:view_source_vibe/widgets/media_browser_platform_proxy.dart'
    if (dart.library.js_util) 'package:view_source_vibe/widgets/media_browser_web_impl.dart'
    as platform_impl;

class MediaBrowser extends StatefulWidget {
  final HtmlFile file;

  const MediaBrowser({super.key, required this.file});

  @override
  State<MediaBrowser> createState() => _MediaBrowserState();
}

class _MediaBrowserState extends State<MediaBrowser> {
  final String viewID = 'media-browser-view';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      platform_impl.registerMediaIframe(viewID, widget.file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extension = widget.file.extension.toLowerCase();
    final isImage = const {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'ico',
      'avif',
      'svg'
    }.contains(extension);

    // Zoomable image viewer for all platforms
    if (isImage && widget.file.isUrl) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: InteractiveViewer(
          minScale: 0.1,
          maxScale: 5.0,
          child: Center(
            child: Image.network(
              widget.file.path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildErrorView(),
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
            ),
          ),
        ),
      );
    }

    if (kIsWeb) {
      return HtmlElementView(
        viewType: viewID,
        key: ValueKey(widget.file.path),
      );
    }

    return _buildFallbackView();
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline,
            size: 64, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        const Text('Error loading media'),
        const SizedBox(height: 8),
        Text(
          'Could not load ${widget.file.name}',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFallbackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 24),
            Text(
              'View media in browser',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This file type (${widget.file.extension}) is best viewed in an external browser.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
