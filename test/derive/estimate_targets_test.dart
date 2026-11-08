import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/estimate_targets.dart';

import '../fixtures/inspection/ios_partial.dart';
import 'fixtures.dart';

void main() {
  group('isEstimableResourceType', () {
    test('static resources are safe to request again', () {
      for (final t in [
        'script',
        'link',
        'css',
        'font',
        'img',
        'image',
        'video',
        'audio',
        'media',
        'IMG',
      ]) {
        expect(isEstimableResourceType(t, 'https://a.test/x.bin'), isTrue,
            reason: t);
      }
    });

    test('requests that may have side effects never are', () {
      for (final t in [
        'xmlhttprequest',
        'xhr',
        'fetch',
        'beacon',
        'ping',
        'iframe',
        'frame',
        'navigation',
        'other',
        '',
        'something-new',
      ]) {
        expect(isEstimableResourceType(t, 'https://a.test/x.js'), isFalse,
            reason: t);
      }
    });

    test('only http(s) URLs; a linked page is not a static resource', () {
      expect(
          isEstimableResourceType('script', 'data:text/javascript,1'), isFalse);
      expect(isEstimableResourceType('img', 'blob:https://a.test/1'), isFalse);
      expect(isEstimableResourceType('img', 'ftp://a.test/x.png'), isFalse);
      expect(
          isEstimableResourceType('link', 'https://a.test/next.html'), isFalse);
      expect(isEstimableResourceType('link', 'https://a.test/s.css'), isTrue);
      expect(
          isEstimableResourceType('LINK', 'https://a.test/next.html'), isFalse);
    });
  });

  group('estimateTargets', () {
    test('the iOS fixture: unsized static resources, once each', () {
      expect(estimateTargets(iosPartial()), ['https://cdn.other.net/lib.js']);
    });

    test('a cache hit without encoded size is looked up too', () {
      final p = inspection(
          browser: browserSnap(resources: [
        res('https://a.test/c.js',
            tx: const Unavailable(UnavailableReason.servedFromCache),
            dec: b(900)),
        res('https://a.test/d.js'),
      ]));
      expect(
          estimateTargets(p), ['https://a.test/c.js', 'https://a.test/d.js']);
    });

    test('measured, duplicate and already estimated URLs are skipped', () {
      final p = inspection(
          browser: browserSnap(resources: [
        res('https://a.test/m.js', tx: b(10)),
        res('https://a.test/u.js'),
        res('https://a.test/u.js'),
        res('https://a.test/e.js'),
        res('https://a.test/f.js'),
      ])).copyWith(resourceEstimates: {
        'https://a.test/e.js': Present(5,
            source: DataSource.server, provenance: Provenance.estimated),
        'https://a.test/f.js': const Failed('no'),
      });
      expect(estimateTargets(p), ['https://a.test/u.js']);
    });

    test('types and schemes are filtered', () {
      final p = inspection(
          browser: browserSnap(resources: [
        res('https://a.test/a.js', type: 'xmlhttprequest'),
        res('https://a.test/b', type: 'fetch'),
        res('https://a.test/c', type: 'beacon'),
        res('https://a.test/d', type: 'iframe'),
        res('https://a.test/e', type: 'other'),
        res('data:image/png;base64,AAAA', type: 'img'),
        res('https://a.test/f.woff2', type: 'css'),
        res('https://a.test/g.png', type: 'img'),
        res('https://a.test/h.mp4', type: 'video'),
      ]));
      expect(estimateTargets(p), [
        'https://a.test/f.woff2',
        'https://a.test/g.png',
        'https://a.test/h.mp4',
      ]);
    });

    test('limit caps the list; nothing without Present resources', () {
      final p = inspection(
          browser: browserSnap(resources: [
        for (var i = 0; i < 10; i++) res('https://a.test/$i.js'),
      ]));
      expect(estimateTargets(p, limit: 3), hasLength(3));
      expect(estimateTargets(p, limit: 0), isEmpty);
      expect(estimateTargets(inspection(browser: browserSnap(resources: null))),
          isEmpty);
      expect(estimateTargets(inspection()), isEmpty);
    });
  });
}
