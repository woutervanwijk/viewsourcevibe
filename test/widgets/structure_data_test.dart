import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/page_layout.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/structure_view.dart';

import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

LayoutBlock _block(String tag, LayoutKind kind,
        {String id = '',
        String src = '',
        String text = '',
        double x = 0,
        double y = 0,
        double w = 1000,
        double h = 100}) =>
    LayoutBlock(
        tag: tag,
        role: '',
        id: id,
        classes: '',
        src: src,
        text: text,
        x: x,
        y: y,
        width: w,
        height: h,
        depth: 1,
        descendants: 3,
        kind: kind,
        fixed: false);

PageInspection pageWithLayout() => fullPage().copyWith(
        layout: Present(
      PageLayout(
          viewportWidth: 1000,
          viewportHeight: 800,
          width: 1000,
          height: 2000,
          totalBlocks: 4,
          blocks: [
            _block('header', LayoutKind.landmark, id: 'top'),
            _block('h1', LayoutKind.heading,
                text: 'Welcome to the shop', y: 120, h: 40),
            _block('main', LayoutKind.landmark, y: 200, h: 500),
            _block('iframe', LayoutKind.frame,
                src: 'https://ads.doubleclick.net/x',
                x: 200,
                y: 800,
                w: 600,
                h: 400),
          ]),
      source: DataSource.browser,
    ));

void main() {
  late HtmlService service;

  Future<void> show(WidgetTester tester, PageInspection p) async {
    final store = seedStore(InspectionStore(), p);
    // seedStore does not carry the layout.
    store.applyLayout(store.current.generation, p.layout);
    service = makeService(store);
    addTearDown(service.dispose);
    await pumpWithProviders(tester,
        service: service, child: const StructureView());
    await tester.pump();
  }

  Offset wireframeOrigin(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const Key('structure-wireframe')));

  testWidgets('the tab draws the wireframe and the outline', (tester) async {
    await show(tester, pageWithLayout());
    expect(find.byKey(const Key('structure-wireframe')), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Welcome to the shop'), findsOneWidget);
    expect(find.textContaining('Third-party frames cover'), findsOneWidget);
  });

  testWidgets('a tap on a block opens its details', (tester) async {
    await show(tester, pageWithLayout());
    await tester.tapAt(wireframeOrigin(tester) + const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.textContaining('header#top'), findsOneWidget);
    expect(find.textContaining('1000 × 100 px'), findsOneWidget);
  });

  testWidgets('the sheet opens the DOM tree at the tapped element',
      (tester) async {
    await show(tester, pageWithLayout());
    await tester.tapAt(wireframeOrigin(tester) + const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Open in DOM tree'), findsOneWidget);
    expect(find.text('Open in source'), findsOneWidget);
    await tester.tap(find.text('Open in DOM tree'));
    await tester.pumpAndSettle();
    expect(service.pendingDomReveal?.id, 'top');
    expect(service.pendingDomReveal?.tag, 'header');
    expect(service.requestedTabIndex, HtmlService.domTreeTab);
  });

  testWidgets('the sheet opens the source view at the tapped element',
      (tester) async {
    await show(tester, pageWithLayout());
    await tester.tapAt(wireframeOrigin(tester) + const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open in source'));
    await tester.pumpAndSettle();
    expect(service.requestedTabIndex, HtmlService.sourceTab);
  });

  testWidgets('without a browser the tab says why', (tester) async {
    await show(tester, localFile());
    expect(find.textContaining('only for pages loaded in the browser'),
        findsOneWidget);
    expect(find.byKey(const Key('structure-wireframe')), findsNothing);
  });

  testWidgets('a measuring page shows progress', (tester) async {
    await show(tester, fullPage().copyWith(layout: const Pending()));
    expect(find.text('Measuring the page…'), findsOneWidget);
  });

  testWidgets('a page still loading says it waits', (tester) async {
    await show(tester,
        fullPage().copyWith(layout: const Pending('waiting for the page to settle')));
    expect(find.text('waiting for the page to settle'), findsOneWidget);
  });
}
