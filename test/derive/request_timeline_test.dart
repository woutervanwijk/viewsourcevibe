import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/request_timeline.dart';

import '../fixtures/inspection/builders.dart' as fx;
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/local_file.dart';
import 'fixtures.dart' show res, b, inspection, browserSnap;

TimelineModel timeline(PageInspection p) =>
    (deriveTimeline(p) as Present<TimelineModel>).value;

List<TimelineRow> rows(PageInspection p) =>
    (timeline(p).rows as Present<List<TimelineRow>>).value;

ResourceEntry timed(String url, double start, double dur,
        {String type = 'script', int? tx, int? dec}) =>
    ResourceEntry(
      url: url,
      type: type,
      source: ResourceSource.observer,
      startTime: b(start),
      duration: b(dur),
      transfer: tx == null
          ? const Unavailable(UnavailableReason.blockedByPlatform)
          : b(tx),
      decoded: dec == null
          ? const Unavailable(UnavailableReason.blockedByPlatform)
          : b(dec),
    );

void main() {
  group('states', () {
    test('local file and nothing loaded say what they are', () {
      expect((deriveTimeline(localFile()) as Unavailable).detail,
          contains('local file'));
      expect(
          (deriveTimeline(const PageInspection.empty()) as Unavailable).detail,
          'Load a URL to view the request timeline.');
    });

    test('browser pending: resources pending, redirects already there', () {
      final t = timeline(fullPage().copyWith(browser: const Pending()));
      expect(t.rows, isA<Pending<List<TimelineRow>>>());
      expect(t.redirects, hasLength(2));
      expect(t.resourcesLabel, startsWith('unknown ('));
    });

    test('browser failed keeps the error', () {
      final t =
          timeline(fullPage().copyWith(browser: const Failed('payload broke')));
      expect((t.rows as Failed).error, 'payload broke');
    });

    test('server pending: no status, no redirects, never 0', () {
      final t = timeline(fullPage().copyWith(server: const Pending()));
      expect(t.appStatus, startsWith('App request: unknown ('));
      expect(t.redirects, isEmpty);
      expect(t.rows, isA<Present<List<TimelineRow>>>());
    });

    test('resources unavailable: says why, not an empty list', () {
      final p = inspection(browser: browserSnap(resources: null));
      final t = timeline(p);
      expect(t.rows, isA<Unavailable<List<TimelineRow>>>());
    });
  });

  group('rows', () {
    test('full page: values equal the fixture', () {
      final r = rows(fullPage());
      expect(r.map((x) => x.shortName), ['app.js', 'app.css']);
      expect(r.first.start, 10.0);
      expect(r.first.duration, 20.0);
      expect(r.first.hasBar, isTrue);
      expect(r.first.timingLabel, '10ms / 20ms');
      expect(r.first.sizeLabel, '12 KB (↓ 4 KB)');
      expect(r.first.type, 'script');
      final t = timeline(fullPage());
      expect(t.appStatus, 'App request: 200 OK');
      expect(t.url, 'https://example.com/');
      expect(t.resourcesLabel, '2 resources');
      expect(t.timelineEnd, 30.0);
    });

    test('a resource without start or duration has no bar and says so', () {
      final p = inspection(
          browser: browserSnap(resources: [
        timed('https://a.test/a.js', 100, 50, tx: 10, dec: 20),
        res('https://a.test/b.js', tx: b(5), dec: b(6)),
      ]));
      final t = timeline(p);
      final r = (t.rows as Present<List<TimelineRow>>).value;
      expect(r.map((x) => x.shortName), ['a.js', 'b.js']);
      expect(r.last.hasBar, isFalse);
      expect(r.last.start, isNull);
      expect(r.last.timingLabel, startsWith('timing unknown ('));
      expect(r.last.timingLabel, isNot(contains('0ms')));
      expect(t.rowsWithoutTiming, 1);
      expect(t.timelineEnd, 150.0);
      expect(t.note, contains('1 resource has no timing'));
    });

    test('rows without timing come after those with timing', () {
      final p = inspection(
          browser: browserSnap(resources: [
        res('https://a.test/first.js'),
        timed('https://a.test/late.js', 500, 5),
        timed('https://a.test/early.js', 1, 5),
      ]));
      expect(
          rows(p).map((x) => x.shortName), ['early.js', 'late.js', 'first.js']);
    });

    test('unknown sizes are "size unknown (reason)", images use the transfer',
        () {
      final r = rows(iosPartial());
      final unknown = r.singleWhere((x) => x.url.contains('cdn.other.net'));
      expect(unknown.sizeLabel, startsWith('size unknown ('));
      final img = r.singleWhere((x) => x.url.endsWith('pic.png'));
      expect(img.sizeLabel, '5 KB');
      for (final x in r) {
        expect(x.sizeLabel, isNot(contains('0 KB')));
      }
    });
  });

  group('totals', () {
    test('ios: the total is a lower bound', () {
      final t = timeline(iosPartial());
      expect(t.transferLabel, startsWith('≥ '));
    });

    test('nothing reported a size: unknown, not 0', () {
      final p = inspection(
          browser: browserSnap(resources: [res('https://a.test/a.js')]));
      expect(timeline(p).transferLabel, 'Size unknown');
    });

    test('no resources at all with a Present list is genuinely none', () {
      final p = inspection(browser: browserSnap(resources: const []));
      final t = timeline(p);
      expect(t.resourcesLabel, '0 resources');
      expect((t.rows as Present<List<TimelineRow>>).value, isEmpty);
    });

    test('a truncated buffer is said', () {
      final p = inspection(
          browser: browserSnap(
              resources: [timed('https://a.test/a.js', 1, 2, tx: 1, dec: 1)],
              truncated: true));
      expect(timeline(p).note, contains('not collected'));
    });
  });

  group('redirect chain from the server hops', () {
    test('steps with status text', () {
      final t = timeline(fullPage());
      expect(t.redirects.map((r) => r.statusText), ['301 Moved', '302 Moved']);
      expect(fx.server<int>(1), isNotNull);
    });
  });

  test('resourceTypeOf', () {
    expect(resourceTypeOf('https://a.test/x.js?v=1'), 'script');
    expect(resourceTypeOf('https://a.test/x.css'), 'style');
    expect(resourceTypeOf('https://a.test/x.woff2'), 'font');
    expect(resourceTypeOf('https://a.test/api/users'), 'fetch');
    expect(resourceTypeOf('https://a.test/x.html'), 'document');
    expect(resourceTypeOf('https://a.test/x'), 'other');
  });
}
