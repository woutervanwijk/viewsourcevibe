import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_layout.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';

import 'html_service_lifecycle_test.dart' show FakeBrowserLoader;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HtmlService make(InspectionStore store, Future<Object?> Function(String) c) =>
      HtmlService(
        store: store,
        browserLoader: FakeBrowserLoader(),
        layoutCollect: c,
        metadataExtractor: (html, baseUrl, {headers}) async => {},
      );

  test('collectLayout stores the parsed layout', () async {
    final store = InspectionStore()..beginUrl(Uri.parse('https://a.test/'));
    final s = make(
        store,
        (u) async =>
            '{"v":1,"vw":1,"vh":1,"w":10,"h":20,"total":0,"blocks":'
            '[{"k":"frame","x":0,"y":0,"w":5,"h":5}]}');
    await s.collectLayout();
    expect(store.current.layout, isA<Present<PageLayout>>());
    s.dispose();
  });

  test('a throwing evaluation becomes Failed', () async {
    final store = InspectionStore()..beginUrl(Uri.parse('https://a.test/'));
    final s = make(store, (u) async => throw StateError('boom'));
    await s.collectLayout();
    expect(store.current.layout, isA<Failed<PageLayout>>());
    s.dispose();
  });

  test('without a browser the layout needs the browser', () async {
    final store = InspectionStore()..beginUrl(Uri.parse('https://a.test/'));
    final s = HtmlService(
        store: store,
        browserLoader: FakeBrowserLoader(),
        metadataExtractor: (html, baseUrl, {headers}) async => {});
    await s.collectLayout();
    final l = store.current.layout as Unavailable<PageLayout>;
    expect(l.detail, 'needs the browser');
    s.dispose();
  });

  test('a result after navigating on is dropped', () async {
    final store = InspectionStore()..beginUrl(Uri.parse('https://a.test/'));
    final s = make(store, (u) async {
      store.beginUrl(Uri.parse('https://b.test/'));
      return '{"v":1,"empty":true}';
    });
    await s.collectLayout();
    expect((store.current.layout as Unavailable<PageLayout>).detail,
        'not measured yet');
    s.dispose();
  });
}
