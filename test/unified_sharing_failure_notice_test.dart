import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

/// A failed incoming share or pending-content check is shown to the user
/// (HtmlService.fileNotice, under the URL bar), never only logged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('info.wouter.sourceviewer/shared_content');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(Future<Object?>? Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, handler);

  late HtmlService service;

  setUp(() => service = HtmlService());
  tearDown(() {
    mock((_) async => null);
    service.dispose();
  });

  test('a failing pending-content check surfaces a notice', () async {
    mock((call) async => throw PlatformException(code: 'boom', message: 'x'));
    final has = await UnifiedSharingService.hasPendingSharedContent(
        htmlService: service);
    expect(has, isFalse);
    expect(service.fileNotice, isNotNull);
    expect(service.fileNotice, contains('shared content'));
  });

  test('a failing retrieval of pending content surfaces a notice', () async {
    mock((call) async => throw PlatformException(code: 'boom', message: 'x'));
    final handled =
        await UnifiedSharingService.handlePendingSharedContent(service);
    expect(handled, isFalse);
    expect(service.fileNotice, isNotNull);
  });

  test('a platform without the channel is not an error', () async {
    mock((call) async => throw MissingPluginException());
    await UnifiedSharingService.hasPendingSharedContent(htmlService: service);
    await UnifiedSharingService.handlePendingSharedContent(service);
    expect(service.fileNotice, isNull);
  });

  test('no pending content is not an error', () async {
    mock((call) async => call.method == 'hasSharedContent' ? false : null);
    expect(
        await UnifiedSharingService.hasPendingSharedContent(
            htmlService: service),
        isFalse);
    expect(service.fileNotice, isNull);
  });

  testWidgets('a failing initial share check at start-up surfaces a notice',
      (tester) async {
    mock((call) async => throw PlatformException(code: 'boom', message: 'x'));
    late BuildContext ctx;
    await tester.pumpWidget(ChangeNotifierProvider<HtmlService>.value(
      value: service,
      child: MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ),
    ));
    UnifiedSharingService.initialize(ctx);
    await tester.pump();
    expect(service.fileNotice, isNotNull);
  });
}
