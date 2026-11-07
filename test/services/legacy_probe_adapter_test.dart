import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/legacy_probe_adapter.dart';
import 'package:view_source_vibe/utils/text_decoding.dart';

Present<T> _p<T>(T v) => Present(v, source: DataSource.server);

HttpHop _hop(String url, int status,
        {String reason = 'OK',
        Map<String, List<String>> headers = const {},
        List<String> cookies = const [],
        String? ip}) =>
    HttpHop(
      url: Uri.parse(url),
      statusCode: status,
      reasonPhrase: reason,
      headers: headers,
      setCookies: cookies,
      remoteAddress: ip == null
          ? const Unavailable(UnavailableReason.notReportedByPlatform)
          : _p(ip),
      certificate: const Unavailable(UnavailableReason.notApplicable),
    );

ServerBody _body(String text, {Observed<int>? contentLength}) => ServerBody(
      decoded: DecodedText(
          text: text,
          charset: 'utf-8',
          charsetSource: CharsetSource.fallback,
          byteLength: text.length),
      transferLength: text.length,
      truncated: false,
      contentLength: contentLength ??
          const Unavailable(UnavailableReason.notReportedByServer),
    );

ServerSnapshot _snapshot(List<HttpHop> hops,
    {Observed<ServerBody>? body,
    Observed<Uri>? finalUrl,
    Observed<int>? timing,
    bool acceptedInvalidCertificate = false}) {
  return ServerSnapshot(
    requestedUrl: hops.first.url,
    userAgent: 'ua',
    hops: hops,
    finalUrl: finalUrl ?? _p(hops.last.url),
    body: body ?? _p(_body('<p>x</p>')),
    timingMs: timing ?? _p(42),
    certificate: const Unavailable(UnavailableReason.notApplicable),
    acceptedInvalidCertificate: acceptedInvalidCertificate,
  );
}

PageInspection _inspection(Observed<ServerSnapshot> server,
        {Observed<RobotsInfo> robots = const Pending()}) =>
    PageInspection(
      generation: 1,
      target: UrlTarget(Uri.parse('http://a.test/start')),
      server: server,
      browser: const Pending(),
      file: const Unavailable(UnavailableReason.notApplicable),
      robots: robots,
    );

