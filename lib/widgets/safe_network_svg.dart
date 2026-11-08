import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:view_source_vibe/services/derive/media.dart';

export 'package:view_source_vibe/services/derive/media.dart' show sanitizeSvgData;


/// Network SVG that never crashes the vector compiler: the bytes are fetched,
/// checked for HTML error pages and sanitized (see [sanitizeSvgData]) before
/// being handed to [SvgPicture.memory]. Unlike a raw `SvgPicture.network`, a
/// dimensionless SVG fails into [errorWidget] instead of an unhandled
/// 'Bad state: SVG did not specify dimensions' exception.
class SafeNetworkSvg extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final WidgetBuilder placeholderBuilder;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const SafeNetworkSvg({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    required this.placeholderBuilder,
    this.width,
    this.height,
    this.errorWidget,
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

  @override
  void didUpdateWidget(covariant SafeNetworkSvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadingFuture = _loadSvg();
    }
  }

  Future<Uint8List?> _loadSvg() async {
    try {
      final uri = Uri.tryParse(widget.url);
      if (uri == null) return null;

      final bundle = NetworkAssetBundle(uri);
      final data = await bundle.load('');
      final bytes = data.buffer.asUint8List();

      // Simple validation to prevent HTML parsing
      // Check first 1KB for <html or <!DOCTYPE html
      final head = String.fromCharCodes(
        bytes.sublist(0, bytes.length < 1024 ? bytes.length : 1024),
      ).toLowerCase();

      if (head.contains('<html') || head.contains('<!doctype html')) {
        debugPrint(
            'SVG Validation Failed: Content looks like HTML for ${widget.url}');
        return null; // Invalid SVG
      }

      return sanitizeSvgData(bytes);
    } catch (e) {
      debugPrint('Error loading SVG: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.errorWidget ??
        const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    return FutureBuilder<Uint8List?>(
      future: _loadingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.placeholderBuilder(context);
        }

        if (snapshot.hasError || snapshot.data == null) {
          return fallback;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            double w = widget.width ??
                (constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : 100.0);
            double h = widget.height ??
                (constraints.hasBoundedHeight
                    ? constraints.maxHeight
                    : 100.0);
            if (w.isNaN || w.isInfinite) w = 100.0;
            if (h.isNaN || h.isInfinite) h = 100.0;
            return Center(
              child: SvgPicture.memory(
                snapshot.data!,
                width: w,
                height: h,
                fit: widget.fit,
                placeholderBuilder: widget.placeholderBuilder,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('SVG Render Error (network): $error');
                  return const Icon(Icons.broken_image, color: Colors.grey);
                },
              ),
            );
          },
        );
      },
    );
  }
}
