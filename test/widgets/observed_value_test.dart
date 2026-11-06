import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/widgets/observed_value.dart';

Widget host(Observed<int> v) => MaterialApp(
      home: Scaffold(
        body: ObservedValue<int>(value: v, format: (n) => '$n KB'),
      ),
    );

void main() {
  testWidgets('Present renders formatted value and a source badge',
      (tester) async {
    await tester.pumpWidget(host(const Present(42, source: DataSource.browser)));
    expect(find.text('42 KB'), findsOneWidget);
    expect(find.text('browser'), findsOneWidget);

    await tester.pumpWidget(host(const Present(1, source: DataSource.server)));
    expect(find.text('server'), findsOneWidget);
    await tester.pumpWidget(host(const Present(1, source: DataSource.file)));
    expect(find.text('file'), findsOneWidget);
  });

  testWidgets('estimated provenance gets the approx prefix', (tester) async {
    await tester.pumpWidget(host(const Present(7,
        source: DataSource.server, provenance: Provenance.estimated)));
    expect(find.textContaining('≈'), findsOneWidget);
    expect(find.textContaining('7 KB'), findsOneWidget);
  });

  testWidgets('measured has no approx prefix', (tester) async {
    await tester.pumpWidget(host(const Present(7, source: DataSource.server)));
    expect(find.textContaining('≈'), findsNothing);
  });

  testWidgets('Unavailable shows reason detail and never 0', (tester) async {
    await tester.pumpWidget(host(const Unavailable(
        UnavailableReason.blockedByPlatform,
        'cross-origin without Timing-Allow-Origin')));
    expect(find.textContaining('Not visible:'), findsOneWidget);
    expect(find.textContaining('cross-origin without Timing-Allow-Origin'),
        findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.textContaining('0 KB'), findsNothing);
  });

  testWidgets('Pending shows an indicator', (tester) async {
    await tester.pumpWidget(host(const Pending()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Failed shows the error message', (tester) async {
    await tester.pumpWidget(host(const Failed('connection reset')));
    expect(find.textContaining('connection reset'), findsOneWidget);
  });
}
