import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/inspection/file_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/screens/home_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/reader_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/source_viewer.dart';

import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/pump.dart';

/// Records the scheduler phase each tab call happened in.
class SpyService extends HtmlService {
  final consumePhases = <SchedulerPhase>[];
  final activePhases = <SchedulerPhase>[];

  SpyService(InspectionStore store)
      : super(
          store: store,
          serverFetcher: SilentServerFetcher(),
          browserLoader: SilentBrowserLoader(),
          metadataExtractor: (html, baseUrl, {headers}) async => {},
        );

  @override
  void consumeTabSwitchRequest() {
    consumePhases.add(SchedulerBinding.instance.schedulerPhase);
    super.consumeTabSwitchRequest();
  }

  @override
  void setActiveTabIndex(int index) {
    activePhases.add(SchedulerBinding.instance.schedulerPhase);
    super.setActiveTabIndex(index);
  }
}

Future<void> pumpHome(WidgetTester tester, HtmlService service) async {
  final settings = AppSettings()..useBrowserByDefault = false;
  service.setAppSettings(settings);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<HtmlService>.value(value: service),
      ChangeNotifierProvider<ReaderService>.value(
          value: ReaderService(service)),
      ChangeNotifierProvider<AppSettings>.value(value: settings),
    ],
    child: const MaterialApp(home: HomeScreen()),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('home screen', () {
    Future<SpyService> localHome(WidgetTester tester) async {
      final service = SpyService(InspectionStore());
      addTearDown(service.dispose);
      // JSON: only the Source tab (the metadata tabs have their own tests).
      const jsonText = '{"a": 1}';
      final f = FileSnapshot(
          name: 'data.json',
          path: '/tmp/data.json',
          origin: FileOrigin.picker,
          bytes: jsonText.codeUnits,
          text: decoded(jsonText),
          lastModified: const Unavailable(UnavailableReason.notApplicable));
      await tester.runAsync(() => service.loadFile(
          HtmlFile(
              name: f.name,
              path: f.path,
              content: jsonText,
              lastModified: DateTime(2024),
              size: jsonText.length),
          snapshot: f));
      await pumpHome(tester, service);
      return service;
    }

    testWidgets('a loading-progress tick does not rebuild the tab bodies',
        (tester) async {
      final service = await localHome(tester);
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 200))); // let the load finish
      await tester.pump(const Duration(milliseconds: 300));
      final before = HomeScreen.structureBuilds;
      for (final p in [0.2, 0.6, 1.0]) {
        service.updateWebViewLoadingProgress(p);
        await tester.pump();
      }
      expect(HomeScreen.structureBuilds, before);
      expect(find.byType(SourceViewer), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Reader tab appears for HTML pages, before DOM Tree',
        (tester) async {
      final service = makeService(seedStore(InspectionStore(), fullPage()));
      addTearDown(service.dispose);
      await pumpHome(tester, service);

      expect(find.text('Reader'), findsOneWidget);
      expect(find.text('DOM Tree'), findsOneWidget);
      final readerX = tester.getTopLeft(find.text('Reader')).dx;
      final domX = tester.getTopLeft(find.text('DOM Tree')).dx;
      expect(readerX, lessThan(domX));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no Reader tab for non-HTML content', (tester) async {
      await localHome(tester);
      expect(find.text('Reader'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tab switch request is consumed outside build', (tester) async {
      final service = await localHome(tester);
      service.consumePhases.clear();
      service.activePhases.clear();

      service.revealSourceLine(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(service.consumePhases, isNotEmpty);
      expect(service.consumePhases,
          everyElement(isNot(SchedulerPhase.persistentCallbacks)));
      expect(service.activePhases,
          everyElement(isNot(SchedulerPhase.persistentCallbacks)));
      expect(service.requestedTabIndex, isNull);
      expect(tester.takeException(), isNull);
      expect(service.activeTabIndex, service.sourceTabIndex);

      // Unmount so the editor's cursor timer ends with the test.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
