import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/batch_runner.dart';
import 'package:view_source_vibe/widgets/batch_banner.dart';

import '../support/fake_batch_target.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('batch_banner_test'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> pumpBanner(WidgetTester tester, BatchRunner runner) =>
      tester.pumpWidget(ChangeNotifierProvider<BatchRunner>.value(
          value: runner,
          child: const MaterialApp(home: Scaffold(body: BatchBanner()))));

  BatchRunner newRunner(FakeBatchTarget t) => BatchRunner(t,
      poll: const Duration(milliseconds: 1),
      settle: Duration.zero,
      lateWait: Duration.zero,
      workDir: () async => tmp);

  testWidgets('nothing shows before a batch', (tester) async {
    await pumpBanner(tester, newRunner(FakeBatchTarget()));
    expect(find.textContaining('Batch'), findsNothing);
  });

  testWidgets('the banner shows progress and cancels', (tester) async {
    final t = FakeBatchTarget()..pendingFor['b.test'] = -1;
    final runner = newRunner(t);
    await pumpBanner(tester, runner);
    await tester.runAsync(() async {
      final done = runner.run([
        Uri.parse('https://a.test/'),
        Uri.parse('https://b.test/'),
        Uri.parse('https://c.test/'),
      ],
          options: const BatchOptions(
              timeout: Duration(seconds: 30), linger: Duration.zero));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.textContaining('Batch 2/3'), findsOneWidget);
      expect(find.textContaining('b.test'), findsOneWidget);
      expect(find.text('Batch 2/3 · b.test · waiting for sovereignty'),
          findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await done;
      await tester.pump();
    });
    expect(runner.running, isFalse);
    expect(find.textContaining('Batch done: 1 site(s)'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.textContaining('Batch'), findsNothing);
  });

  testWidgets('a run that failed says so and can be dismissed', (tester) async {
    final runner = BatchRunner(FakeBatchTarget(),
        workDir: () async => throw StateError('no disk'));
    await pumpBanner(tester, runner);
    await tester.runAsync(() => runner.run([Uri.parse('https://a.test/')]));
    await tester.pump();
    expect(find.text('Batch failed: Bad state: no disk'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(runner.error, isNull);
    expect(find.textContaining('Batch'), findsNothing);
  });
}
