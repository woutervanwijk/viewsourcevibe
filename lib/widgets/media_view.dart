import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/media.dart';
import 'package:view_source_vibe/services/derive/metadata_view.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:view_source_vibe/widgets/media_browser.dart';
import '../utils/font_url.dart';

class MediaView extends StatelessWidget {
  const MediaView({super.key});

  /// Counts builds (tests check that unrelated changes do not rebuild).
  @visibleForTesting
  static int builds = 0;

  Widget _status(BuildContext context, Widget lead, String title,
      {String? text, bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            lead,
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center),
            if (text != null) ...[
              const SizedBox(height: 8),
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: error ? scheme.error : Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    builds++;
    final state =
        context.select<HtmlService, Observed<MediaModel>>((s) => s.mediaState);
    final icon = Icon(Icons.perm_media_outlined,
        size: 64, color: Theme.of(context).colorScheme.outlineVariant);

    switch (state) {
      case Pending<MediaModel>():
        return _status(context, const CircularProgressIndicator(),
            'Reading the page metadata…');
      case Failed<MediaModel>(:final error):
        return _status(
            context,
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            'Media could not be read',
            text: error,
            error: true);
      case Unavailable<MediaModel>():
        return _status(context, icon, 'No Media Detected',
            text: 'Load an HTML page to view detected media.');
      case Present<MediaModel>(value: final model):
        if (model.isEmpty) {
          // The extraction succeeded and found nothing.
          return _status(context, icon, 'No Images, Videos or Fonts found',
              text: 'Checked: ${documentLabel(model.docSource)}');
        }
        return _buildModel(context, model);
    }
  }

  Widget _buildModel(BuildContext context, MediaModel model) {
    final images = model.images;
    final inlineImages = model.inlineImages;
    final videos = model.videos;
    final fonts = model.fonts;

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
                      SizedBox(
                          key: ValueKey('font:${font.src}'),
                          width: w,
                          child: _FontItem(font: font)),
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

  Widget _buildImageGrid(BuildContext context, List<MediaItem> items) {
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
      itemBuilder: (context, index) => KeyedSubtree(
          key: ValueKey('image:${items[index].src}'),
          child: _buildImageItem(context, items[index])),
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

  Widget _buildVideoItem(BuildContext context, MediaItem video) {
    final src = video.src;
    final provider = video.provider;
    final unresolved = video.unresolvedNote;

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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              src,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            Text(
              unresolved == null
                  ? video.sizeLabel
                  : '$unresolved; ${video.sizeLabel}',
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        trailing:
            unresolved == null ? const Icon(Icons.open_in_new, size: 16) : null,
        onTap: unresolved != null
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
            const SnackBar(content: Text('URL copied to clipboard')),
          );
        },
      ),
    );
  }

  Widget _buildImageItem(BuildContext context, MediaItem image) {
    final src = image.src;
    final alt = image.alt;
    final isInline = image.inline;
    final unresolved = image.unresolvedNote;

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
        onTap: isInline || unresolved != null
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
                child: unresolved != null
                    ? const Center(
                        child: Icon(Icons.link_off, color: Colors.grey))
                    : _buildImageContent(src, isInline, dataBytes),
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
                  const SizedBox(height: 4),
                  Text(
                    unresolved == null
                        ? image.sizeLabel
                        : '$unresolved; ${image.sizeLabel}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: image.sizeBytes == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
  final MediaItem font;
  const _FontItem({required this.font});

  @override
  State<_FontItem> createState() => _FontItemState();
}

class _FontItemState extends State<_FontItem> {
  static int _counter = 0;
  String _family = 'vsv_font_${_counter++}';
  bool _loaded = false;

  String get _src => widget.font.src;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_FontItem old) {
    super.didUpdateWidget(old);
    // A different font file: forget the previous preview.
    if (old.font.src != widget.font.src) {
      _family = 'vsv_font_${_counter++}';
      _loaded = false;
      _load();
    }
  }

  Future<void> _load() async {
    final src = _src;
    if (widget.font.unresolvedNote != null) return;
    try {
      final data = await NetworkAssetBundle(Uri.parse(src)).load('');
      if (!mounted || src != _src) return;
      final loader = FontLoader(_family)..addFont(Future.value(data));
      await loader.load();
      if (mounted && src == _src) setState(() => _loaded = true);
    } catch (e) {
      debugPrint('Font preview unavailable for $_src: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (name, format) = describeFontUrl(_src);
    final unresolved = widget.font.unresolvedNote;
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
                  widget.font.sizeLabel,
                  if (unresolved != null) unresolved,
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

      return sanitizeSvgData(bytes);
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
