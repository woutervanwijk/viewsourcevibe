import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/page_weight.dart';

import 'fixtures.dart';

void main() {
  test('total equals the sum of the breakdown', () {
    final w = derivePageWeight(inspection(
        browser: browserSnap(resources: [
      res('https://a.test/a.js', tx: b(100), dec: b(300)),
      res('https://a.test/s.css', type: 'link', tx: b(50), dec: b(80)),
      res('https://a.test/i.png', type: 'img', tx: b(1000), dec: b(1000)),
    ])))!;
    expect(w.transfer, 1150);
    expect(w.decoded, 1380);
    expect(w.breakdown.values.fold<int>(0, (a, x) => a + (x.transfer ?? 0)),
        w.transfer);
    expect(w.breakdown.values.fold<int>(0, (a, x) => a + (x.decoded ?? 0)),
        w.decoded);
    expect(w.transferLowerBound, isFalse);
    expect(w.decodedLowerBound, isFalse);
    expect(w.provenance, Provenance.measured);
    expect(w.transferPrefix, '');
    expect(w.decodedPrefix, '');
  });

  test('iOS images count with transfer, never the pixel buffer', () {
    final w = derivePageWeight(inspection(
        browser: browserSnap(platform: BrowserPlatform.ios, resources: [
      res('https://a.test/i.png', type: 'img', tx: b(2000), dec: b(4000000)),
    ])))!;
    expect(w.transfer, 2000);
    expect(w.decoded, isNull);
    expect(w.transferLowerBound, isFalse);
    expect(w.decodedLowerBound, isFalse);
  });

  test('missing values make the total estimated and a lower bound', () {
    final w = derivePageWeight(inspection(
        browser: browserSnap(resources: [
      res('https://a.test/a.js', tx: b(100), dec: b(300)),
      res('https://cdn.test/b.js'), // blocked: no sizes
    ])))!;
    expect(w.transfer, 100);
    expect(w.transferLowerBound, isTrue);
    expect(w.decodedLowerBound, isTrue);
    expect(w.provenance, Provenance.estimated);
    expect(w.transferPrefix, '≥ ');
    expect(w.decodedPrefix, '≥ ');
  });

  test('server document is added and labelled', () {
    final w = derivePageWeight(inspection(
        server: serverSnap(body: 'x' * 500),
        browser: browserSnap(resources: [
          res('https://a.test/a.js', tx: b(100), dec: b(300)),
        ])))!;
    expect(w.documentSource, DataSource.server);
    expect(w.transfer, 600);
  });

  test('null without browser resources', () {
    expect(derivePageWeight(inspection(browser: browserSnap(resources: null))),
        isNull);
    expect(derivePageWeight(inspection()), isNull);
  });
}
