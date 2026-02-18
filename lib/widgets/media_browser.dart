import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
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
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Stack(
        fit: StackFit.expand,
        children: [
          // Full-tab checkerboard background
          CustomPaint(
            painter: CheckerboardPainter(
              color1: isDark ? Colors.grey[800]! : const Color(0xFFE0E0E0),
              color2: isDark ? Colors.grey[900]! : const Color(0xFFFFFFFF),
            ),
          ),
          InteractiveViewer(
            minScale: 0.1,
            maxScale: 5.0,
            child: Center(
              child: extension == 'svg'
                  ? SvgPicture.network(
                      widget.file.path,
                      fit: BoxFit.contain,
                      placeholderBuilder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    )
                  : Image.network(
                      widget.file.path,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildErrorView(),
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
        ],
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

class CheckerboardPainter extends CustomPainter {
  const CheckerboardPainter({
    this.color1 = const Color(0xFFE0E0E0), // Light grey
    this.color2 = const Color(0xFFFFFFFF), // White
    this.gridSize = 20.0,
  });

  final Color color1;
  final Color color2;
  final double gridSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Fill with color2 first
    paint.color = color2;
    canvas.drawRect(Offset.zero & size, paint);

    // Draw checkerboard squares
    paint.color = color1;
    for (double y = 0; y < size.height; y += gridSize) {
      for (double x = 0; x < size.width; x += gridSize) {
        if (((x / gridSize).floor() + (y / gridSize).floor()) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, gridSize, gridSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
