import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_layout.dart';
import 'package:view_source_vibe/services/collectors/layout_payload.dart';

final u = Uri.parse('https://a.test/x');

String payload(
        {List<Map<String, Object?>>? blocks,
        int total = 57,
        Map<String, Object?> extra = const {}}) =>
    jsonEncode({
      ...extra,
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

  test('a sized page without qualifying boxes is present with no blocks', () {
    final l = present(parseLayoutPayload(payload(blocks: [], total: 0),
        pageUrl: u));
    expect(l.blocks, isEmpty);
    expect(l.height, 5210);
  });

  test('a zero-size document is "no layout"', () {
    for (final k in ['w', 'h']) {
      final m = jsonDecode(payload(blocks: [], total: 0))
          as Map<String, Object?>
        ..[k] = 0;
      final o = parseLayoutPayload(jsonEncode(m), pageUrl: u);
      expect((o as Unavailable<PageLayout>).detail, 'the page has no layout',
          reason: k);
    }
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

  test('a missing viewport or document size is Failed, not 0', () {
    for (final key in ['vw', 'vh', 'w', 'h']) {
      final m = jsonDecode(payload()) as Map<String, Object?>..remove(key);
      expect(parseLayoutPayload(jsonEncode(m), pageUrl: u), isA<Failed>(),
          reason: key);
    }
  });

  test('a block without depth or descendants is dropped', () {
    Map<String, Object?> b(Map<String, Object?> o) =>
        {'k': 'frame', 'x': 0, 'y': 0, 'w': 5, 'h': 5, 'd': 1, 'n': 2, ...o};
    final l = present(parseLayoutPayload(
        payload(blocks: [
          b({}),
          b({'d': null}),
          b({'n': 'x'}),
        ], total: 3),
        pageUrl: u));
    expect(l.blocks.length, 1);
  });

  test('scanCapped is carried', () {
    expect(
        present(parseLayoutPayload(payload(extra: {'scanCapped': 1}),
                pageUrl: u))
            .scanCapped,
        isTrue);
    expect(present(parseLayoutPayload(payload(), pageUrl: u)).scanCapped,
        isFalse);
  });

  test('a relative frame source is resolved', () {
    final l = present(parseLayoutPayload(
        payload(blocks: [
          {'k': 'frame', 'x': 0, 'y': 0, 'w': 5, 'h': 5, 'd': 1, 'n': 0, 's': '/embed'},
        ], total: 1),
        pageUrl: u));
    expect(l.blocks.single.src, 'https://a.test/embed');
  });
}
