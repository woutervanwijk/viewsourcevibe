import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/collectors/server_fetcher.dart';
import 'package:view_source_vibe/services/derive/probe_general.dart';

import '../fixtures/inspection/bot_blocked.dart';
import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/ios_partial.dart';
import '../fixtures/inspection/local_file.dart';

GeneralModel general(PageInspection p) =>
    (deriveGeneral(p) as Present<GeneralModel>).value;

T present<T>(Observed<T> o) => (o as Present<T>).value;

void main() {
  group('sniffContentType (moved from the widget)', () {
    test('html wins over inline css/js', () {
      expect(
          sniffContentType('<style>a{b:c}</style><div></div>', null), 'html');
      expect(sniffContentType('<!-- c --><!DOCTYPE html><p>', null), 'html');
    });
    test('json, xml, css, js, text, empty', () {
      expect(sniffContentType('{"a":1}', null), 'json');
      expect(sniffContentType('{not json', null), 'text');
      expect(sniffContentType('<?xml version="1.0"?><a/>', null), 'xml');
      expect(sniffContentType('@media x { a { b: c } }', null), 'css');
      expect(sniffContentType('const a = 1;', null), 'javascript');
      expect(sniffContentType('hello', null), 'text');
      expect(sniffContentType('  \n', null), 'empty');
      expect(sniffContentType('x', 'a.css'), 'css');
    });
  });

  group('deriveGeneral gate', () {
    test('a local file has no server request to show', () {
      final o = deriveGeneral(localFile());
      expect(o, isA<Unavailable<GeneralModel>>());
      expect((o as Unavailable).detail, contains('local file'));
    });
    test('nothing loaded', () {
      final o = deriveGeneral(const PageInspection.empty());
      expect((o as Unavailable).detail, 'Probe a URL to see details');
    });
  });

  group('status card', () {
    test('full page: every hop with status and reason, final URL, socket', () {
      final s = present(general(fullPage()).status);
      expect(s.hops.map((h) => h.text), ['301 Moved', '302 Moved', '200 OK']);
      expect(s.hops.first.location, 'https://example.com/');
      expect(s.redirects.map((r) => (r.statusText, r.from, r.to)), [
        ('301 Moved', 'http://example.com/', 'https://example.com/'),
        ('302 Moved', 'https://example.com/', 'https://example.com/'),
      ]);
      expect(s.finalStatusText, '200 OK');
      expect(present(s.finalUrl).toString(), 'https://example.com/');
      expect(s.contentType, 'text/html; charset=utf-8');
      expect(s.isRedirect, isTrue);
      expect(s.remoteAddressLabel, '93.184.216.34');
      expect(
          s.timingLabel, '42 ms (measured by the app, including DNS and TLS)');
      expect(s.userAgent, kServerUserAgent);
      expect(s.bodyLabel, startsWith('${fullPageServerHtml.length} bytes'));
    });

    test('a reason phrase that is empty gives just the code, never "null"', () {
      final h = HttpHop(
          url: Uri.parse('https://a.test/'),
          statusCode: 204,
          reasonPhrase: '',
          headers: const {},
          setCookies: const [],
          remoteAddress:
              const Unavailable(UnavailableReason.notReportedByPlatform),
          certificate: const Unavailable(UnavailableReason.notApplicable));
      final p = urlInspection(
          url: 'https://a.test/',
          serverResult: server(
              serverSnapshot(url: 'https://a.test/', hops: [h], body: '')),
          browserResult: const Pending());
      final s = present(general(p).status);
      expect(s.hops.single.text, '204');
      expect(s.remoteAddressLabel, startsWith('unknown ('));
      expect(s.contentType, isNull);
    });

    test('bot blocked: the final status is the 403 of the app request', () {
      final s = present(general(botBlocked()).status);
      expect(s.finalStatusText, '403 Forbidden');
      expect(s.isRedirect, isFalse);
    });

    test('pending and failed servers', () {
      final pend = urlInspection(
          url: 'https://a.test/',
          serverResult: const Pending(),
          browserResult: const Pending());
      final g = general(pend);
      expect(g.status, isA<Pending<ServerStatus>>());
      expect(g.contentType, isA<Pending<ContentTypeTruth>>());
      expect(g.network, isA<Pending<NetworkCard>>());
      final failed = urlInspection(
          url: 'https://a.test/',
          serverResult: const Failed('network error: boom'),
          browserResult: const Pending());
      expect((general(failed).status as Failed).error, 'network error: boom');
    });

    test('a cut chain has no final URL; the Location is offered', () {
      final h = hop('https://a.test/', 302, headers: {
        'location': ['https://a.test/next']
      });
      final snap = ServerSnapshot(
        requestedUrl: Uri.parse('https://a.test/'),
        userAgent: kServerUserAgent,
        hops: [h],
        finalUrl: const Failed('too many redirects'),
        body: const Failed('too many redirects'),
        timingMs: server(10),
        certificate: const Unavailable(UnavailableReason.notApplicable),
      );
      final p = urlInspection(
          url: 'https://a.test/',
          serverResult: server(snap),
          browserResult: const Pending());
      final s = present(general(p).status);
      expect(s.finalUrl, isA<Failed<Uri>>());
      expect(s.finalUrlLabel, 'unknown (too many redirects)');
      expect(s.redirectTo, 'https://a.test/next');
      expect(s.redirects.single.to, 'https://a.test/next');
      expect(s.bodyLabel, 'unknown (too many redirects)');
    });
  });

  group('content type truth', () {
    test('aligned header and body', () {
      final c = present(general(fullPage()).contentType);
      expect(c.declared, 'text/html; charset=utf-8');
      expect(c.sniffed, 'html');
      expect(c.verdict, ContentTypeVerdict.aligned);
    });

    test('mismatch', () {
      final h = hop('https://a.test/', 200, headers: {
        'content-type': ['application/json']
      });
      final p = urlInspection(
          url: 'https://a.test/',
          serverResult: server(serverSnapshot(
              url: 'https://a.test/', hops: [h], body: '<html><div>')),
          browserResult: const Pending());
      final c = present(general(p).contentType);
      expect(c.verdict, ContentTypeVerdict.mismatch);
    });

    test('no header is "not sent", the verdict says nothing to compare', () {
      final h = hop('https://a.test/', 200);
      final p = urlInspection(
          url: 'https://a.test/',
          serverResult: server(
              serverSnapshot(url: 'https://a.test/', hops: [h], body: 'hi')),
          browserResult: const Pending());
      final c = present(general(p).contentType);
      expect(c.declared, isNull);
      expect(c.verdict, ContentTypeVerdict.noHeader);
    });
  });

  group('source diff: server body vs rendered DOM', () {
    test('both present: counts and both labelled', () {
      final d = general(fullPage()).diff;
      expect(d.diff, isNotNull);
      expect(d.diff!.serverLines, 1);
      expect(d.diff!.browserLines, 1);
      expect(d.diff!.addedLines, 1);
      expect(d.diff!.removedLines, 1);
      expect(d.sides.map((s) => s.name), ['server HTML', 'rendered DOM']);
      expect(d.sides.every((s) => s.ready), isTrue);
    });

    test('the DOM is still pending: no diff, the side says waiting', () {
      final p = urlInspection(
          url: 'https://a.test/',
          serverResult: server(serverSnapshot(
              url: 'https://a.test/',
              hops: [hop('https://a.test/', 200)],
              body: 'x')),
          browserResult: const Pending());
      final d = general(p).diff;
      expect(d.diff, isNull);
      expect(d.sides.last.ready, isFalse);
      expect(d.sides.last.status, contains('waiting'));
    });

    test('a failed server fetch is a failure, not "missing"', () {
      final p = urlInspection(
          url: 'https://a.test/',
          serverResult: const Failed('network error: boom'),
          browserResult: browser(
              browserSnapshot(url: 'https://a.test/', dom: '<html></html>')));
      final d = general(p).diff;
      expect(d.diff, isNull);
      expect(d.sides.first.status, contains('network error: boom'));
    });
  });

  group('robots / sitemap', () {
    test('full page: counts from the store', () {
      final r = present(general(fullPage()).robots);
      expect(r.robotsLabel, 'robots 200');
      expect(r.robotsFound, isTrue);
      expect(r.sitemapsLabel, '0 sitemaps');
      expect(r.disallowLabel, '1 disallow');
      expect(r.allowLabel, '0 allow');
      expect(r.robotsUrl, 'http://example.com/robots.txt');
      expect(r.sampleDisallow, ['/private']);
    });

    test('unavailable counts are unknown, never 0', () {
      final info = RobotsInfo(
        robotsStatus: server(200),
        robotsText: const Unavailable(UnavailableReason.exceedsLimit),
        disallowCount: const Unavailable(UnavailableReason.exceedsLimit),
        allowCount: const Unavailable(UnavailableReason.exceedsLimit),
        sitemaps: const Unavailable(UnavailableReason.exceedsLimit),
        sitemapStatus: const Failed('timeout: slow'),
        robotsTruncated: true,
      );
      final base = fullPage();
      final p = PageInspection(
          generation: 1,
          target: base.target,
          server: base.server,
          browser: base.browser,
          file: base.file,
          robots: server(info));
      final r = present(general(p).robots);
      expect(r.disallowLabel, startsWith('disallow: unknown ('));
      expect(r.allowLabel, startsWith('allow: unknown ('));
      expect(r.sitemapsLabel, startsWith('sitemaps: unknown ('));
      expect(r.truncatedNote, contains('too large'));
      for (final l in [r.disallowLabel, r.allowLabel, r.sitemapsLabel]) {
        expect(l, isNot(contains(' 0 ')));
      }
    });

    test('pending / failed / unavailable robots', () {
      PageInspection with_(Observed<RobotsInfo> r) {
        final base = fullPage();
        return PageInspection(
            generation: 1,
            target: base.target,
            server: base.server,
            browser: base.browser,
            file: base.file,
            robots: r);
      }

      expect(general(with_(const Pending())).robots, isA<Pending>());
      expect(general(with_(const Failed('x'))).robots, isA<Failed>());
    });
  });

  group('browser storage and browser card', () {
    test('storage unavailable keeps its reason', () {
      final s = general(fullPage()).storage;
      expect(s, isA<Unavailable<StorageCard>>());
    });

    test('storage present: counts and UTF-8 bytes', () {
      final base = fullPage();
      final snap = (base.browser as Present<BrowserSnapshot>).value;
      final withStorage = BrowserSnapshot(
        url: snap.url,
        platform: snap.platform,
        contentType: snap.contentType,
        renderedDom: snap.renderedDom,
        resources: snap.resources,
        cookies: snap.cookies,
        storage: browser(BrowserStorage(
          local: browser(StorageArea(
              count: 2,
              bytes: browser(30),
              topItems: const [StorageItem('theme', 20)])),
          session: const Unavailable(UnavailableReason.blockedBySite),
        )),
        navigation: snap.navigation,
        snapshotTimeMs: snap.snapshotTimeMs,
      );
      final p = PageInspection(
          generation: 1,
          target: base.target,
          server: base.server,
          browser: browser(withStorage),
          file: base.file,
          robots: base.robots);
      final s = present(general(p).storage);
      expect(s.local!.countLabel, 'local 2 keys');
      expect(s.local!.sizeLabel, '30 b');
      expect(s.session, isNull);
      expect(s.sessionUnknown, startsWith('unknown ('));
      expect(s.local!.items.single.key, 'theme');
    });

    test('full page: request count and totals', () {
      final b = present(general(fullPage()).browser);
      expect(b.resourcesLabel, '2 requests');
      expect(b.url, 'https://example.com/');
      expect(b.totalSizeLabel, isNot(startsWith('≥')));
      expect(b.documentSizeLabel, contains('KB'));
    });

    test('ios: the total is a lower bound and says so', () {
      final b = present(general(iosPartial()).browser);
      expect(b.totalSizeLabel, startsWith('≥ '));
    });

    test('no HTTP status of the server is copied into the browser card', () {
      final b = present(general(botBlocked()).browser);
      expect(b.toString(), isNot(contains('403')));
      expect(b.serverStatusNote, isNull);
    });

    test('pending / failed browser', () {
      final pend = urlInspection(
          url: 'https://a.test/',
          serverResult: const Pending(),
          browserResult: const Pending());
      expect(general(pend).browser, isA<Pending<BrowserCard>>());
      expect(general(pend).storage, isA<Pending<StorageCard>>());
    });

    test('no resource list is unknown, an empty one is zero requests', () {
      final p = urlInspection(
          url: 'https://a.test/',
          serverResult: const Pending(),
          browserResult:
              browser(browserSnapshot(url: 'https://a.test/', dom: '<html/>')));
      expect(
          present(general(p).browser).resourcesLabel, startsWith('unknown ('));
      final q = urlInspection(
          url: 'https://a.test/',
          serverResult: const Pending(),
          browserResult: browser(browserSnapshot(
              url: 'https://a.test/', dom: '<html/>', resources: const [])));
      expect(present(general(q).browser).resourcesLabel, '0 requests');
    });
  });

  group('network card', () {
    test('socket address, timing and software come from the server', () {
      final n = present(general(fullPage()).network);
      expect(n.remoteAddress, '93.184.216.34');
      expect(
          n.responseTime, '42 ms (measured by the app, including DNS and TLS)');
      expect(n.serverSoftware, 'nginx');
      expect(n.via, isNull);
    });
  });
}
