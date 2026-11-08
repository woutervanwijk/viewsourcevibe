import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/widgets/safe_network_svg.dart';

Uint8List svg(String body) => utf8.encode(body);

void main() {
  group('sanitizeSvgData', () {
    test('injects a viewBox when the root svg has no dimensions', () {
      final out = utf8.decode(sanitizeSvgData(
          svg('<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0h10v10z"/></svg>')));
      expect(out, contains('viewBox="0 0 24 24"'));
    });

    test('injects a viewBox when only width is present (no height)', () {
      // The compiler needs viewBox or width AND height; width alone crashes.
      final out = utf8.decode(sanitizeSvgData(
          svg('<svg width="100"><rect width="10" height="10"/></svg>')));
      expect(out, contains('viewBox="0 0 24 24"'));
    });

    test('keeps an existing viewBox untouched', () {
      final out = utf8.decode(sanitizeSvgData(
          svg('<svg viewBox="0 0 48 48"><path d="M0 0h10v10z"/></svg>')));
      expect(out, contains('viewBox="0 0 48 48"'));
      expect(out, isNot(contains('0 0 24 24')));
    });

    test('keeps width+height without a viewBox', () {
      final out = utf8.decode(sanitizeSvgData(
          svg('<svg width="24" height="24"><path d="M0 0h10v10z"/></svg>')));
      expect(out, isNot(contains('viewBox')));
    });

    test('converts percentage coordinates using the viewBox', () {
      final out = utf8.decode(sanitizeSvgData(svg(
          '<svg viewBox="0 0 200 100"><circle cx="50%" cy="50%" r="25%"/></svg>')));
      expect(out, contains('cx="100.0"'));
      expect(out, contains('cy="50.0"'));
      expect(out, contains('r="50.0"'));
    });

    test('returns the original bytes on empty input, never throws', () {
      expect(sanitizeSvgData(Uint8List(0)), isEmpty);
      final raw = Uint8List.fromList([0xff, 0xfe, 0x00, 0x01]);
      expect(sanitizeSvgData(raw), isNotEmpty);
    });
  });
}
