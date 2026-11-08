import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/page_size.dart';
import 'package:view_source_vibe/services/derive/page_weight.dart';

import 'fixtures.dart';

Present<int> est(int v) =>
    Present(v, source: DataSource.server, provenance: Provenance.estimated);

void main() {
  final measured = res('https://a.test/a.js', tx: b(100), dec: b(300));
  final blocked = res('https://cdn.test/b.js');
  final blockedCss = res('https://cdn.test/c.css', type: 'link');

  group('derivePageWeight with estimates', () {
    test('measured + estimated + missing are kept apart', () {
      final p = inspection(
              browser: browserSnap(resources: [measured, blocked, blockedCss]))
          .copyWith(resourceEstimates: {'https://cdn.test/b.js': est(1000)});
      final w = derivePageWeight(p)!;
      expect(w.measuredTransfer, 100);
      expect(w.estimatedTransfer, 1000);
      expect(w.transfer, 1100);
      expect(w.missingCount, 1);
      expect(w.transferLowerBound, isTrue);
      expect(w.transferEstimated, isTrue);
      expect(w.decodedLowerBound, isTrue);
      expect(w.transferPrefix, '≥ ≈ ');
      // Decoded is never estimated.
      expect(w.decodedPrefix, '≥ ');
      expect(w.provenance, Provenance.estimated);
      expect(w.breakdown['scripts']!.transferPrefix, '≈ ');
      expect(w.breakdown['scripts']!.decodedPrefix, '≥ ');
      expect(w.breakdown['css']!.transferPrefix, '≥ ');
      expect(w.breakdown['scripts']!.estimatedTransfer, 1000);
      expect(w.breakdown['scripts']!.transfer, 1100);
      expect(w.breakdown['css']!.missingCount, 1);
      expect(w.breakdown['css']!.transfer, isNull);
    });

    test('estimates only: "≈ " and nothing missing', () {
      final p = inspection(
          browser: browserSnap(resources: [
        res('https://cdn.test/b.js', dec: b(5)),
      ])).copyWith(resourceEstimates: {'https://cdn.test/b.js': est(1000)});
      final w = derivePageWeight(p)!;
      expect(w.missingCount, 0);
      expect(w.measuredTransfer, isNull);
      expect(w.estimatedTransfer, 1000);
      expect(w.transferLowerBound, isFalse);
      expect(w.decodedLowerBound, isFalse);
      expect(w.transferPrefix, '≈ ');
      expect(w.decodedPrefix, '');
    });

    test('a failed lookup stays missing, never 0', () {
      final p = inspection(browser: browserSnap(resources: [blocked]))
          .copyWith(resourceEstimates: {
        'https://cdn.test/b.js': const Failed('timeout'),
      });
      final w = derivePageWeight(p)!;
      expect(w.transfer, isNull);
      expect(w.estimatedTransfer, isNull);
      expect(w.missingCount, 1);
      expect(w.transferPrefix, '≥ ');
    });

    test('no estimates: unchanged numbers, measured == transfer', () {
      final w = derivePageWeight(
          inspection(browser: browserSnap(resources: [measured])))!;
      expect(w.measuredTransfer, 100);
      expect(w.estimatedTransfer, isNull);
      expect(w.transfer, 100);
      expect(w.missingCount, 0);
      expect(w.transferPrefix, '');
      expect(w.decodedPrefix, '');
    });

    test('cache hits count: encoded size, else an estimate', () {
      final p = inspection(
          browser: browserSnap(resources: [
        res('https://a.test/hit.js', tx: b(300), dec: b(900), fromCache: true),
        res('https://a.test/c.js',
            tx: const Unavailable(UnavailableReason.servedFromCache),
            dec: b(900),
            fromCache: true),
      ])).copyWith(resourceEstimates: {
        'https://a.test/c.js': est(400),
      });
      final w = derivePageWeight(p)!;
      expect(w.transfer, 700);
      expect(w.estimatedTransfer, 400);
      expect(w.decoded, 1800);
      expect(w.missingCount, 0);
      expect(w.transferLowerBound, isFalse);
    });

    test('truncated resources make both totals lower bounds', () {
      final w = derivePageWeight(inspection(
          browser: browserSnap(truncated: true, resources: [measured])))!;
      expect(w.transferLowerBound, isTrue);
      expect(w.decodedLowerBound, isTrue);
    });
  });

  test('each number gets its own prefix; "≈" never on decoded', () {
    expect(
        formatSizePair(
            decoded: 1024,
            transfer: 38 * 1024,
            decodedPrefix: '≥ ',
            transferPrefix: '≈ '),
        '≥ 1 KB (↓ ≈ 38 KB)');
    expect(
        formatSizePair(transfer: 2048, transferPrefix: '≥ ≈ '), '↓ ≥ ≈ 2 KB');
    expect(
        formatSizePair(
            decoded: 2048,
            transfer: 2048,
            decodedPrefix: '≥ ',
            transferPrefix: '≥ '),
        '≥ 2 KB');
  });

  group('derivePageSize with estimates', () {
    PageSizeModel model(PageInspection p) =>
        (derivePageSize(p) as Present<PageSizeModel>).value;

    test('estimated rows show "≈ 12 KB"; images use transfer', () {
      final p = inspection(
          browser: browserSnap(platform: BrowserPlatform.ios, resources: [
        res('https://cdn.test/b.js'),
        res('https://cdn.test/i.png', type: 'img'),
        res('https://cdn.test/gone.js'),
      ])).copyWith(resourceEstimates: {
        'https://cdn.test/b.js': est(12 * 1024),
        'https://cdn.test/i.png': est(2048),
        'https://cdn.test/gone.js': const Failed('x'),
      });
      final m = model(p);
      final js = m.rows.singleWhere((r) => r.url.endsWith('b.js'));
      expect(js.estimated, isTrue);
      expect(js.size, 12 * 1024);
      expect(js.sizeLabel, '≈ 12 KB');
      final img = m.rows.singleWhere((r) => r.url.endsWith('i.png'));
      expect(img.estimated, isTrue);
      expect(img.sizeLabel, '≈ 2 KB');
      final gone = m.rows.singleWhere((r) => r.url.endsWith('gone.js'));
      expect(gone.size, isNull);
      expect(gone.sizeLabel, startsWith('size unknown ('));
      expect(m.rowsWithoutSize, 1);
      expect(m.estimatedCount, 2);
      expect(m.estimateNote, contains('2 sizes'));
      expect(m.estimateNote, contains('estimate'));
      expect(m.missingNote, contains('1 resource without size'));
      expect(m.weight.transferPrefix, '≥ ≈ ');
    });

    test('the generic "only part" clause is not added next to a specific note',
        () {
      final specific = model(inspection(
          browser: browserSnap(resources: [
        res('https://cdn.test/x.js'),
        res('https://a.test/a.js', tx: b(10)),
      ])));
      expect(specific.weight.decodedLowerBound, isTrue);
      expect(specific.missingNote, contains('1 resource without size'));
      expect(specific.missingNote, isNot(contains('only part')));

      final generic = model(inspection(
          browser: browserSnap(resources: [
        res('https://a.test/a.js', tx: b(10)),
      ])));
      // Only the decoded size is missing: it is not shown, so no note.
      expect(generic.missingNote, isNull);
    });

    test('lookup outcomes are told apart in the row note', () {
      final p = inspection(
          browser: browserSnap(resources: [
        res('https://cdn.test/u.js'),
        res('https://cdn.test/f.js'),
      ])).copyWith(resourceEstimates: {
        'https://cdn.test/u.js':
            const Unavailable(UnavailableReason.notReportedByServer),
        'https://cdn.test/f.js': const Failed('timeout'),
      });
      final m = model(p);
      expect(m.rows.singleWhere((r) => r.url.endsWith('u.js')).sizeNote,
          'the server reported no size');
      expect(m.rows.singleWhere((r) => r.url.endsWith('f.js')).sizeNote,
          'size lookup failed');
    });

    test('cache hits are counted and said so, apart from "no size"', () {
      final p = inspection(
          browser: browserSnap(resources: [
        res('https://a.test/c.js', tx: b(300), dec: b(900), fromCache: true),
        res('https://a.test/d.js', tx: b(300), dec: b(900), fromCache: true),
        res('https://cdn.test/x.js'),
      ]));
      final m = model(p);
      expect(
          m.missingNote, '1 resource without size (blocked by the platform)');
      expect(m.cacheNote, startsWith('2 served from the browser cache'));
      final c = m.rows.singleWhere((r) => r.url.endsWith('c.js'));
      expect(c.size, 300);
      expect(c.sizeLabel, '1 KB · cached');
    });

    test('everything estimated: no missing note, no lower-bound claim', () {
      final p = inspection(
          browser: browserSnap(platform: BrowserPlatform.android, resources: [
        res('https://cdn.test/b.js', dec: b(10)),
      ])).copyWith(resourceEstimates: {'https://cdn.test/b.js': est(2048)});
      final m = model(p);
      expect(m.estimatedCount, 1);
      expect(m.missingNote, isNull);
      expect(m.estimateNote, isNotNull);
    });
  });
}
