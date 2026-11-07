import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/inspection_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InspectionExportService', () {
    test('builds a portable inspection zip with report and data files',
        () async {
      final htmlService = HtmlService();
      await htmlService.loadFile(
        HtmlFile(
          name: 'example.html',
          path: 'https://example.com',
          content:
              '<!doctype html><html><head><title>Example</title></head><body>Hello</body></html>',
          lastModified: DateTime.utc(2026, 4, 29),
          size: 82,
          isUrl: true,
          probeResult: {
            'url': 'https://example.com',
            'statusCode': 200,
            'headers': {'content-type': 'text/html'},
            'security': {'X-Content-Type-Options': 'nosniff'},
            'analyzedCookies': [],
          },
        ),
      );

      final bytes = InspectionExportService().buildPackageBytes(htmlService);
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((file) => file.name).toSet();

      expect(names, contains('manifest.json'));
      expect(names, contains('report.html'));
      expect(names, contains('source/browser-dom.html'));
      expect(names, contains('network/headers.json'));
      expect(names, contains('analysis/security-scorecard.json'));

      final manifest = jsonDecode(
        utf8.decode(archive.findFile('manifest.json')!.readBytes()!),
      ) as Map<String, dynamic>;
      expect(manifest['format'], 'view-source-vibe-inspection-package');
      expect(manifest['source']['path'], 'https://example.com');

      final report = utf8.decode(archive.findFile('report.html')!.readBytes()!);
      for (final section in [
        'Metadata',
        'Probe',
        'Services',
        'Cookies',
        'Headers',
        'Security',
        'Timeline',
        'Raw Metadata JSON',
        'Raw Probe JSON',
      ]) {
        expect(report, contains(section));
      }
    });

    test(
        'adds the raw browser payload as debug/browser-payload.json and '
        'prints unknown sizes as unknown', () async {
      const raw = '{"v":1,"url":"https://example.com/","dom":{"ok":true,'
          '"value":"<html></html>","iframes":0,"shadowRoots":0},'
          '"resources":{"ok":true,"bootstrap":true,"dropped":0,"observer":['
          '{"n":"https://cdn.test/x.js","it":"script","st":1,"du":2,'
          '"tx":0,"enc":0,"dec":0}],"patch":[]}}';
      final store = InspectionStore();
      final htmlService = HtmlService(
        store: store,
        browserPlatform: BrowserPlatform.macos,
        browserCollect: (url) async => raw,
        nativeCookies: (url) async => [],
        browserRefreshDelays: const [],
      );
      addTearDown(htmlService.dispose);
      await htmlService.loadUrl('https://example.com/', skipWebViewLoad: true);
      await htmlService.syncWebViewState('https://example.com/');

      final archive = ZipDecoder().decodeBytes(
          InspectionExportService().buildPackageBytes(htmlService));
      final payload = jsonDecode(utf8.decode(
          archive.findFile('debug/browser-payload.json')!.readBytes()!));
      expect(payload['url'], 'https://example.com/');

      final timeline = jsonDecode(utf8.decode(
          archive.findFile('network/timeline.json')!.readBytes()!)) as List;
      expect(timeline.single['transfer'], isNull);
      final report = utf8.decode(archive.findFile('report.html')!.readBytes()!);
      expect(report, contains('unknown'));
    });

    test('no debug payload without a browser sync', () async {
      final htmlService = HtmlService();
      addTearDown(htmlService.dispose);
      await htmlService.loadFile(HtmlFile(
          name: 'a.html',
          path: '/tmp/a.html',
          content: '<p>x</p>',
          lastModified: DateTime.utc(2026),
          size: 8));
      final archive = ZipDecoder().decodeBytes(
          InspectionExportService().buildPackageBytes(htmlService));
      expect(archive.findFile('debug/browser-payload.json'), isNull);
    });

    test('R22: the debug payload redacts cookie and storage values', () async {
      const raw = '{"v":1,"url":"https://example.com/","dom":{"ok":true,'
          '"value":"<html></html>","iframes":0,"shadowRoots":0},'
          '"storage":{"local":{"ok":true,"count":1,"items":'
          '[{"k":"authToken","v":"SECRET-STORAGE-é"}],"truncated":false},'
          '"session":{"ok":true,"count":0,"items":[],"truncated":false}},'
          '"cookies":{"ok":true,"raw":"sid=SECRET-COOKIE; theme=dark"}}';
      final htmlService = HtmlService(
        store: InspectionStore(),
        browserPlatform: BrowserPlatform.macos,
        browserCollect: (url) async => raw,
        nativeCookies: (url) async => [],
        browserRefreshDelays: const [],
      );
      addTearDown(htmlService.dispose);
      await htmlService.loadUrl('https://example.com/', skipWebViewLoad: true);
      await htmlService.syncWebViewState('https://example.com/');
      final archive = ZipDecoder().decodeBytes(
          InspectionExportService().buildPackageBytes(htmlService));
      final text = utf8
          .decode(archive.findFile('debug/browser-payload.json')!.readBytes()!);
      expect(text, isNot(contains('SECRET')));
      expect(text, isNot(contains('dark')));
      expect(text, contains('authToken'));
      expect(text, contains('sid'));
      expect(text, contains('theme'));
      final j = jsonDecode(text) as Map;
      final item = j['storage']['local']['items'].single as Map;
      expect(item['bytes'], utf8.encode('SECRET-STORAGE-é').length);
      final cookies = j['cookies']['redacted'] as List;
      expect(cookies.first['bytes'], 'SECRET-COOKIE'.length);
    });

    test('R22: an unparsable payload keeps only its length', () async {
      final htmlService = HtmlService(
        store: InspectionStore(),
        browserPlatform: BrowserPlatform.macos,
        browserCollect: (url) async => 'password=hunter2 {broken',
        nativeCookies: (url) async => [],
        browserRefreshDelays: const [],
      );
      addTearDown(htmlService.dispose);
      await htmlService.loadUrl('https://example.com/', skipWebViewLoad: true);
      await htmlService.syncWebViewState('https://example.com/');
      final archive = ZipDecoder().decodeBytes(
          InspectionExportService().buildPackageBytes(htmlService));
      final text = utf8
          .decode(archive.findFile('debug/browser-payload.json')!.readBytes()!);
      expect(text, isNot(contains('hunter2')));
      expect(text, contains('24'));
    });
  });
}
