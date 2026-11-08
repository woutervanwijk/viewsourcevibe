import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/page_size.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/page_size_view.dart';

import '../derive/fixtures.dart' show inspection, browserSnap, res, b;
import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

void main() {
  group('derivePageSize reasons and media flag', () {
    PageSizeModel model(List<ResourceEntry> r) =>
        (derivePageSize(inspection(browser: browserSnap(resources: r)))
                as Present<PageSizeModel>)
            .value;

    test('the note is the reason itself, not a guess', () {
      Unavailable<int> u(UnavailableReason r, [String d = '']) =>
          Unavailable<int>(r, d);
      final m = model([
        res('https://a.test/1.js', tx: u(UnavailableReason.blockedByPlatform)),
        res('https://a.test/2.js', tx: u(UnavailableReason.notExposedToPage)),
        res('https://a.test/3.js', tx: u(UnavailableReason.blockedBySite)),
        res('https://a.test/4.js',
            tx: u(UnavailableReason.blockedByPlatform,
                'cross-origin without Timing-Allow-Origin')),
      ]);
      String note(String n) =>
          m.rows.singleWhere((r) => r.url.endsWith(n)).sizeNote!;
      expect(note('1.js'), 'blocked by the platform');
      expect(note('2.js'), 'not exposed to the page');
      expect(note('3.js'), 'blocked by the site');
      expect(note('4.js'), contains('cross-origin'));
      expect(m.missingNote, isNot(contains('cross-origin, ')));
    });

    test('isAudioVideo is set by the deriver', () {
      final m = model([
        res('https://a.test/v.mp4', type: 'video', tx: b(10), dec: b(10)),
        res('https://a.test/p.png', type: 'img', tx: b(10), dec: b(10)),
      ]);
      expect(m.rows.singleWhere((r) => r.url.endsWith('.mp4')).isAudioVideo,
          isTrue);
      expect(m.rows.singleWhere((r) => r.url.endsWith('.png')).isAudioVideo,
          isFalse);
    });
  });

  group('derivePageSize', () {
    test('the full page: totals and rows equal the fixture', () {
      final m = (derivePageSize(fullPage()) as Present<PageSizeModel>).value;
      expect(m.weight.isPartial, isFalse);
      expect(m.rows.map((r) => r.url),
          ['https://example.com/app.js', 'https://example.com/app.css']);
      expect(m.rows.first.size, 12000);
      expect(m.rows.first.sizeLabel, '12 KB (↓ 4 KB)');
      expect(m.missingNote, isNull);
    });

    test('iOS: unknown sizes are counted and explained, never 0', () {
      final m = (derivePageSize(iosPartial()) as Present<PageSizeModel>).value;
      expect(m.weight.isPartial, isTrue);
      expect(m.weight.totalPrefix, '≥ ');
      expect(m.rowsWithoutSize, 1);
      expect(m.missingNote, contains('1 resource without size'));
      expect(m.missingNote, contains('cross-origin'));
      expect(m.missingNote, contains('iOS'));
      final unknown =
          m.rows.singleWhere((r) => r.url == 'https://cdn.other.net/lib.js');
      expect(unknown.size, isNull);
      expect(unknown.sizeLabel, startsWith('size unknown ('));
      // The image uses its transfer size; the decoded size is never used.
      final img = m.rows.singleWhere((r) => r.url.endsWith('pic.png'));
      expect(img.size, 5000);
      expect(img.sizeLabel, '5 KB');
      // A script with a transfer size only is still sized.
      final own = m.rows.singleWhere((r) => r.url.endsWith('own.js'));
      expect(own.size, 2048);
    });

    test('sizeless rows sort last', () {
      final m = (derivePageSize(iosPartial()) as Present<PageSizeModel>).value;
      expect(m.rows.last.size, isNull);
    });

    test('states: pending, unavailable, failed browser', () {
      final p = fullPage();
      expect(derivePageSize(p.copyWith(browser: const Pending())),
          isA<Pending<PageSizeModel>>());
      expect(derivePageSize(localFile()), isA<Unavailable<PageSizeModel>>());
      expect(derivePageSize(p.copyWith(browser: const Failed('boom'))),
          isA<Failed<PageSizeModel>>());
    });

    test('formatSizePair never prints 0 for unknown', () {
      expect(formatSizePair(), isNull);
      expect(formatSizePair(transfer: 2048), '↓ 2 KB');
      expect(formatSizePair(decoded: 2048, transfer: 2048), '2 KB');
    });
  });

  group('PageSizeView', () {
    late HtmlService service;

    Future<void> show(WidgetTester tester, PageInspection p) async {
      service = makeService(seedStore(InspectionStore(), p));
      addTearDown(service.dispose);
      await pumpWithProviders(tester,
          service: service, child: const PageSizeView());
      await tester.pump();
    }

    testWidgets('(a) values equal the fixture', (tester) async {
      await show(tester, fullPage());
      expect(find.text('Total Page Size'), findsOneWidget);
      expect(find.text('app.js'), findsOneWidget);
      expect(find.text('12 KB (↓ 4 KB)'), findsWidgets);
      expect(find.textContaining('≥'), findsNothing);
    });

    testWidgets('(b) iOS: lower bound, explained, no 0 KB', (tester) async {
      await show(tester, iosPartial());
      expect(find.textContaining('≥ '), findsWidgets);
      expect(find.textContaining('1 resource without size'), findsOneWidget);
      expect(find.textContaining('size unknown'), findsWidgets);
      expect(find.textContaining('0 KB'), findsNothing);
      expect(find.textContaining('0 B'), findsNothing);
      expect(find.textContaining('size n/a'), findsNothing);
    });

    testWidgets('(c) local file: says it is not available', (tester) async {
      await show(tester, localFile());
      expect(
          find.textContaining('not available for local files'), findsOneWidget);
      expect(find.text('Total Page Size'), findsNothing);
    });

    testWidgets('(c) a file after a URL shows nothing of the URL',
        (tester) async {
      final store = seedStore(InspectionStore(), fullPage());
      service = makeService(store);
      addTearDown(service.dispose);
      await pumpWithProviders(tester,
          service: service, child: const PageSizeView());
      await tester.pump();
      expect(find.text('app.js'), findsOneWidget);
      store.beginFile((localFile().target as FileTarget).file);
      await tester.pump();
      expect(find.text('app.js'), findsNothing);
      expect(
          find.textContaining('not available for local files'), findsOneWidget);
    });

    testWidgets('(d) a loading-progress tick does not rebuild', (tester) async {
      await show(tester, fullPage());
      final before = PageSizeView.builds;
      service.updateWebViewLoadingProgress(0.4);
      await tester.pump();
      service.updateWebViewLoadingProgress(0.8);
      await tester.pump();
      expect(PageSizeView.builds, before);
    });

    testWidgets('(e) pending and failed are distinct texts', (tester) async {
      await show(tester, fullPage().copyWith(browser: const Pending()));
      expect(find.text('Waiting for the browser…'), findsOneWidget);
      await show(
          tester, fullPage().copyWith(browser: const Failed('payload broke')));
      expect(find.textContaining('payload broke'), findsOneWidget);
      expect(find.textContaining('No Page Size'), findsNothing);
    });

    testWidgets('resources not reported: says so, not an empty list',
        (tester) async {
      final p = fullPage();
      final b = (p.browser as Present<BrowserSnapshot>).value;
      await show(
          tester,
          p.copyWith(
              browser: browser(BrowserSnapshot(
                  url: b.url,
                  platform: b.platform,
                  contentType: b.contentType,
                  renderedDom: b.renderedDom,
                  resources: const Unavailable(
                      UnavailableReason.notReportedByPlatform, 'no entries'),
                  cookies: b.cookies,
                  storage: b.storage,
                  navigation: b.navigation,
                  snapshotTimeMs: b.snapshotTimeMs))));
      expect(
          find.textContaining('Not reported by the platform'), findsOneWidget);
      expect(find.text('Total Page Size'), findsNothing);
    });
  });
}
