import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/technique_signals.dart';
import 'package:view_source_vibe/services/cname_cloaking_service.dart';
import 'package:view_source_vibe/services/collectors/fresh_load_measurer.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/privacy_view.dart';

import '../derive/fixtures.dart' as fx;
import '../fixtures/inspection/pump.dart';
import '../fixtures/inspection/trackers.dart';

void main() {
  late InspectionStore store;
  late HtmlService service;

  Future<void> show(WidgetTester tester, PageInspection p,
      {Observed<TechniqueSignals>? techniques,
      FreshLoadMeasurer? freshLoadMeasurer}) async {
    store = seedStore(InspectionStore(), p);
    if (techniques != null) {
      store.applyFreshLoad(store.current.generation,
          Present(fx.browserSnap(), source: DataSource.browser),
          techniques: techniques);
    }
    service = HtmlService(
      store: store,
      serverFetcher: SilentServerFetcher(),
      browserLoader: SilentBrowserLoader(),
      metadataExtractor: (html, baseUrl, {headers}) async => {},
      freshLoadMeasurer: freshLoadMeasurer,
      cloakingFinder: (hosts, {required pageHost, required lookup}) async =>
          const CloakingResult(),
    );
    addTearDown(service.dispose);
    // The metadata the page's own checks (SRI) run on.
    await tester.runAsync(() => service.loadFile(htmlFileFor(p, content: 'x')));
    await pumpWithProviders(tester,
        service: service, child: const PrivacyView());
    await tester.pumpAndSettle();
  }

  testWidgets('the section offers the fresh load when it has not run',
      (tester) async {
    await show(tester, trackerPage());
    expect(find.text('Techniques'), findsOneWidget);
    expect(find.text('Run a fresh load to check'), findsOneWidget);
    expect(find.text('Run fresh load'), findsOneWidget);
    expect(find.textContaining('No suspicious techniques'), findsNothing);
  });

  testWidgets('a platform without a fresh load says so from the start',
      (tester) async {
    await show(tester, trackerPage(), freshLoadMeasurer: const NoFreshLoad());
    expect(find.text('Not supported on this platform'), findsOneWidget);
    expect(find.text('Run fresh load'), findsNothing);
  });

  testWidgets('unsupported platform: says so, no button', (tester) async {
    await show(tester, trackerPage(),
        techniques: const Unavailable(UnavailableReason.unsupportedPlatform,
            'Not supported on this platform'));
    expect(find.text('Not supported on this platform'), findsOneWidget);
    expect(find.text('Run fresh load'), findsNothing);
    // The data-derived trackers still show.
    expect(find.text('Meta Pixel'), findsOneWidget);
  });

  testWidgets('no findings after all checks ran', (tester) async {
    await show(tester, trackerPage(),
        techniques:
            Present(const TechniqueSignals(), source: DataSource.browser));
    expect(find.text('No suspicious techniques seen by the checks that ran.'),
        findsOneWidget);
    expect(find.text('Run fresh load'), findsNothing);
  });

  testWidgets('a finding is shown with its title and hosts', (tester) async {
    await show(tester, trackerPage(),
        techniques: Present(const TechniqueSignals(clipboardRead: 1),
            source: DataSource.browser));
    expect(find.text('Reads the clipboard'), findsOneWidget);
    expect(find.textContaining('No suspicious techniques'), findsNothing);
  });

  testWidgets('the cloaking check runs while the section shows',
      (tester) async {
    var calls = 0;
    store = seedStore(InspectionStore(), trackerPage());
    service = HtmlService(
      store: store,
      serverFetcher: SilentServerFetcher(),
      browserLoader: SilentBrowserLoader(),
      metadataExtractor: (html, baseUrl, {headers}) async => {},
      cloakingFinder: (hosts, {required pageHost, required lookup}) async {
        calls++;
        return const CloakingResult();
      },
    );
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const PrivacyView());
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
