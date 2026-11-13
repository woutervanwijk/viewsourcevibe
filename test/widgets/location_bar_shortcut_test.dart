import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
  // the widget tree) settles.
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
  // Let the tab animation settle and the page-focus callback run (the new
  // page can take a few frames to build, so pump repeatedly).
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Ctrl+L and Cmd+L focus the location bar', (tester) async {
    final service = makeService(seedStore(InspectionStore(), fullPage()));
    addTearDown(service.dispose);
    await pumpApp(tester, service);

    final fieldFinder = find.byType(TextField);
    TextField field() => tester.widget<TextField>(fieldFinder);
    expect(fieldFinder, findsOneWidget);
    expect(field().focusNode!.hasFocus, isFalse);

    // Ctrl+L (Windows/Linux): the location bar gets focus, text selected.
    await pressKey(tester, LogicalKeyboardKey.keyL, control: true);
    expect(field().focusNode!.hasFocus, isTrue);
    expect(field().controller!.selection.baseOffset, 0);
    expect(field().controller!.selection.extentOffset,
        field().controller!.text.length);

    // Cmd+L (macOS) works the same way.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(field().focusNode!.hasFocus, isFalse);
    await pressKey(tester, LogicalKeyboardKey.keyL, meta: true);
    expect(field().focusNode!.hasFocus, isTrue);

    // Plain L does not steal focus.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await pressKey(tester, LogicalKeyboardKey.keyL);
    expect(field().focusNode!.hasFocus, isFalse);
  });

  testWidgets('Ctrl/Cmd+arrows move through the tabs, even with the '
      'location bar focused', (tester) async {
    final service = makeService(seedStore(InspectionStore(), fullPage()));
    addTearDown(service.dispose);
    await pumpApp(tester, service);

    final state = homeScreenKey.currentState!;
    final initial = state.currentTabIndex;

    // Ctrl+Right (Windows/Linux) goes to the next tab.
    await pressKey(tester, LogicalKeyboardKey.arrowRight, control: true);
    expect(state.currentTabIndex, isNot(initial));

    // Ctrl+Left goes back.
    await pressKey(tester, LogicalKeyboardKey.arrowLeft, control: true);
    expect(state.currentTabIndex, initial);

    // Cmd+arrows (macOS) work the same, and win over the focused location
    // bar: after Ctrl+L the field has focus, Cmd+Right still switches tabs.
    // The newly selected tab's page then takes keyboard focus (so the page
    // scrolls with the keyboard), so the location bar loses it.
    await pressKey(tester, LogicalKeyboardKey.keyL, control: true);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    await pressKey(tester, LogicalKeyboardKey.arrowRight, meta: true);
    await tester.pump();
    expect(state.currentTabIndex, isNot(initial));
    expect(field.focusNode!.hasFocus, isFalse);
    expect(state.activeTabFocusNode?.hasFocus, isTrue);
  });

  testWidgets('the mouse wheel scrolls the tab strip horizontally',
      (tester) async {
    final service = makeService(seedStore(InspectionStore(), fullPage()));
    addTearDown(service.dispose);
    // Narrow window, so the chips of a group overflow and the strip scrolls.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, service);

    final state = homeScreenKey.currentState!;
    final strip = find.byKey(const ValueKey('tab-chip-strip'));
    expect(strip, findsOneWidget);
    expect(state.tabStripOffset, 0);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final center = tester.getCenter(strip);
    await tester.sendEventToBinding(pointer.hover(center));
    // Wheel "down" reports a positive dy; the strip is horizontal, so it
    // must scroll right (this was a no-op on macOS/Windows before).
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 240)));
    await tester.pump();
    expect(state.tabStripOffset, greaterThan(0));

    // Wheel back up scrolls left again.
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -240)));
    await tester.pump();
    expect(state.tabStripOffset, 0);
  });
}
