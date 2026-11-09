import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/page_size_view.dart';

import '../derive/fixtures.dart' show browserSnap, res;
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/pump.dart';

Present<int> bt(int v) => Present(v, source: DataSource.browser);

void main() {
  Future<InspectionStore> show(
      WidgetTester tester, Observed<BrowserSnapshot> fresh) async {
    final store = seedStore(InspectionStore(), fullPage());
    store.applyFreshLoad(store.current.generation, fresh);
    final service = makeService(store);
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const PageSizeView());
    await tester.pump();
    return store;
  }

  testWidgets('pending: says it is measuring', (tester) async {
    await show(tester, const Pending());
    expect(find.textContaining('measuring…'), findsOneWidget);
    expect(find.text('Measure'), findsNothing);
  });

  testWidgets('failed: the error and a retry, never a size', (tester) async {
    await show(tester, const Failed('Fresh load failed: timeout'));
    expect(find.textContaining('timeout'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('0 KB'), findsNothing);
  });

  testWidgets('unsupported platform is said, no button', (tester) async {
    await show(
        tester,
        const Unavailable(UnavailableReason.unsupportedPlatform,
            'not available on this platform'));
    expect(find.text('not available on this platform'), findsOneWidget);
    expect(find.text('Measure'), findsNothing);
  });

  testWidgets(
      'measured: both totals, the verdict on the fresh load, its files '
      'with third-party iframes labelled; tap switches', (tester) async {
    await show(
        tester,
        Present(
            browserSnap(url: 'https://example.com/', resources: [
              res('https://example.com/app.js', tx: bt(4096)),
              res('https://ads.test/ad.js',
                  tx: bt(50 * 1024), frameOrigin: 'https://ads.test'),
            ]),
            source: DataSource.browser));
    expect(find.text('This load'), findsOneWidget);
    expect(find.textContaining('Lighthouse (fresh load)'), findsOneWidget);
    expect(find.text('Third-party iframes (ads, embeds) (1)'), findsOneWidget);
    expect(find.textContaining('third-party iframe'), findsWidgets);
    expect(find.textContaining('Files below: fresh load'), findsOneWidget);

    await tester.tap(find.text('This load'));
    await tester.pump();
    expect(find.textContaining('Files below: this load'), findsOneWidget);
    expect(find.text('Third-party iframes (ads, embeds) (1)'), findsNothing);
  });
}
