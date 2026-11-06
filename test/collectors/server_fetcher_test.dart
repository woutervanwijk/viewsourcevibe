import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/collectors/server_fetcher.dart';

import '../support/fixture_server.dart';

const ua = 'TestAgent/1.0';

T present<T>(Observed<T> o) {
  expect(o, isA<Present<T>>(), reason: '$o');
  return (o as Present<T>).value;
}

void main() {
  final servers = <FixtureServer>[];
  Future<FixtureServer> start(Map<String, FixtureRoute> routes) async {
    final s = await FixtureServer.start(routes);
    servers.add(s);
    return s;
  }

  tearDown(() async {
    for (final s in servers) {
      await s.close();
    }
    servers.clear();
  });

  ServerFetcher fetcher({Duration? body}) => IoServerFetcher(
        bodyTimeout: body ?? const Duration(seconds: 30),
      );

  test('301 -> 302 -> 200 with relative Location gives 3 hops', () async {
    final s = await start({
      '/a': FixtureRoute.redirect('/b', status: 301),
      '/b': FixtureRoute.redirect('c'),
      '/c': FixtureRoute(
          headers: {'content-type': 'text/html; charset=utf-8'},
          body: utf8.encode('<p>final</p>')),
    });
    final snap = await fetcher().fetch(s.url('/a'), userAgent: ua);
    expect(snap.hops.map((h) => h.statusCode), [301, 302, 200]);
    expect(present(snap.finalUrl), s.url('/c'));
    expect(present(snap.body).decoded.text, '<p>final</p>');
    expect(snap.requestedUrl, s.url('/a'));
    expect(present(snap.timingMs), greaterThanOrEqualTo(0));
  });

  test('redirect to another origin (scheme/port/host) is a distinct hop',
      () async {
    final b = await start({'/': FixtureRoute(body: utf8.encode('b'))});
    final a = await start({'/': FixtureRoute.redirect(b.url('/').toString())});
    final snap = await fetcher().fetch(a.url('/'), userAgent: ua);
    expect(snap.hops, hasLength(2));
    expect(snap.hops[0].url.port, isNot(snap.hops[1].url.port));
    expect(present(snap.finalUrl), b.url('/'));
  });

  test('endless redirects stop at 6 hops with Unavailable(exceedsLimit)',
      () async {
    final s = await start({'/': FixtureRoute.redirect('/')});
    final snap = await fetcher().fetch(s.url('/'), userAgent: ua);
    expect(snap.hops, hasLength(6));
    expect(snap.finalUrl, isA<Unavailable<Uri>>());
    expect(
        (snap.finalUrl as Unavailable).reason, UnavailableReason.exceedsLimit);
    expect(snap.body, isA<Unavailable<ServerBody>>());
  });

  test('redirect to file:// stops the chain with a reason', () async {
    final s = await start({'/': FixtureRoute.redirect('file:///etc/passwd')});
    final snap = await fetcher().fetch(s.url('/'), userAgent: ua);
    expect(snap.hops, hasLength(1));
    final f = snap.finalUrl as Unavailable<Uri>;
    expect(f.reason, UnavailableReason.blockedBySite);
    expect(f.detail, contains('file'));
  });

  test('Set-Cookie is kept per hop', () async {
    final s = await start({
      '/1': FixtureRoute.redirect('/2', headers: {
        'set-cookie': ['a=1; Path=/', 'b=2']
      }),
      '/2': FixtureRoute.redirect('/3'),
      '/3': FixtureRoute(headers: {'set-cookie': 'c=3'}, body: [65]),
    });
    final snap = await fetcher().fetch(s.url('/1'), userAgent: ua);
    expect(snap.hops[0].setCookies, ['a=1; Path=/', 'b=2']);
    expect(snap.hops[1].setCookies, isEmpty);
    expect(snap.hops[2].setCookies, ['c=3']);
  });

  test('chunked response: contentLength unavailable, byteLength = received',
      () async {
    final s = await start({
      '/': FixtureRoute(
          body: utf8.encode('hello world'), sendContentLength: false),
    });
    final body = present((await fetcher().fetch(s.url(), userAgent: ua)).body);
    expect(body.contentLength, isA<Unavailable<int>>());
    expect((body.contentLength as Unavailable).reason,
        UnavailableReason.notReportedByServer);
    expect(body.byteLength, 11);
    expect(body.transferLength, 11);
  });

  test('gzip: wire size and decoded size recorded separately', () async {
    final text = 'abc' * 1000;
    final s = await start({
      '/': FixtureRoute(
          body: utf8.encode(text), gzip: true, sendContentLength: false),
    });
    final snap = await fetcher().fetch(s.url(), userAgent: ua);
    final body = present(snap.body);
    expect(body.decoded.text, text);
    expect(body.byteLength, 3000);
    expect(body.transferLength, lessThan(3000));
    expect(body.contentEncoding, 'gzip');
    expect(body.contentLength, isA<Unavailable<int>>());
    expect(s.requests.single.headers['accept-encoding'], contains('gzip'));
  });

  test('Content-Length header is Present when sent', () async {
    final s = await start({'/': FixtureRoute(body: utf8.encode('12345'))});
    final body = present((await fetcher().fetch(s.url(), userAgent: ua)).body);
    expect(present(body.contentLength), 5);
  });

  test('unsupported Content-Encoding gives Unavailable body, no garbage',
      () async {
    final s = await start({
      '/': FixtureRoute(headers: {'content-encoding': 'br'}, body: [1, 2, 3]),
    });
    final snap = await fetcher().fetch(s.url(), userAgent: ua);
    final b = snap.body as Unavailable<ServerBody>;
    expect(b.reason, UnavailableReason.unsupportedPlatform);
    expect(b.detail, contains('br'));
    expect(snap.finalUrl, isA<Present<Uri>>());
  });

  test('11 MB body is truncated to the first 10 MB', () async {
    final s = await start({
      '/': FixtureRoute(
          headers: {'content-type': 'text/plain'},
          body: Uint8List(11 << 20)..fillRange(0, 11 << 20, 0x61)),
    });
    final body = present((await fetcher().fetch(s.url(), userAgent: ua)).body);
    expect(body.truncated, isTrue);
    expect(body.byteLength, 10 << 20);
  });

  test('403 challenge page keeps status and body, records user agent',
      () async {
    final s = await start({
      '/': FixtureRoute(
          status: 403,
          headers: {'content-type': 'text/html'},
          body: utf8.encode('<html>Just a moment...</html>')),
    });
    final snap = await fetcher().fetch(s.url(), userAgent: ua);
    expect(snap.hops.single.statusCode, 403);
    expect(present(snap.body).decoded.text, contains('Just a moment'));
    expect(snap.userAgent, ua);
    expect(s.requests.single.headers['user-agent'], ua);
  });

  test('slow body gives Failed(timeout) within the timeout, hops kept',
      () async {
    final s = await start({
      '/': FixtureRoute(
          body: utf8.encode('x' * 1000),
          stallMidBody: const Duration(seconds: 5)),
    });
    final sw = Stopwatch()..start();
    final snap = await fetcher(body: const Duration(milliseconds: 300))
        .fetch(s.url(), userAgent: ua);
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    expect((snap.body as Failed).error, contains('timeout'));
    expect(snap.hops, hasLength(1));
  });

  test('slow headers give Failed finalUrl', () async {
    final s = await start({
      '/': FixtureRoute(body: [1], delay: const Duration(seconds: 5)),
    });
    final snap =
        await IoServerFetcher(headersTimeout: const Duration(milliseconds: 300))
            .fetch(s.url(), userAgent: ua);
    expect((snap.finalUrl as Failed).error, contains('timeout'));
    expect(snap.hops, isEmpty);
  });

  test('connection refused is Failed, not the requested URL', () async {
    final s = await start({});
    final url = s.url();
    await s.close();
    final snap = await fetcher().fetch(url, userAgent: ua);
    expect(snap.finalUrl, isA<Failed<Uri>>());
    expect(snap.body, isA<Failed<ServerBody>>());
  });

  test('failure after a redirect keeps the recorded hop', () async {
    final dead = await start({});
    final deadUrl = dead.url('/x');
    await dead.close();
    final s = await start({'/': FixtureRoute.redirect(deadUrl.toString())});
    final snap = await fetcher().fetch(s.url(), userAgent: ua);
    expect(snap.hops, hasLength(1));
    expect(snap.finalUrl, isA<Failed<Uri>>());
  });

  test('remoteAddress is the socket address; http has no certificate',
      () async {
    final s = await start({
      '/': FixtureRoute(body: [65])
    });
    final snap = await fetcher().fetch(s.url(), userAgent: ua);
    expect(present(snap.hops.single.remoteAddress), '127.0.0.1');
    expect((snap.certificate as Unavailable).reason,
        UnavailableReason.notApplicable);
  });

  test('non-http(s) start URL is Failed', () async {
    final snap =
        await fetcher().fetch(Uri.parse('ftp://example.com/'), userAgent: ua);
    expect(snap.finalUrl, isA<Failed<Uri>>());
    expect(snap.hops, isEmpty);
  });

  test('certificate is Unavailable when the chain failed', () async {
    final dead = await start({});
    final deadUrl = dead.url('/x');
    await dead.close();
    final s = await start({'/': FixtureRoute.redirect(deadUrl.toString())});
    final snap = await fetcher().fetch(s.url(), userAgent: ua);
    expect(snap.hops, hasLength(1));
    expect(snap.certificate, isA<Unavailable<Map<String, dynamic>>>());
  });

  test('repeated Content-Type / Content-Length headers do not throw', () async {
    final s = await start({
      '/': FixtureRoute(headers: {
        'content-type': ['text/html', 'text/plain'],
        'content-length': ['2', '2'],
      }, body: utf8.encode('hi'), sendContentLength: false),
    });
    final snap = await fetcher().fetch(s.url(), userAgent: ua);
    expect(snap.hops, hasLength(1));
    expect(snap.body, anyOf(isA<Present<ServerBody>>(), isA<Failed>()));
  });

  test('parseContentLength handles repeated values', () {
    expect(present(IoServerFetcher.parseContentLength(['5', '5'])), 5);
    final bad = IoServerFetcher.parseContentLength(['5', '6']) as Unavailable;
    expect(bad.detail, 'conflicting content-length');
    expect(bad.reason, UnavailableReason.notReportedByServer);
    expect(IoServerFetcher.parseContentLength(null), isA<Unavailable<int>>());
    expect(IoServerFetcher.parseContentLength(['x']), isA<Unavailable<int>>());
  });

  group('fetchRobots', () {
    test('robots.txt over 256 KB: counts Unavailable(exceedsLimit)', () async {
      final big = utf8.encode('Disallow: /a\n' * 25000); // ~325 KB
      final s = await start({'/robots.txt': FixtureRoute(body: big)});
      final r = await fetcher().fetchRobots(s.url('/'), userAgent: ua);
      expect(r.robotsTruncated, isTrue);
      expect(present(r.robotsText).length, 256 * 1024);
      for (final o in [r.disallowCount, r.allowCount, r.sitemaps]) {
        expect((o as Unavailable).reason, UnavailableReason.exceedsLimit);
      }
    });

    test('parses counts and sitemaps; sitemap status via HEAD', () async {
      final s = await start({
        '/robots.txt': FixtureRoute(
            headers: {'content-type': 'text/plain'},
            body: utf8.encode('User-agent: *\nDisallow: /a\nDisallow: /b # c\n'
                'Disallow:\nAllow: /a/ok\nSitemap: https://x.test/s.xml\n')),
        '/sitemap.xml': FixtureRoute(body: utf8.encode('<urlset/>')),
      });
      final r = await fetcher().fetchRobots(s.url('/'), userAgent: ua);
      expect(present(r.robotsStatus), 200);
      expect(present(r.disallowCount), 2);
      expect(present(r.allowCount), 1);
      expect(present(r.sitemaps), ['https://x.test/s.xml']);
      expect(present(r.sitemapStatus), 200);
      expect(present(r.robotsText), contains('Disallow: /a'));
      expect(s.requests.where((q) => q.path == '/sitemap.xml').single.method,
          'HEAD');
    });

    test('404 robots gives Unavailable, not zero counts', () async {
      final s = await start({});
      final r = await fetcher().fetchRobots(s.url('/'), userAgent: ua);
      expect(present(r.robotsStatus), 404);
      expect(r.robotsText, isA<Unavailable<String>>());
      expect(r.disallowCount, isA<Unavailable<int>>());
      expect(r.allowCount, isA<Unavailable<int>>());
      expect(r.sitemaps, isA<Unavailable<List<String>>>());
    });

    test('unreachable origin gives Failed values', () async {
      final s = await start({});
      final url = s.url('/');
      await s.close();
      final r = await fetcher().fetchRobots(url, userAgent: ua);
      expect(r.robotsStatus, isA<Failed<int>>());
      expect(r.disallowCount, isA<Failed<int>>());
    });
  });
}
