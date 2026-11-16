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

  NavigationTiming nav({Observed<int>? tx, Observed<int>? dec}) =>
      NavigationTiming(
        timeToFirstByte: b(1.0),
        domInteractive: b(2.0),
        domContentLoaded: b(3.0),
        loadEvent: b(4.0),
        protocol: b('h2'),
        documentTransfer:
            tx ?? const Unavailable(UnavailableReason.notReportedByPlatform),
        documentDecoded:
            dec ?? const Unavailable(UnavailableReason.notReportedByPlatform),
      );

  test('the document is sized by the browser when it reports it', () {
    final w = derivePageWeight(inspection(
        server: serverSnap(body: 'x' * 9999),
        browser: browserSnap(
            navigation: nav(tx: b(5300), dec: b(20000)), resources: [])))!;
    expect(w.breakdown['html']!.transfer, 5300);
    expect(w.breakdown['html']!.decoded, 20000);
    expect(w.documentSource, DataSource.browser);
    expect(w.transferEstimated, isFalse);
  });

  test('without browser sizes the server body counts as an estimate', () {
    final w = derivePageWeight(inspection(
        server: serverSnap(body: 'x' * 9999),
        browser: browserSnap(navigation: nav(), resources: [])))!;
    expect(w.breakdown['html']!.transfer, 9999);
    expect(w.estimatedTransfer, 9999);
    expect(w.transferEstimated, isTrue);
    expect(w.documentSource, DataSource.server);
  });

  test('null without browser resources', () {
    expect(derivePageWeight(inspection(browser: browserSnap(resources: null))),
        isNull);
    expect(derivePageWeight(inspection()), isNull);
  });

  test('an XHR is not a stylesheet because its URL says lifestyle', () {
    expect(
        resourceCategory(
            res('https://a.test/lifestyle/api', type: 'xmlhttprequest'),
            'https://a.test/'),
        'other');
    expect(
        resourceCategory(res('https://a.test/subscriptions', type: 'fetch'),
            'https://a.test/'),
        'other');
    expect(
        resourceCategory(
            res('https://a.test', type: 'fetch'), 'https://a.test/'),
        'document');
  });

  test('fonts and media have their own kind', () {
    expect(resourceCategory(res('https://a.test/f.woff2', type: 'css'), ''),
        'font');
    expect(resourceCategory(res('https://a.test/v.mp4', type: 'video'), ''),
        'media');
    expect(resourceCategory(res('https://a.test/v.mp4', type: 'fetch'), ''),
        'media');
  });

  test('a link without an extension is a stylesheet', () {
    expect(
        resourceCategory(
            res('https://fonts.googleapis.com/css2?family=Inter', type: 'link'),
            ''),
        'style');
  });

  test('the breakdown has fonts and media buckets', () {
    final w = derivePageWeight(inspection(
        browser: browserSnap(resources: [
      res('https://a.test/f.woff2', type: 'css', tx: b(100)),
      res('https://a.test/v.mp4', type: 'video', tx: b(900)),
    ])))!;
    expect(w.breakdown['fonts']!.transfer, 100);
    expect(w.breakdown['media']!.transfer, 900);
    expect(w.breakdown['images']!.count, 0);
    expect(w.breakdown.keys.toSet(), {
      'scripts',
      'css',
      'images',
      'media',
      'fonts',
      'html',
      'other',
      'thirdPartyFrames'
    });
  });
}
