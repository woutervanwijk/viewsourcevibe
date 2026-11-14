import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/main.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/screens/home_screen.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';

import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/pump.dart';

Future<void> pumpApp(WidgetTester tester, HtmlService service) async {
  final settings = AppSettings()..useBrowserByDefault = false;
  service.setAppSettings(settings);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<HtmlService>.value(value: service),
      ChangeNotifierProvider<AppSettings>.value(value: settings),
    ],
    child: const MyApp(),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  // Load after the first frame so the tab structure (and TabController in
  // the widget tree) settles, then let the tab switch request land.
  await tester.runAsync(() => service.loadFile(htmlFileFor(fullPage())));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> pressKey(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool meta = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  // Let the tab animation settle and the focus callback run (the new page
  // can take a few frames to build, so pump repeatedly).
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('switching tabs with the keyboard focuses the new page',
      (tester) async {
    final service = makeService(seedStore(InspectionStore(), fullPage()));
    addTearDown(service.dispose);
    await pumpApp(tester, service);

    final state = homeScreenKey.currentState!;
    final initial = state.currentTabIndex;
    final initialNode = state.activeTabFocusNode;
    expect(initialNode, isNotNull);
    expect(initialNode!.hasFocus, isFalse);

    // Ctrl+Right selects the next tab; its page gets keyboard focus so the
    // keyboard scrolls it without tapping the page first.
    await pressKey(tester, LogicalKeyboardKey.arrowRight, control: true);
    expect(state.currentTabIndex, isNot(initial));
    final node = state.activeTabFocusNode;
    expect(node, isNotNull);
    expect(node, isNot(initialNode));
    expect(node!.hasFocus, isTrue);
    expect(FocusManager.instance.primaryFocus, node);

    // Ctrl+Left goes back; focus follows the selection again.
    await pressKey(tester, LogicalKeyboardKey.arrowLeft, control: true);
    expect(state.currentTabIndex, initial);
    expect(state.activeTabFocusNode, initialNode);
    expect(initialNode.hasFocus, isTrue);
  });

  testWidgets('tapping a tab focuses its page', (tester) async {
    final service = makeService(seedStore(InspectionStore(), fullPage()));
    addTearDown(service.dispose);
    await pumpApp(tester, service);

    final state = homeScreenKey.currentState!;
    final initial = state.currentTabIndex;
    expect(state.activeTabFocusNode?.hasFocus, isFalse);

    // Tap another tab's chip. The body tap handler unfocuses on tap, but
    // once the tab animation settles the page focus must win.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Media'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(state.currentTabIndex, isNot(initial));
    final node = state.activeTabFocusNode;
    expect(node, isNotNull);
    expect(node!.hasFocus, isTrue);
    expect(FocusManager.instance.primaryFocus, node);
  });
}
