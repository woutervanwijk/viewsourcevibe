import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:view_source_vibe/models/inspection/page_layout.dart';
import 'package:view_source_vibe/services/derive/structure_view.dart';

/// What the wireframe's colours stand for.
enum StructureColoring { owner, element }

/// Legend entries and fill colours of the two colourings. Colours come from
/// the theme; the owner tones match the Privacy tab's categories.
class StructurePalette {
  final ColorScheme scheme;
  const StructurePalette(this.scheme);

  Color owner(BlockOwner o) => switch (o) {
        BlockOwner.page => scheme.surfaceContainerHighest,
        BlockOwner.ownFrame => scheme.tertiary,
        BlockOwner.thirdParty => Colors.orange,
        BlockOwner.advertising => Colors.red,
        BlockOwner.social => Colors.green,
      };

  Color kind(LayoutKind k) => switch (k) {
        LayoutKind.landmark => scheme.primary,
        LayoutKind.frame => scheme.tertiary,
        LayoutKind.heading => scheme.secondary,
        LayoutKind.media => scheme.error,
        LayoutKind.block => scheme.surfaceContainerHighest,
      };

  Color of(StructureBlock b, StructureColoring mode) =>
      mode == StructureColoring.owner ? owner(b.owner) : kind(b.block.kind);

  List<(String, Color)> legend(StructureColoring mode) =>
      mode == StructureColoring.owner
          ? [
              ('Page', owner(BlockOwner.page)),
              ('Own frame', owner(BlockOwner.ownFrame)),
              ('Third party', owner(BlockOwner.thirdParty)),
              ('Advertising', owner(BlockOwner.advertising)),
              ('Social', owner(BlockOwner.social)),
            ]
          : [
              ('Landmark', kind(LayoutKind.landmark)),
              ('Frame', kind(LayoutKind.frame)),
              ('Heading', kind(LayoutKind.heading)),
              ('Media', kind(LayoutKind.media)),
              ('Block', kind(LayoutKind.block)),
            ];
}

/// Draws the page's blocks in page proportions: [scale] logical px per CSS px.
/// When [background] is set (a screenshot of the page), it is drawn opaque
/// behind the blocks — stretched over the whole canvas when
/// [backgroundFullPage], else over the first screen only. The canvas is the
/// page at [model.layout]'s size, so a full-page background drawn at canvas
/// size always shares its coordinate space with the blocks, even when the
/// layout was measured at a different page height than the capture. The
/// blocks themselves are drawn 75% transparent so the screenshot shows
/// through.
class StructurePainter extends CustomPainter {
  final StructureModel model;
  final double scale;
  final StructureColoring coloring;
  final ColorScheme scheme;
  final ui.Image? background;
  final bool backgroundFullPage;

  StructurePainter({
    required this.model,
    required this.scale,
    required this.coloring,
    required this.scheme,
    this.background,
    this.backgroundFullPage = false,
  });

  /// Where the screenshot goes on the canvas. The shot is as wide as the
  /// viewport (not the document, which can overflow it, esp. on phones), so
  /// it is drawn [layout.viewportWidth] * [scale] wide with its own aspect
  /// ratio: one uniform scale, no stretching, so it lines up with the blocks
  /// at the top and drifts only if the page height changed after capture.
  /// Without a viewport width it falls back to the canvas width.
  static Rect backgroundRect(
      int imageWidth, int imageHeight, PageLayout layout, double scale) {
    final w = (layout.viewportWidth > 0 ? layout.viewportWidth : layout.width) *
        scale;
    final h = imageWidth > 0 ? w * imageHeight / imageWidth : 0.0;
    return Rect.fromLTWH(0, 0, w, h);
  }

  static const double minLabelWidth = 60;
  static const double minLabelHeight = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = StructurePalette(scheme);
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = scheme.outlineVariant);

    // The screenshot is the background, fully opaque: stretched over the
    // whole canvas for a full-page capture (the canvas is the page, so the
    // image and the blocks share coordinates), else over the first screen
    // only.
    if (background != null) {
      canvas.drawImageRect(
        background!,
        Rect.fromLTWH(
            0, 0, background!.width.toDouble(), background!.height.toDouble()),
        backgroundRect(
            background!.width, background!.height, model.layout, scale),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    final fill = Paint()..style = PaintingStyle.fill;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.outline;

    for (final s in model.blocks) {
      final b = s.block;
      final rect = Rect.fromLTWH(
          b.x * scale, b.y * scale, b.width * scale, b.height * scale);
      // 75% transparent: the screenshot shows through the structure overlay.
      fill.color = palette.of(s, coloring).withValues(alpha: 0.20);
      canvas.drawRect(rect, fill);
      if (b.fixed) {
        _dashedRect(canvas, rect, outline);
      } else {
        canvas.drawRect(rect, outline);
      }
      if (rect.width >= minLabelWidth && rect.height >= minLabelHeight) {
        _label(canvas, s.label, rect);
      }
    }

    final fold = model.layout.viewportHeight * scale;
    if (fold > 0 && fold < size.height) {
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = scheme.primary;
      _dashedLine(canvas, Offset(0, fold), Offset(size.width, fold), line);
      _text(canvas, 'first screen', Offset(4, fold + 2), size.width - 8,
          scheme.primary);
    }
  }

  void _label(Canvas canvas, String text, Rect rect) => _text(canvas, text,
      rect.topLeft + const Offset(3, 1), rect.width - 6, scheme.onSurface);

  void _text(
      Canvas canvas, String text, Offset at, double maxWidth, Color color) {
    final p = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 10, color: color)),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth < 1 ? 1 : maxWidth);
    p.paint(canvas, at);
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
    _dashed(canvas, path, paint);
  }

  void _dashedRect(Canvas canvas, Rect r, Paint paint) =>
      _dashed(canvas, Path()..addRect(r), paint);

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(StructurePainter old) =>
      !identical(old.model, model) ||
      old.scale != scale ||
      old.coloring != coloring ||
      old.scheme != scheme ||
      old.background != background ||
      old.backgroundFullPage != backgroundFullPage;
}
