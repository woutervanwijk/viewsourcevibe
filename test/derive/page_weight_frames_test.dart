import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/page_size.dart';
import 'package:view_source_vibe/services/derive/page_weight.dart';

import 'fixtures.dart';

Present<int> bt(int v) => Present(v, source: DataSource.browser);

void main() {
  final page = browserSnap(url: 'https://www.a.test/page', resources: [
    res('https://www.a.test/app.js', tx: bt(1000)),
    // The ad iframe document and what it loaded.
    res('https://ads.test/frame.html', type: 'iframe', tx: bt(300)),
    res('https://ads.test/ad.js',
        tx: bt(5000), frameOrigin: 'https://ads.test'),
    res('https://cdn.ads.test/creative.jpg',
        type: 'img', frameOrigin: 'https://ads.test'),
    // A same-origin frame counts as the page's own.
    res('https://a.test/widget.css',
        type: 'link', tx: bt(200), frameOrigin: 'https://a.test'),
  ]);

  test('cross-origin iframes and their contents form their own bucket', () {
    final w = derivePageWeightOf(page)!;
    final frames = w.breakdown['thirdPartyFrames']!;
    expect(frames.count, 3);
    expect(frames.transfer, 5300);
    expect(frames.missingCount, 1, reason: 'creative.jpg has no size');
    expect(w.breakdown['scripts']!.transfer, 1000);
    expect(w.breakdown['css']!.transfer, 200);
    // Iframe content counts in the total, as Lighthouse counts it.
    expect(w.transfer, 6500);
    expect(w.transferLowerBound, isTrue);
  });

  test('an own lookup sizes hidden iframe content', () {
    final w = derivePageWeightOf(page, estimates: {
      'https://cdn.ads.test/creative.jpg': Present(40000,
          source: DataSource.server, provenance: Provenance.estimated),
    })!;
    expect(w.breakdown['thirdPartyFrames']!.transfer, 45300);
    expect(w.transferLowerBound, isFalse);
    expect(w.transferEstimated, isTrue);
  });

  test('live and fresh loads go through the same derivation', () {
    final fresh = browserSnap(resources: [
      res('https://a.test/app.js', tx: bt(1000)),
      res('https://a.test/late.js', tx: bt(9000)),
    ]);
    final p = inspection(browser: browserSnap(resources: [
      res('https://a.test/app.js', tx: bt(1000)),
    ])).copyWith(
        freshLoad: Present(fresh, source: DataSource.browser),
        browserSettled: true);
    expect(derivePageWeight(p)!.transfer, 1000);
    expect(deriveFreshPageWeight(p)!.transfer, 10000);
    final m = (derivePageSize(p) as Present<PageSizeModel>).value;
    expect(m.weight.transfer, 1000);
    final f = (m.fresh as Present<PageSizeModel>).value;
    expect(f.weight.transfer, 10000);
    expect(f.rows.first.url, 'https://a.test/late.js');
    // The verdict uses the fresh load and says so.
    expect(m.lighthouseNote, startsWith('Lighthouse (fresh load): good'));
    expect(m.stillCollecting, isFalse);
  });

  test('without a fresh load the verdict is on this load; not measured', () {
    final p = inspection(browser: page);
    final m = (derivePageSize(p) as Present<PageSizeModel>).value;
    expect(m.fresh, isA<Unavailable<PageSizeModel>>());
    expect(m.lighthouseNote, startsWith('Lighthouse (this load)'));
    expect(m.stillCollecting, isTrue);
    expect(m.rows.where((r) => r.thirdPartyFrame).map((r) => r.url).toSet(), {
      'https://ads.test/frame.html',
      'https://ads.test/ad.js',
      'https://cdn.ads.test/creative.jpg',
    });
  });

  test('a pending or failed fresh load passes through', () {
    final p = inspection(browser: page);
    Observed<PageSizeModel> freshOf(PageInspection q) =>
        (derivePageSize(q) as Present<PageSizeModel>).value.fresh;
    expect(freshOf(p.copyWith(freshLoad: const Pending())),
        isA<Pending<PageSizeModel>>());
    expect(freshOf(p.copyWith(freshLoad: const Failed('timeout'))),
        isA<Failed<PageSizeModel>>());
  });
}
