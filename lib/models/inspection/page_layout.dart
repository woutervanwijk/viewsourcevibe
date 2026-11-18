enum LayoutKind { landmark, frame, heading, media, block }

/// One measured box of the page, in CSS pixels in page space.
class LayoutBlock {
  final String tag, role, id, classes, src, text;
  final double x, y, width, height;
  final int depth, descendants;
  final LayoutKind kind;

  /// position: fixed or sticky (overlaps the content).
  final bool fixed;

  const LayoutBlock({
    required this.tag,
    required this.role,
    required this.id,
    required this.classes,
    required this.src,
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.depth,
    required this.descendants,
    required this.kind,
    required this.fixed,
  });

  double get area => width * height;
}

/// The page's measured layout: the viewport, the whole document and the
/// first qualifying boxes ([totalBlocks] counts all of them).
class PageLayout {
  final double viewportWidth, viewportHeight, width, height;
  final int totalBlocks;
  final List<LayoutBlock> blocks;

  /// The page had more elements than the script scanned.
  final bool scanCapped;

  bool get truncated => totalBlocks > blocks.length;

  const PageLayout({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.width,
    required this.height,
    required this.totalBlocks,
    required this.blocks,
    this.scanCapped = false,
  });
}
