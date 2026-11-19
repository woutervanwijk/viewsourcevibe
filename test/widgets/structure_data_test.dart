import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/page_layout.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/widgets/dom_tree_view.dart';
import 'package:view_source_vibe/widgets/structure_painter.dart';
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
    expect(find.text('header#top'), findsOneWidget);
    expect(find.textContaining('1000 × 100 px'), findsOneWidget);
  });

  testWidgets('the sheet shows a DOM tree of only the tapped element',
      (tester) async {
    final p = pageWithLayout().copyWith(
        layout: Present(
      PageLayout(
          viewportWidth: 1000,
          viewportHeight: 800,
          width: 1000,
          height: 2000,
          totalBlocks: 1,
          blocks: [
            _block('div', LayoutKind.block, id: 'app', w: 1000, h: 500),
          ]),
      source: DataSource.browser,
    ));
    await show(tester, p);
    await tester.tapAt(wireframeOrigin(tester) + const Offset(20, 20));
    await tester.pumpAndSettle();
    // The sheet is large and embeds the element's subtree, root expanded.
    expect(find.text('DOM of div#app'), findsOneWidget);
    expect(find.byType(DomSubtreeView), findsOneWidget);
    expect(find.textContaining('RENDERED-DOM'), findsOneWidget);
    // The subtree fills the rest of the sheet down to its bottom edge
    // (no fixed height anymore).
    final treeBottom = tester.getBottomLeft(find.byType(DomSubtreeView)).dy;
    final contentBottom = tester
        .getBottomLeft(find.descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(SafeArea)))
        .dy;
    expect(contentBottom - treeBottom, lessThan(24)); // 16 padding + border
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

  // A valid 1x1 PNG, so the test engine can decode it.
  const List<int> pngBytes = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
    0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54,
    0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
    0x0D, 0x0A, 0x2D, 0xB4,
    0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ];

  StructurePainter wireframePainter(WidgetTester tester) =>
      tester
          .widget<CustomPaint>(find.byKey(const Key('structure-wireframe')))
          .painter as StructurePainter;

  Future<void> showWithShots(
      WidgetTester tester, PageInspection p, Observed<Uint8List> live) async {
    final store = seedStore(InspectionStore(), p);
    store.applyLayout(store.current.generation, p.layout);
    store.applyLiveScreenshot(store.current.generation, live);
    service = makeService(store);
    addTearDown(service.dispose);
    await pumpWithProviders(tester, service: service, child: const StructureView());
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the top screenshot shows at once and the full-page shot '
      'replaces it when ready', (tester) async {
    final live = Present<Uint8List>(Uint8List.fromList(pngBytes),
        source: DataSource.browser);
    await showWithShots(tester, pageWithLayout(), live);

    // The top-of-page shot is selected behind the wireframe, not full-page.
    // (The test engine does not decode images, so only the selection and
    // the full-page flag are observable here.)
    expect(wireframePainter(tester).backgroundFullPage, isFalse);

    // The scroll-through capture finishes: the larger screenshot replaces it.
    service.debugSetFullPageScreenshot(Present<Uint8List>(
        Uint8List.fromList(pngBytes),
        source: DataSource.browser));
    await tester.pump();
    await tester.pump();
    expect(wireframePainter(tester).backgroundFullPage, isTrue);
  });

  testWidgets('while the wireframe is still measuring, the top screenshot '
      'already shows behind the progress', (tester) async {
    final live = Present<Uint8List>(Uint8List.fromList(pngBytes),
        source: DataSource.browser);
    await showWithShots(
        tester, fullPage().copyWith(layout: const Pending()), live);
    expect(find.byKey(const Key('structure-wireframe')), findsNothing);
    expect(find.text('Measuring the page…'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
