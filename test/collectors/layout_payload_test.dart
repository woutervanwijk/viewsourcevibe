import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_layout.dart';
import 'package:view_source_vibe/services/collectors/layout_payload.dart';

final u = Uri.parse('https://a.test/x');

String payload({List<Map<String, Object?>>? blocks, int total = 57}) =>
    jsonEncode({
      'v': 1,
      'vw': 390,
      'vh': 800,
      'w': 390,
      'h': 5210,
      'total': total,
      'blocks': blocks ??
          [
            {
              't': 'header',
              'r': 'banner',
              'i': 'top',
              'c': 'bar wide',
              'x': 0,
              'y': 0,
              'w': 390,
              'h': 64,
              'd': 1,
              'n': 12,
              'k': 'landmark',
              's': '',
              'f': 1,
              'tx': ''
            }
          ],
    });

PageLayout present(Observed<PageLayout> o) => (o as Present<PageLayout>).value;

void main() {
  test('the payload of Task 1 parses', () {
    final l = present(parseLayoutPayload(payload(), pageUrl: u));
    expect(l.height, 5210);
    expect(l.viewportWidth, 390);
    expect(l.blocks.single.kind, LayoutKind.landmark);
    expect(l.blocks.single.tag, 'header');
    expect(l.blocks.single.fixed, isTrue);
    expect(l.blocks.single.area, 390 * 64);
    expect(l.truncated, isTrue); // total 57, one block
  });

  test('an empty document is unavailable with the reason', () {
    final o = parseLayoutPayload('{"v":1,"empty":true}', pageUrl: u);
    expect((o as Unavailable<PageLayout>).detail, 'the page has no layout');
  });

  test('no blocks and a total of 0 is also "no layout"', () {
    final o = parseLayoutPayload(payload(blocks: [], total: 0), pageUrl: u);
    expect(o, isA<Unavailable<PageLayout>>());
    expect((o as Unavailable<PageLayout>).detail, 'the page has no layout');
  });

  test('bad blocks are skipped, bad payloads fail', () {
    final l = present(parseLayoutPayload(
        payload(blocks: [
          {'k': 'weird', 'x': 0, 'y': 0, 'w': 5, 'h': 5},
          {'k': 'frame', 'x': 'a', 'y': 0, 'w': 5, 'h': 5},
        ], total: 2),
        pageUrl: u));
    expect(l.blocks, isEmpty);
    expect(parseLayoutPayload('not json', pageUrl: u), isA<Failed>());
    final o = parseLayoutPayload(42, pageUrl: u) as Unavailable<PageLayout>;
    expect(o.reason, UnavailableReason.unsupportedPlatform);
  });

  test('a relative frame source is resolved', () {
    final l = present(parseLayoutPayload(
        payload(blocks: [
          {'k': 'frame', 'x': 0, 'y': 0, 'w': 5, 'h': 5, 's': '/embed'},
        ], total: 1),
        pageUrl: u));
    expect(l.blocks.single.src, 'https://a.test/embed');
  });
}
