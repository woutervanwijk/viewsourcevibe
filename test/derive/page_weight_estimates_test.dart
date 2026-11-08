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
      expect(w.totalPrefix, '≥ ≈ ');
      expect(w.provenance, Provenance.estimated);
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
      expect(w.totalPrefix, '≈ ');
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
      expect(w.totalPrefix, '≥ ');
    });

    test('no estimates: unchanged numbers, measured == transfer', () {
      final w = derivePageWeight(
          inspection(browser: browserSnap(resources: [measured])))!;
      expect(w.measuredTransfer, 100);
      expect(w.estimatedTransfer, isNull);
      expect(w.transfer, 100);
      expect(w.missingCount, 0);
      expect(w.totalPrefix, '');
    });

    test('a cached resource is not estimated and stays without transfer', () {
      final p = inspection(
          browser: browserSnap(resources: [
        res('https://a.test/c.js',
            tx: const Unavailable(UnavailableReason.servedFromCache),
            dec: b(900)),
      ])).copyWith(resourceEstimates: {
        'https://a.test/c.js': est(1),
      });
      // An estimate never overrides the cache case: transfer stays unknown.
      final w = derivePageWeight(p)!;
      expect(w.estimatedTransfer, isNull);
      expect(w.decoded, 900);
      expect(w.missingCount, 1);
    });
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
      expect(m.weight.totalPrefix, '≥ ≈ ');
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