void main() {
  final threeHops = _snapshot([
    _hop('http://a.test/start', 301, reason: 'Moved Permanently', headers: {
      'location': ['https://a.test/start'],
      'set-cookie': ['a=1; Path=/']
    }, cookies: [
      'a=1; Path=/'
    ]),
    _hop('https://a.test/start', 302, reason: 'Found', headers: {
      'location': ['/final']
    }),
    _hop('https://a.test/final', 200,
        headers: {
          'content-type': ['text/html; charset=utf-8'],
          'x-multi': ['one', 'two'],
          'set-cookie': ['b=2; Path=/'],
          'strict-transport-security': ['max-age=1'],
        },
        cookies: ['b=2; Path=/'],
        ip: '203.0.113.9'),
  ]);

  group('legacyProbeMap', () {
    test('multi-hop snapshot yields the redirect chain and final-hop fields',
        () {
      final m = legacyProbeMap(_inspection(_p(threeHops)))!;
      expect(m['statusCode'], 200);
      expect(m['reasonPhrase'], 'OK');
      expect(m['isRedirect'], isTrue);
      expect(m['url'], 'http://a.test/start');
      expect(m['finalUrl'], 'https://a.test/final');
      expect(m['redirectLocation'], 'https://a.test/final');
      expect(m['redirectChain'], [
        {
          'from': 'http://a.test/start',
          'to': 'https://a.test/start',
          'statusCode': 301,
          'reasonPhrase': 'Moved Permanently'
        },
        {
          'from': 'https://a.test/start',
          'to': 'https://a.test/final',
          'statusCode': 302,
          'reasonPhrase': 'Found'
        },
      ]);
      expect(m['ip'], '203.0.113.9');
      expect(m['ipAddress'], '203.0.113.9');
      expect(m['responseTime'], 42);
      final headers = m['headers'] as Map<String, String>;
      expect(headers['x-multi'], 'one, two');
      expect(headers['content-type'], 'text/html; charset=utf-8');
      expect(headers.containsKey('set-cookie'), isFalse);
      expect((m['security'] as Map)['Strict-Transport-Security'], 'max-age=1');
      expect((m['security'] as Map)['Content-Security-Policy'], isNull);
    });

    test('a single hop is not a redirect and has no chain', () {
      final m = legacyProbeMap(_inspection(_p(_snapshot([
        _hop('http://a.test/', 200),
      ]))))!;
      expect(m['isRedirect'], isFalse);
      expect(m.containsKey('redirectChain'), isFalse);
      expect(m.containsKey('redirectLocation'), isFalse);
    });

    test('missing content-length leaves the key out (never 0)', () {
      final m = legacyProbeMap(_inspection(_p(threeHops)))!;
      expect(m.containsKey('contentLength'), isFalse);
    });

    test('present content-length is reported', () {
      final s = _snapshot([_hop('http://a.test/', 200)],
          body: _p(_body('x', contentLength: _p(1234))));
      expect(legacyProbeMap(_inspection(_p(s)))!['contentLength'], 1234);
    });

    test('Set-Cookie from the first and the last hop are both in cookies', () {
      final m = legacyProbeMap(_inspection(_p(threeHops)))!;
      expect(m['cookies'], ['a=1; Path=/', 'b=2; Path=/']);
    });

    test('analyzedCookies merges server and browser cookies', () {
      final m = legacyProbeMap(_inspection(_p(threeHops)),
          browserCookies: 'c=3; d=4')!;
      final names =
          (m['analyzedCookies'] as List).map((c) => (c as Map)['name']).toSet();
      expect(names, containsAll(['a', 'b', 'c', 'd']));
    });

    test('unknown values are absent, not 0 or empty', () {
      final s = _snapshot([_hop('http://a.test/', 200)],
          timing: const Unavailable(UnavailableReason.notReportedByPlatform));
      final m = legacyProbeMap(_inspection(_p(s)))!;
      expect(m.containsKey('ip'), isFalse);
      expect(m.containsKey('ipAddress'), isFalse);
      expect(m.containsKey('responseTime'), isFalse);
      expect(m['certificate'], isNull);
    });

    test('a chain that was cut short has no finalUrl', () {
      final s = _snapshot([
        _hop('http://a.test/', 302, headers: {
          'location': ['/b']
        }),
        _hop('http://a.test/b', 302, headers: {
          'location': ['/c']
        }),
      ],
          finalUrl: const Unavailable(UnavailableReason.exceedsLimit),
          body: const Unavailable(UnavailableReason.exceedsLimit));
      final m = legacyProbeMap(_inspection(_p(s)))!;
      expect(m.containsKey('finalUrl'), isFalse);
      expect(m.containsKey('redirectLocation'), isFalse);
      expect(m['statusCode'], 302);
    });

    test('Pending, Unavailable and Failed servers give null', () {
      expect(legacyProbeMap(_inspection(const Pending())), isNull);
      expect(
          legacyProbeMap(_inspection(const Unavailable(
              UnavailableReason.notApplicable, 'local file'))),
          isNull);
      expect(legacyProbeMap(_inspection(const Failed('boom'))), isNull);
    });

    test('tls flags come from the snapshot, only for https', () {
      final ok = legacyProbeMap(_inspection(_p(_snapshot(
          [_hop('https://a.test/', 200)],
          acceptedInvalidCertificate: false))))!;
      expect(ok['tlsInvalidCertificate'], isFalse);
      expect(ok['tlsWarning'], isNull);
      final bad = legacyProbeMap(_inspection(_p(_snapshot(
          [_hop('https://a.test/', 200)],
          acceptedInvalidCertificate: true))))!;
      expect(bad['tlsInvalidCertificate'], isTrue);
      expect(bad['tlsWarning'], isNotNull);
      final http = legacyProbeMap(
          _inspection(_p(_snapshot([_hop('http://a.test/', 200)]))))!;
      expect(http.containsKey('tlsInvalidCertificate'), isFalse);
    });

    test('robotsSitemap is built from RobotsInfo and absent while pending', () {
      expect(
          legacyProbeMap(_inspection(_p(threeHops)))!
              .containsKey('robotsSitemap'),
          isFalse);

      final robots = RobotsInfo(
        robotsStatus: _p(200),
        robotsText: _p('User-agent: *\nDisallow: /a\nDisallow: /b\nAllow: /c\n'
            'Sitemap: https://a.test/s.xml\n'),
        disallowCount: _p(2),
        allowCount: _p(1),
        sitemaps: _p(['https://a.test/s.xml']),
        sitemapStatus: _p(404),
      );
      final m = legacyProbeMap(_inspection(_p(threeHops), robots: _p(robots)))!;
      final r = m['robotsSitemap'] as Map;
      expect(r['robotsUrl'], 'http://a.test/robots.txt');
      expect(r['robotsStatus'], 200);
      expect(r['robotsPresent'], isTrue);
      expect(r['sitemapStatus'], 404);
      expect(r['sitemaps'], ['https://a.test/s.xml']);
      expect(r['disallowCount'], 2);
      expect(r['allowCount'], 1);
      expect(r['sampleDisallow'], ['/a', '/b']);
    });

    test('robots counts that are unavailable are left out', () {
      const no = Unavailable<int>(UnavailableReason.notReportedByServer);
      final robots = RobotsInfo(
        robotsStatus: _p(404),
        robotsText: const Unavailable(UnavailableReason.notReportedByServer),
        disallowCount: no,
        allowCount: no,
        sitemaps: const Unavailable(UnavailableReason.notReportedByServer),
        sitemapStatus: const Failed('timeout'),
      );
      final r = legacyProbeMap(_inspection(_p(threeHops), robots: _p(robots)))![
          'robotsSitemap'] as Map;
      expect(r['robotsStatus'], 404);
      expect(r['robotsPresent'], isFalse);
      expect(r.containsKey('disallowCount'), isFalse);
      expect(r.containsKey('allowCount'), isFalse);
      expect(r.containsKey('sitemapStatus'), isFalse);
      expect(r.containsKey('sitemaps'), isFalse);
    });
  });
}
