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
  test('stitchScreenshots stacks the shots at their offsets and sizes to '
      'the page height', () async {
    final top = await solidPng(100, 50, const ui.Color(0xFF0000FF));
    final bottom = await solidPng(100, 50, const ui.Color(0xFF00FF00));
    // Viewport 100 CSS px wide, shots 100 px wide (scale 1), page 200 px tall.
    final img = await stitchScreenshots(
        [(top, 0), (bottom, 50)],
        pageHeight: 200,
        viewportWidth: 100);
    expect(img, isNotNull);
    expect(img!.width, 100);
    expect(img.height, 200);

    final raw = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final px = raw!.buffer.asUint8List();
    int at(int x, int y) => (y * img.width + x) * 4;
    // Top shot in the top half, bottom shot below it.
    expect(px[at(10, 10) + 2], 0xFF); // blue channel: top is blue
    expect(px[at(10, 10)], 0x00);
    expect(px[at(10, 60) + 1], 0xFF); // green shot below
    img.dispose();
  });

  test('stitchScreenshots places the clamped last shot at its real offset, '
      'not one viewport too low', () async {
    final top = await solidPng(100, 100, const ui.Color(0xFF0000FF));
    final bottom = await solidPng(100, 100, const ui.Color(0xFF00FF00));
    // Page 150 px tall, viewport 100: the second scroll request (100) is
    // clamped to 50, so the bottom shot really starts at CSS y=50.
    final img = await stitchScreenshots(
        [(top, 0), (bottom, 50)],
        pageHeight: 150,
        viewportWidth: 100);
    expect(img, isNotNull);
    expect(img!.width, 100);
    expect(img.height, 150);

    final raw = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final px = raw!.buffer.asUint8List();
    int at(int x, int y) => (y * img.width + x) * 4;
    expect(px[at(10, 20) + 2], 0xFF); // still the blue top shot at y=20
    expect(px[at(10, 120) + 1], 0xFF); // green bottom shot covers the bottom
    img.dispose();
  });

  test('stitchScreenshots scales the page height to the shot width',
      () async {
    final shot = await solidPng(200, 100, const ui.Color(0xFFFFFFFF));
    // Viewport 400 CSS px wide, shot 200 px wide (scale 0.5), page 800 tall.
    final img = await stitchScreenshots(
        [(shot, 0), (shot, 400)],
        pageHeight: 800,
        viewportWidth: 400);
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
        await stitchScreenshots(
            [(Uint8List.fromList([1, 2, 3]), 0)],
            pageHeight: 100,
            viewportWidth: 100),
        isNull);
  });
}
