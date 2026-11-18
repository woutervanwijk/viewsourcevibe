import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/screenshot_stitch.dart';

Future<Uint8List> solidPng(int w, int h, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = color);
  final img = await recorder.endRecording().toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  test('stitchScreenshots stacks the shots and sizes to the page height',
      () async {
    final top = await solidPng(100, 50, const ui.Color(0xFF0000FF));
    final bottom = await solidPng(100, 50, const ui.Color(0xFF00FF00));
    // Viewport 100 CSS px wide, shots 100 px wide (scale 1), page 200 px tall.
    final img = await stitchScreenshots([top, bottom],
        pageHeight: 200, viewportWidth: 100);
    expect(img, isNotNull);
    expect(img!.width, 100);
    expect(img.height, 200);

    final raw = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final px = raw!.buffer.asUint8List();
    int at(int x, int y) => (y * img.width + x) * 4;
    // Top shot in the top half, bottom shot below it.
    expect(px[at(10, 10) + 2], 0xFF); // blue channel of the red... top is blue
    expect(px[at(10, 10)], 0x00);
    expect(px[at(10, 60) + 1], 0xFF); // green shot below
    img.dispose();
  });

  test('stitchScreenshots scales the page height to the shot width',
      () async {
    final shot = await solidPng(200, 100, const ui.Color(0xFFFFFFFF));
    // Viewport 400 CSS px wide, shot 200 px wide (scale 0.5), page 800 tall.
    final img = await stitchScreenshots([shot, shot],
        pageHeight: 800, viewportWidth: 400);
    expect(img, isNotNull);
    expect(img!.width, 200);
    expect(img.height, 400);
    img.dispose();
  });

  test('stitchScreenshots returns null without decodable shots', () async {
    expect(
        await stitchScreenshots([], pageHeight: 100, viewportWidth: 100),
        isNull);
    expect(
        await stitchScreenshots([Uint8List.fromList([1, 2, 3])],
            pageHeight: 100, viewportWidth: 100),
        isNull);
  });
}
