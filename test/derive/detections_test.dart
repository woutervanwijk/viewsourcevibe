import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/detections.dart';

import 'fixtures.dart';

void main() {
  test('every evidence item carries a DataSource', () {
    final ds = deriveDetections(inspection(
        server: serverSnap(
            headers: {
              'content-type': ['text/html'],
              'server': ['cloudflare'],
              'cf-ray': ['abc'],
            },
            body:
                '<html><head><script src="https://www.googletagmanager.com/gtm.js?id=GTM-1"></script></head></html>'),
        browser: browserSnap(
            dom:
                '<html><head><script src="https://www.googletagmanager.com/gtm.js?id=GTM-1"></script></head></html>',
            resources: [
              res('https://www.google-analytics.com/g/collect?v=2'),
            ])));
    expect(ds, isNotEmpty);
    for (final d in ds) {
      expect(d.evidence, isNotEmpty);
      expect(d.evidence.every((e) => e.source != null), isTrue, reason: d.name);
    }
    final cf = ds.firstWhere((d) => d.name == 'Cloudflare');
    expect(cf.evidence.first.source, DataSource.server);
    final ga = ds.firstWhere((d) => d.name.contains('Analytics'));
    expect(
        ga.evidence.any(
            (e) => e.source == DataSource.browser && e.kind.name == 'request'),
        isTrue);
  });

  test('a detection found only in the DOM is labelled browser', () {
    final ds = deriveDetections(inspection(
        server: serverSnap(body: '<html><body>plain</body></html>'),
        browser: browserSnap(
            dom:
                '<html><head><script src="https://connect.facebook.net/en_US/fbevents.js"></script></head></html>')));
    final fb = ds.firstWhere(
        (d) => d.name.contains('Facebook') || d.name.contains('Meta'));
    expect(fb.evidence.every((e) => e.source == DataSource.browser), isTrue);
    expect(fb.sources, {DataSource.browser});
  });

  test('a detection in both server source and DOM shows both sources', () {
    final html =
        '<html><head><script src="https://connect.facebook.net/en_US/fbevents.js"></script></head></html>';
    final ds = deriveDetections(inspection(
        server: serverSnap(body: html), browser: browserSnap(dom: html)));
    final fb = ds.firstWhere(
        (d) => d.name.contains('Facebook') || d.name.contains('Meta'));
    expect(fb.sources, {DataSource.server, DataSource.browser});
  });

  test('R4: a file target has no requests or cookies from a previous URL', () {
    final ds = deriveDetections(inspection(
        file: fileSnap(
            '<html><script src="https://www.googletagmanager.com/gtm.js?id=GTM-1"></script></html>')));
    expect(ds, isNotEmpty);
    for (final d in ds) {
      expect(d.requests, 0);
      expect(d.cookies, isEmpty);
      expect(d.evidence.every((e) => e.source == DataSource.file), isTrue);
    }
  });

  test('cookie evidence is tagged by where the cookie was seen', () {
    final ds = deriveDetections(inspection(
        server: serverSnap(setCookies: ['_ga=GA1.2.3; Path=/']),
        browser: browserSnap(cookies: [cookie('_fbp', value: 'fb.1.2')])));
    final ga = ds.firstWhere((d) => d.cookies.contains('_ga'));
    expect(ga.evidence.firstWhere((e) => e.kind.name == 'cookie').source,
        DataSource.server);
    final fbp = ds.firstWhere((d) => d.cookies.contains('_fbp'));
    expect(fbp.evidence.firstWhere((e) => e.kind.name == 'cookie').source,
        DataSource.browser);
  });

  test('split scan + cheap part equals the one-shot derive (I2)', () {
    final p = inspection(
        server: serverSnap(
            setCookies: ['_ga=GA1.2.3'],
            body:
                '<html><script src="https://connect.facebook.net/en_US/fbevents.js"></script></html>'),
        browser: browserSnap(resources: [
          res('https://www.google-analytics.com/g/collect?v=2')
        ]));
    final texts = detectionTextsOf(p);
    final scanned = scanTextsToMaps(texts);
    List<Map<String, dynamic>> maps(List ds) => [for (final d in ds) d.toMap()];
    expect(
        maps(deriveDetections(p, scanned: scanned)), maps(deriveDetections(p)));
    expect(sameDetectionTexts(texts, detectionTextsOf(p)), isTrue);
  });
}
