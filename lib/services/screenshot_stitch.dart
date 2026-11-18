import 'dart:typed_data';
import 'dart:ui'
    show Canvas, FilterQuality, Image, Paint, PictureRecorder, Rect,
        instantiateImageCodec;

/// Stitches viewport screenshots taken while scrolling through a page into
/// one full-page image. [shots] are the screenshots in top-to-bottom order,
/// [pageHeight] and [viewportWidth] the page's CSS dimensions; the result's
/// width is the first shot's width and its height is the page height at that
/// scale. Returns null when no shot decodes.
Future<Image?> stitchScreenshots(
  List<Uint8List> shots, {
  required double pageHeight,
  required double viewportWidth,
}) async {
  final images = <Image>[];
  for (final shot in shots) {
    try {
      final codec = await instantiateImageCodec(shot);
      final frame = await codec.getNextFrame();
      codec.dispose();
      images.add(frame.image);
    } catch (_) {
      // Skip a shot that does not decode.
    }
  }
  if (images.isEmpty || viewportWidth <= 0) return null;
  final w = images.first.width.toDouble();
  final targetH =
      (pageHeight * w / viewportWidth).clamp(1.0, 100000.0).ceilToDouble();
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.clipRect(Rect.fromLTWH(0, 0, w, targetH));
  var y = 0.0;
  for (final img in images) {
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, y, w, img.height.toDouble()),
      Paint()..filterQuality = FilterQuality.low,
    );
    y += img.height;
    img.dispose();
  }
  final picture = recorder.endRecording();
  final out = await picture.toImage(w.ceil(), targetH.ceil());
  picture.dispose();
  return out;
}
