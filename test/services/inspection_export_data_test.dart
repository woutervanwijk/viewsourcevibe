import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/inspection_export_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/observed_json.dart';

import '../derive/fixtures.dart'
    show inspection, serverSnap, browserSnap, cookie;
import '../fixtures/inspection/bot_blocked.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/local_file.dart';
import '../fixtures/inspection/pump.dart';

void main() {
  group('observedJson', () {
    test('the four states', () {
      expect(
          observedPlain(const Present(3, source: DataSource.server),
              source: DataSource.browser),
          {
            'status': 'present',
            'value': 3,
            'source': 'server',
            'provenance': 'measured'
          });
      expect(
          observedPlain<int>(
              const Unavailable(
                  UnavailableReason.blockedByPlatform, 'x-origin'),
              source: DataSource.browser),
          {
            'status': 'unavailable',
            'reason': 'blockedByPlatform',
            'detail': 'x-origin',
            'source': 'browser',
            'provenance': 'measured'
          });
      expect(
          observedPlain<int>(const Pending(),
              source: DataSource.server)['status'],
          'pending');
      final failed =
          observedPlain<int>(const Failed('boom'), source: DataSource.server);
      expect(failed['status'], 'failed');
      expect(failed['detail'], 'boom');
      expect(failed.containsKey('value'), isFalse);
    });
  });

  group('export package (store based)', () {
    Archive export(PageInspection p) {
      final service = makeService(seedStore(InspectionStore(), p));
      addTearDown(service.dispose);
      return ZipDecoder()
          .decodeBytes(InspectionExportService().buildPackageBytes(service));
    }

    String text(Archive a, String name) =>
        utf8.decode(a.findFile(name)!.readBytes()!);
    dynamic json(Archive a, String name) => jsonDecode(text(a, name));

    final secretServer = inspection(
      server: serverSnap(headers: {
        'content-type': ['text/html'],
        // The real fetcher keeps Set-Cookie in the headers as well.
        'set-cookie': [
          'sid=SERVER-SECRET; Path=/; Secure; HttpOnly; SameSite=Lax'
        ],
      }, setCookies: [
        'sid=SERVER-SECRET; Path=/; Secure; HttpOnly; SameSite=Lax'
      ]),
      browser: browserSnap(cookies: [cookie('tok', value: 'BROWSER-SECRET')]),
    );

    test('R22: no cookie value in any data file or the report', () {
      final a = export(secretServer);
      for (final f in a.files.where((f) => f.isFile)) {
        if (f.name.startsWith('source/')) continue;
        expect(utf8.decode(f.readBytes()!, allowMalformed: true),
            isNot(contains('SECRET')),
            reason: f.name);
      }
      final cookies = json(a, 'network/cookies.json');
      expect(cookies['status'], 'present');
      final rows = cookies['value']['cookies'] as List;
      final sid = rows.firstWhere((c) => c['name'] == 'sid');
      expect(sid['valueBytes'], 'SERVER-SECRET'.length);
      expect(sid['secure'], 'yes');
      expect(sid.containsKey('value'), isFalse);
      // The raw Set-Cookie header keeps name and attributes, not the value.
      final headers = json(a, 'network/headers.json');
      final sc = headers['value']['hops'].single['headers']['set-cookie'];
      expect(sc.single, startsWith('sid=<redacted, 13 bytes>; Path=/'));
    });

    test('an unknown value is unavailable with its reason, never 0', () {
      final a = export(iosPartial());
      final timeline = json(a, 'network/timeline.json');
      expect(timeline['status'], 'present');
      final lib = (timeline['value'] as List)
          .firstWhere((r) => r['url'].toString().contains('cdn.other.net'));
      expect(lib['transfer']['status'], 'unavailable');
      expect(lib['transfer']['reason'], 'blockedByPlatform');
      expect(lib['transfer'].containsKey('value'), isFalse);
      final own = (timeline['value'] as List)
          .firstWhere((r) => r['url'].toString().endsWith('own.js'));
      expect(own['transfer']['value'], 2048);
      final weight = json(a, 'analysis/page-weight.json');
      expect(weight['value']['transferLowerBound'], isTrue);
      expect(weight['value']['transferEstimated'], isFalse);
      expect(weight['value']['decodedLowerBound'], isTrue);
      expect(weight['value'].containsKey('isPartial'), isFalse);
    });

    test('pending and failed cores are written as such', () {
      final a = export(fullPage().copyWith(server: const Pending()));
      expect(json(a, 'network/probe.json')['status'], 'pending');
      expect(json(a, 'network/headers.json')['status'], 'pending');
      expect(
          json(a, 'analysis/security-scorecard.json')['value']['audit']
              ['status'],
          'pending');
      final b = export(
          fullPage().copyWith(server: const Failed('network error: boom')));
      final probe = json(b, 'network/probe.json');
      expect(probe['status'], 'failed');
      expect(probe['detail'], 'network error: boom');
      final c = export(fullPage().copyWith(browser: const Pending()));
      expect(json(c, 'network/browser-probe.json')['status'], 'pending');
      expect(json(c, 'network/timeline.json')['status'], 'pending');
    });

    test('a local file: lastModified is unavailable, size is the byte length',
        () {
      final a = export(localFile());
      final m = json(a, 'manifest.json')['source'];
      expect(m['kind'], 'file');
      expect(m['lastModified']['status'], 'unavailable');
      expect(m['size']['value'], 123);
      expect(json(a, 'network/probe.json')['status'], 'unavailable');
      expect(a.findFile('source/browser-dom.html'), isNull);
      expect(a.findFile('source/local-file.txt'), isNotNull);
    });

    test('a URL: size from the server body, Last-Modified when sent', () {
      final a = export(fullPage());
      final m = json(a, 'manifest.json')['source'];
      expect(m['kind'], 'url');
      expect(m['size']['value'], fullPageServerHtml.length);
      expect(m['lastModified']['status'], 'unavailable');
      expect(m['lastModified']['reason'], 'notReportedByServer');
    });

    test('full page: files and values equal the fixture', () {
      final a = export(fullPage());
      expect(a.findFile('source/server.html'), isNotNull);
      expect(a.findFile('source/browser-dom.html'), isNotNull);
      expect(a.findFile('source/diff.patch'), isNotNull);
      final probe = json(a, 'network/probe.json')['value'];
      expect((probe['hops'] as List).length, 3);
      expect(probe['userAgent'], contains('ViewSourceVibe'));
      expect(probe['finalUrl']['value'], 'https://example.com/');
      final robots = json(a, 'analysis/robots-sitemap.json');
      expect(robots['value']['disallow'], '1 disallow');
      final redirects = json(a, 'network/redirects.json');
      expect((redirects['value']['steps'] as List).length, 2);
    });

    test('bot blocked: the 403 is in the app request, not the browser file',
        () {
      final a = export(botBlocked());
      final probe = json(a, 'network/probe.json')['value'];
      expect(probe['hops'].single['statusCode'], 403);
      expect(text(a, 'network/browser-probe.json'), isNot(contains('403')));
    });

    test('the report never prints N/A or null for unknowns', () {
      for (final p in [
        iosPartial(),
        fullPage().copyWith(server: const Pending()),
        localFile()
      ]) {
        final report = text(export(p), 'report.html');
        expect(report, isNot(contains('N/A')));
        expect(report, isNot(contains('>null<')));
        expect(report, contains('Timeline'));
        expect(report, contains('Cookies'));
      }
    });

    test('sovereignty is exported as its state, not as an empty map', () {
      final a = export(fullPage());
      expect(json(a, 'analysis/sovereignty.json')['status'], 'pending');
    });
  });
}
