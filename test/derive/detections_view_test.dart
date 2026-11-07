import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/detections_view.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';

import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

void main() {
  group('describeCheckedSources', () {
    test('full page: server and browser sources were read', () {
      final s = describeCheckedSources(fullPage());
      expect(s.checked, contains('server HTML and headers'));
      expect(s.checked, containsAll(['browser DOM', 'browser requests']));
      expect(s.notChecked, isEmpty);
      expect(s.waiting, isFalse);
    });

    test('local file: says which sources are not available for local files',
        () {
      final s = describeCheckedSources(localFile());
      expect(s.checked, ['file source']);
      expect(s.line, contains('Checked: file source'));
      expect(
          s.line, contains('browser requests not available for local files'));
    });

    test('pending browser: waiting only when a browser will report', () {
      final p = fullPage().copyWith(browser: const Pending());
      expect(describeCheckedSources(p).waiting, isTrue);
      final no = describeCheckedSources(p, browserReachable: false);
      expect(no.waiting, isFalse);
      expect(no.line, contains('no browser is active'));
    });

    test('nothing readable is said, not "checked: nothing"', () {
      final p = fullPage().copyWith(
          server: const Failed('timeout'), browser: const Failed('crashed'));
      final s = describeCheckedSources(p);
      expect(s.anythingChecked, isFalse);
      expect(s.line, startsWith('Nothing could be checked'));
      expect(s.line, contains('timeout'));
    });
  });

  group('HtmlService.detectionsView', () {
    test('a completed scan with findings is complete', () {
      final service = makeService(seedStore(InspectionStore(), fullPage()));
      addTearDown(service.dispose);
      final v = service.detectionsView;
      expect(v.scanning, isFalse);
      expect(v.failure, isNull);
      expect(v.complete, isTrue);
      expect(identical(v, service.detectionsView), isTrue);
    });

    test('a failing scan is a failure, not "none found"', () async {
      final service = HtmlService(
        store: seedStore(InspectionStore(), fullPage()),
        serverFetcher: SilentServerFetcher(),
        browserLoader: SilentBrowserLoader(),
        metadataExtractor: (h, b, {headers}) async => {},
        detectionScanner: (t) async => throw StateError('scan broke'),
      );
      addTearDown(service.dispose);
      expect(service.detectionsView.scanning, isTrue);
      expect(service.detectionsView.complete, isFalse);
      await Future<void>.delayed(Duration.zero);
      final v = service.detectionsView;
      expect(v.scanning, isFalse);
      expect(v.failure, contains('scan broke'));
      expect(v.complete, isFalse);
      expect(service.detectionsError, contains('scan broke'));
    });

    test('a running scan is pending, then complete', () async {
      final c = Completer<List<Map<String, dynamic>>>();
      final service = HtmlService(
        store: seedStore(InspectionStore(), fullPage()),
        serverFetcher: SilentServerFetcher(),
        browserLoader: SilentBrowserLoader(),
        metadataExtractor: (h, b, {headers}) async => {},
        detectionScanner: (t) => c.future,
      );
      addTearDown(service.dispose);
      expect(service.detectionsView.scanning, isTrue);
      c.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(service.detectionsView.scanning, isFalse);
      expect(service.detectionsView.complete, isTrue);
    });
  });
}
