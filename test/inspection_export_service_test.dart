import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/derive/network_quiet.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/inspection_export_service.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_layout.dart';
import 'fixtures/inspection/builders.dart' as fx;

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
        ),
      );

      final bytes = InspectionExportService().buildPackageBytes(htmlService);
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((file) => file.name).toSet();

      expect(names, contains('manifest.json'));
      expect(names, contains('report.html'));
      // No browser snapshot was taken: the DOM file is not written (it
      // used to hold the loaded text under the DOM's name).
      expect(names, isNot(contains('source/browser-dom.html')));
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
        browserPoll: NetworkQuietPolicy.off,
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
          archive.findFile('network/timeline.json')!.readBytes()!)) as Map;
      final row = (timeline['value'] as List).single as Map;
      expect(row['transfer']['status'], 'unavailable');
      expect(row['transfer'].containsKey('value'), isFalse);
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
        browserPoll: NetworkQuietPolicy.off,
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
        browserPoll: NetworkQuietPolicy.off,
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

    test('the export has the structure', () {
      final store = InspectionStore();
      final gen = store.beginUrl(Uri.parse('https://example.com/'));
      store.applyLayout(
          gen,
          const Present(
              PageLayout(
                  viewportWidth: 400,
                  viewportHeight: 800,
                  width: 400,
                  height: 1200,
                  totalBlocks: 2,
                  blocks: [
                    LayoutBlock(
                        tag: 'header',
                        role: '',
                        id: 'top',
                        classes: 'bar',
                        src: '',
                        text: '',
                        x: 0,
                        y: 0,
                        width: 400,
                        height: 80,
                        depth: 1,
                        descendants: 4,
                        kind: LayoutKind.landmark,
                        fixed: false),
                    LayoutBlock(
                        tag: 'h1',
                        role: '',
                        id: '',
                        classes: '',
                        src: '',
                        text: 'Hello',
                        x: 0,
                        y: 100,
                        width: 400,
                        height: 30,
                        depth: 2,
                        descendants: 0,
                        kind: LayoutKind.heading,
                        fixed: false),
                  ]),
              source: DataSource.browser));
      final htmlService = HtmlService(store: store);
      addTearDown(htmlService.dispose);
      final archive = ZipDecoder().decodeBytes(
          InspectionExportService().buildPackageBytes(htmlService));
      final json = jsonDecode(utf8.decode(
              archive.findFile('analysis/structure.json')!.readBytes()!))
          as Map<String, dynamic>;
      expect(json['status'], 'present');
      final v = json['value'] as Map<String, dynamic>;
      expect(v['page'], {'w': 400.0, 'h': 1200.0});
      expect(v['totalBlocks'], 2);
      expect((v['blocks'] as List).first['tag'], 'header');
      expect((v['blocks'] as List).first['owner'], 'page');
      expect(v['headings'], [
        {'level': 1, 'text': 'Hello'}
      ]);
    });

    group('source/diff.patch', () {
      Map<String, dynamic> manifestAndFiles(
          String? serverText, String? domText, Set<String> names) {
        final store = InspectionStore();
        final gen = store.beginUrl(Uri.parse('https://example.com/'));
        if (serverText != null) {
          store.applyServer(
              gen,
              fx.server(fx.serverSnapshot(
                  url: 'https://example.com/',
                  hops: [fx.hop('https://example.com/', 200)],
                  body: serverText)));
        }
        if (domText != null) {
          store.applyBrowser(gen,
              fx.browserSnapshot(url: 'https://example.com/', dom: domText));
        }
        final htmlService = HtmlService(store: store);
        addTearDown(htmlService.dispose);
        final archive = ZipDecoder().decodeBytes(
            InspectionExportService().buildPackageBytes(htmlService));
        names.addAll(archive.files.map((f) => f.name));
        return jsonDecode(
                utf8.decode(archive.findFile('manifest.json')!.readBytes()!))
            as Map<String, dynamic>;
      }

      test('a real diff is written and the manifest says present', () {
        final names = <String>{};
        final m = manifestAndFiles('a\nb\nc\n', 'a\nX\nb\nc\n', names);
        expect(names, contains('source/diff.patch'));
        expect(m['diff'], {'status': 'present'});
      });

      test('too many changed lines: no file, manifest says why', () {
        final names = <String>{};
        final a = List.generate(3000, (i) => 'a$i').join('\n');
        final b = List.generate(3000, (i) => 'b$i').join('\n');
        final m = manifestAndFiles(a, b, names);
        expect(names, isNot(contains('source/diff.patch')));
        expect(m['diff'], {
          'status': 'unavailable',
          'reason': 'exceedsLimit',
          'detail': 'more than 2000 changed lines',
        });
      });

      test('without both sources the diff is not applicable', () {
        final names = <String>{};
        final m = manifestAndFiles('a\n', null, names);
        expect(names, isNot(contains('source/diff.patch')));
        expect(m['diff'], {
          'status': 'unavailable',
          'reason': 'notApplicable',
          'detail': 'no server source and browser DOM to compare',
        });
      });
    });
  });
}
