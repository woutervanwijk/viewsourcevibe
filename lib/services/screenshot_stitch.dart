import 'dart:typed_data';
import 'dart:ui'
    show Canvas, FilterQuality, Image, Paint, PictureRecorder, Rect,
        instantiateImageCodec;

/// Stitches viewport screenshots taken while scrolling through a page into
/// one full-page image. Each entry is a shot plus the page's actual scroll
/// offset (CSS px) it was taken at: the browser rounds and clamps scroll
/// positions (at the bottom the last shot starts at pageHeight - viewport,
/// not at steps*viewport), so shots are placed at their real offset to keep
/// the content aligned. [pageHeight] and [viewportWidth] are the page's CSS
/// dimensions at capture time; the result's width is the first shot's width
/// and its height the page height at that scale. Returns null when no shot
/// decodes.
Future<Image?> stitchScreenshots(
  List<(Uint8List shot, double offset)> shots, {
  required double pageHeight,
  required double viewportWidth,
}) async {
  final images = <(Image img, double offset)>[];
  for (final (shot, offset) in shots) {
    try {
      final codec = await instantiateImageCodec(shot);
      final frame = await codec.getNextFrame();
      codec.dispose();
      images.add((frame.image, offset));
    } catch (_) {
      // Skip a shot that does not decode.
    }
  }
  if (images.isEmpty || viewportWidth <= 0) return null;
  final w = images.first.$1.width.toDouble();
  final targetH =
      (pageHeight * w / viewportWidth).clamp(1.0, 100000.0).ceilToDouble();
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.clipRect(Rect.fromLTWH(0, 0, w, targetH));
  final scale = w / viewportWidth; // image px per CSS px
  for (final (img, offset) in images) {
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, offset * scale, w, img.height.toDouble()),
      Paint()..filterQuality = FilterQuality.low,
    );
    img.dispose();
  }
  final picture = recorder.endRecording();
  final out = await picture.toImage(w.ceil(), targetH.ceil());
  picture.dispose();
  return out;
}
