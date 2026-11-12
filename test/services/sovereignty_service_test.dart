import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/detection/engine.dart';
import '../detection_helpers.dart';
import '../fixtures/inspection/builders.dart';
import 'package:view_source_vibe/services/jurisdiction.dart';
import 'package:view_source_vibe/services/probe_service.dart';
import 'package:view_source_vibe/services/sovereignty_service.dart';

void main() {
  group('provider matching', () {
    test('matches hosts, ASN holders and DNS records', () {
      expect(matchProvider(['cdnjs.cloudflare.com'])?.name, 'Cloudflare');
      expect(matchProvider(['x', 'AMAZON-02 - Amazon.com, Inc.'])?.name,
          'Amazon (AWS)');
      expect(matchProvider(['ns-1582.awsdns-05.co.uk'])?.country, 'US');
      expect(matchProvider(['ns1.transip.nu'])?.country, 'NL');
      expect(matchProvider(['example.org']), isNull);
    });

    test('detects CDN from headers', () {
      expect(detectCdnFromHeaders({'CF-Ray': 'abc'})?.name, 'Cloudflare');
      expect(detectCdnFromHeaders({'x-vercel-id': '1'})?.name, 'Vercel');
      expect(detectCdnFromHeaders({'server': 'nginx'}), isNull);
    });
  });

  group('jurisdiction', () {
    test('relation to home, symmetric for any home', () {
      expect(relationTo('NL', eu), Relation.own);
      expect(relationTo('NO', eu), Relation.own); // EEA
      expect(relationTo('CH', eu), Relation.adequate);
      expect(relationTo('US', eu), Relation.foreign); // DPF not verifiable
      expect(relationTo(null, eu), Relation.unknown);
      expect(relationTo('US', 'US'), Relation.own);
      expect(relationTo('DE', 'US'), Relation.foreign);
      expect(relationTo('DE', 'GB'), Relation.adequate);
      expect(relationTo('JP', 'US'), Relation.foreign);
    });

    test('unlisted company: ASN registration country, never IP location', () {
      final host = HostInfo('z.example')
        ..ipCountry = 'US' // edge node / geolocation
        ..asnCountry = 'NL';
      expect(host.controlCountry, 'NL');
      expect(HostInfo('w.example').controlCountry, isNull);
    });

    test('CDNs are edge providers, not hosting', () {
      expect(matchProvider(['CLOUDFLARENET - Cloudflare, Inc.'])?.edge, isTrue);
      expect(matchProvider(['AKAMAI-ASN1 Akamai International B.V.'])?.country,
          'US');
      expect(matchProvider(['hetzner'])?.edge, isFalse);
    });

    test('regions', () {
      expect(regionOf('FR'), 'EU/EEA');
      expect(regionOf('GB'), 'Europe (other)');
      expect(regionOf('US'), 'North America');
      expect(regionOf('SG'), 'Asia');
      expect(regionOf('XX'), 'Other');
      expect(regionOf(null), 'Unknown');
    });

    test('company HQ wins over server location', () {
      final host = HostInfo('x.example')
        ..ipCountry = 'DE'
        ..asnCountry = 'DE'
        ..provider = matchProvider(['cloudfront.net']);
      expect(host.relation(eu), Relation.foreign);
      expect(host.foreignControlled(eu), isTrue);
      // From a US viewpoint the same host is domestic.
      expect(host.relation('US'), Relation.own);
      expect(host.foreignControlled('US'), isFalse);

      final local = HostInfo('y.example')
        ..ipCountry = 'DE'
        ..provider = matchProvider(['hetzner']);
      expect(local.relation(eu), Relation.own);
      expect(local.foreignControlled(eu), isFalse);
    });

    test('notes name the applicable law, not a fixed country', () {
      expect(jurisdictionNote('US', eu), contains('CLOUD Act'));
      expect(jurisdictionNote('US', eu), contains('Data Privacy Framework'));
      expect(
          jurisdictionNote('CN', 'US'), contains('National Intelligence Law'));
      expect(jurisdictionNote('US', 'US'), isEmpty);
      expect(jurisdictionNote('GB', eu), contains('adequate'));
    });

    test('shares per region and relation', () {
      final report = SovereigntyReport(
        mainHost: 'a',
        hosts: [
          HostInfo('a')
            ..requests = 3
            ..ipCountry = 'NL'
            ..asnCountry = 'NL',
          HostInfo('b')
            ..requests = 1
            ..ipCountry = 'US'
            ..asnCountry = 'US',
        ],
        cdn: null,
        nameServers: const [],
        mailServers: const [],
        tlsIssuer: null,
        tlsProvider: null,
        checks: const [],
      );
      expect(report.regionShare(byControl: false)['EU/EEA'], 0.75);
      expect(report.regionShare(byControl: false)['North America'], 0.25);
      expect(report.relationShare()[Relation.foreign], 0.25);
    });
  });

  group('DNS wire format', () {
    test('builds a query', () {
      final q = SovereigntyService.buildDnsQuery('nos.nl', 2);
      expect(q.sublist(12), [3, 110, 111, 115, 2, 110, 108, 0, 0, 2, 0, 1]);
    });

    test('parses compressed NS answers', () {
      // Real Quad9 response for nos.nl NS (trimmed to two answers).
      final data = Uint8List.fromList([
        0, 0, 0x81, 0x80, 0, 1, 0, 2, 0, 0, 0, 0,
        3, 110, 111, 115, 2, 110, 108, 0, 0, 2, 0, 1, // question
        0xC0, 0x0C, 0, 2, 0, 1, 0, 0, 7, 0x4B, 0, 0x16, // answer 1 header
        6, 110, 115, 45, 51, 49, 49, 9, 97, 119, 115, 100, 110, 115, 45, 51, 56,
        3, 99, 111, 109, 0,
        0xC0, 0x0C, 0, 2, 0, 1, 0, 0, 7, 0x4B, 0, 0x09, // answer 2 header
        6, 110, 115, 45, 56, 50, 51, 0xC0,
        0x2B, // ns-823 + pointer to awsdns-38.com
      ]);
      expect(SovereigntyService.parseDnsRecords(data, 2),
          ['ns-311.awsdns-38.com', 'ns-823.awsdns-38.com']);
    });

    test('tolerates garbage', () {
      expect(SovereigntyService.parseDnsRecords(Uint8List(3), 2), isEmpty);
    });
  });

  test('registrable domain', () {
    expect(SovereigntyService.registrableDomain('www.nos.nl'), 'nos.nl');
    expect(SovereigntyService.registrableDomain('a.b.bbc.co.uk'), 'bbc.co.uk');
    expect(SovereigntyService.registrableDomain('nos.nl'), 'nos.nl');
  });

  group('DNS security records (captured LibreDNS responses)', () {
    test('TXT: DMARC record for _dmarc.utrecht.nl', () {
      final data = Uint8List.fromList([
        0,
        0,
        129,
        128,
        0,
        1,
        0,
        1,
        0,
        0,
        0,
        0,
        6,
        95,
        100,
        109,
        97,
        114,
        99,
        7,
        117,
        116,
        114,
        101,
        99,
        104,
        116,
        2,
        110,
        108,
        0,
        0,
        16,
        0,
        1,
        192,
        12,
        0,
        16,
        0,
        1,
        0,
        0,
        14,
        16,
        0,
        109,
        62,
        118,
        61,
        68,
        77,
        65,
        82,
        67,
        49,
        59,
        112,
        61,
        113,
        117,
        97,
        114,
        97,
        110,
        116,
        105,
        110,
        101,
        59,
        114,
        117,
        97,
        61,
        109,
        97,
        105,
        108,
        116,
        111,
        58,
        100,
        109,
        97,
        114,
        99,
        64,
        105,
        110,
        98,
        111,
        117,
        110,
        100,
        46,
        102,
        108,
        111,
        119,
        109,
        97,
        105,
        108,
        101,
        114,
        46,
        110,
        101,
        116,
        59,
        45,
        114,
        117,
        102,
        61,
        109,
        97,
        105,
        108,
        116,
        111,
        58,
        100,
        109,
        97,
        114,
        99,
        64,
        105,
        110,
        98,
        111,
        117,
        110,
        100,
        46,
        102,
        108,
        111,
        119,
        109,
        97,
        105,
        108,
        101,
        114,
        46,
        110,
        101,
        116,
        59,
        102,
        111,
        61,
        49,
        59
      ]);
      final txt = SovereigntyService.parseDnsRecords(data, 16);
      expect(txt.single, startsWith('v=DMARC1;p=quarantine;'));
      expect(classifyDmarc(txt).$1, CheckStatus.pass);
    });

    test('CAA for google.com', () {
      final data = Uint8List.fromList([
        0,
        0,
        129,
        128,
        0,
        1,
        0,
        1,
        0,
        0,
        0,
        0,
        6,
        103,
        111,
        111,
        103,
        108,
        101,
        3,
        99,
        111,
        109,
        0,
        1,
        1,
        0,
        1,
        192,
        12,
        1,
        1,
        0,
        1,
        0,
        1,
        81,
        128,
        0,
        15,
        0,
        5,
        105,
        115,
        115,
        117,
        101,
        112,
        107,
        105,
        46,
        103,
        111,
        111,
        103
      ]);
      expect(SovereigntyService.parseDnsRecords(data, 257), ['issue pki.goog']);
    });

    test('DS present for cloudflare.com, absent for google.com', () {
      final signed = Uint8List.fromList([
        0,
        0,
        129,
        128,
        0,
        1,
        0,
        1,
        0,
        0,
        0,
        0,
        10,
        99,
        108,
        111,
        117,
        100,
        102,
        108,
        97,
        114,
        101,
        3,
        99,
        111,
        109,
        0,
        0,
        43,
        0,
        1,
        192,
        12,
        0,
        43,
        0,
        1,
        0,
        1,
        59,
        37,
        0,
        36,
        9,
        67,
        13,
        2,
        50,
        153,
        104,
        57,
        166,
        216,
        8,
        175,
        227,
        235,
        74,
        121,
        90,
        14,
        106,
        122,
        57,
        167,
        111,
        197,
        47,
        242,
        40,
        178,
        43,
        118,
        246,
        214,
        56,
        38,
        242,
        185
      ]);
      final unsigned = Uint8List.fromList([
        0,
        0,
        129,
        128,
        0,
        1,
        0,
        0,
        0,
        1,
        0,
        0,
        6,
        103,
        111,
        111,
        103,
        108,
        101,
        3,
        99,
        111,
        109,
        0,
        0,
        43,
        0,
        1,
        192,
        19,
        0,
        6,
        0,
        1,
        0,
        0,
        1,
        183,
        0,
        61,
        1,
        97,
        12,
        103,
        116,
        108,
        100,
        45,
        115,
        101,
        114,
        118,
        101,
        114,
        115,
        3,
        110,
        101,
        116,
        0,
        5,
        110,
        115,
        116,
        108,
        100,
        12,
        118,
        101,
        114,
        105,
        115,
        105,
        103,
        110,
        45,
        103,
        114,
        115,
        192,
        19,
        106,
        196,
        213,
        69,
        0,
        0,
        7,
        8,
        0,
        0,
        3,
        132,
        0,
        9,
        58,
        128,
        0,
        0,
        3,
        132
      ]);
      expect(SovereigntyService.parseDnsRecords(signed, 43), ['key tag 2371']);
      expect(SovereigntyService.parseDnsRecords(unsigned, 43), isEmpty);
    });

    test('query encodes two-byte types', () {
      final q = SovereigntyService.buildDnsQuery('a.nl', 257);
      expect(q.sublist(q.length - 4), [1, 1, 0, 1]);
    });
  });

  group('policy classification', () {
    test('SPF', () {
      expect(classifySpf(['v=spf1 include:x -all']).$1, CheckStatus.pass);
      expect(classifySpf(['v=spf1 include:x ~all']).$1, CheckStatus.warn);
      expect(classifySpf(['v=spf1 +all']).$1, CheckStatus.fail);
      expect(classifySpf(['google-site-verification=x']).$1, CheckStatus.fail);
    });

    test('DMARC', () {
      expect(classifyDmarc(['v=DMARC1; p=reject']).$1, CheckStatus.pass);
      expect(classifyDmarc(['v=DMARC1; p=none']).$1, CheckStatus.warn);
      expect(classifyDmarc([]).$1, CheckStatus.fail);
    });

    test('privacy link', () {
      expect(findPrivacyLink('<a href="/over/privacyverklaring">Privacy</a>'),
          '/over/privacyverklaring');
      expect(findPrivacyLink("<a class='x' href='/p'>Datenschutz</a>"), '/p');
      expect(findPrivacyLink('<a href="/contact">Contact</a>'), isNull);
    });
  });

  group('score', () {
    SovereigntyReport report(List<SovereigntyCheck> checks) =>
        SovereigntyReport(
          mainHost: 'a',
          hosts: const [],
          cdn: null,
          nameServers: const [],
          mailServers: const [],
          tlsIssuer: null,
          tlsProvider: null,
          checks: checks,
        );

    test('weighted per pillar, pillars scaled to 40/25/20/15', () {
      final r = report([
        // infrastructure: essential pass (3) + limited fail (1) => 3/4 of 40
        const SovereigntyCheck(
            Pillar.infrastructure, 'mail', CheckStatus.pass, '',
            weight: 3),
        const SovereigntyCheck(
            Pillar.infrastructure, 'tls', CheckStatus.fail, ''),
        // unknown (e.g. hosting behind a CDN) is left out, not counted as 0
        const SovereigntyCheck(
            Pillar.infrastructure, 'hosting', CheckStatus.unknown, '',
            weight: 3),
        // residency: one warn => half of 25
        const SovereigntyCheck(Pillar.residency, 'a', CheckStatus.warn, ''),
        // security: nothing verifiable => n/a, total rescaled to 80 points
        const SovereigntyCheck(Pillar.security, 'c', CheckStatus.unknown, ''),
        // privacy: minor fail barely matters next to a pass
        const SovereigntyCheck(Pillar.privacy, 'd', CheckStatus.pass, ''),
        const SovereigntyCheck(Pillar.privacy, 'fonts', CheckStatus.fail, '',
            weight: 0.5),
      ]);
      expect(r.pillarScore(Pillar.infrastructure), 30);
      expect(r.pillarScore(Pillar.residency), 12.5);
      expect(r.pillarScore(Pillar.security), isNull);
      expect(r.pillarScore(Pillar.privacy), 10);
      expect(r.score, 66); // 52.5 of 80
      expect(r.grade, 'Fair');
      expect(r.count(CheckStatus.pass), 2);
    });

    test('pillar maxima add up to 100', () {
      expect(pillarMax.values.reduce((a, b) => a + b), 100);
    });
  });

  test('vendor origins', () {
    expect(vendorOriginFor('TYPO3'), selfHosted);
    expect(
        relationTo(vendorOriginFor('Google Analytics'), eu), Relation.foreign);
    expect(relationTo(vendorOriginFor('Plausible'), eu), Relation.own);
    expect(vendorOriginFor('Unknown thing'), isNull);
  });

  test('TYPO3 detection', () async {
    final byGenerator = await extractMetadataWithDetections(
        '<html><head><meta name="generator" content="TYPO3 CMS"></head></html>',
        'https://example.nl/');
    final byPath = await extractMetadataWithDetections(
        '<html><head><link href="/typo3temp/assets/x.css" rel="stylesheet"></head></html>',
        'https://example.nl/');
    expect(techOf(byGenerator)['CMS'], 'TYPO3');
    expect(techOf(byPath)['CMS'], 'TYPO3');
  });

  test('every EU alternative has a website', () {
    for (final name in euAlternatives.values.expand((list) => list)) {
      expect(alternativeUrls[name], startsWith('https://'), reason: name);
    }
  });

  group('site jurisdiction detection', () {
    test('certificate subject wins (OV/EV names the legal entity)', () {
      final site = detectSiteJurisdiction(
        host: 'tweakers.net',
        certificateSubject: {
          'Country': 'BE',
          'Organization': 'DPG Media Group NV',
        },
      );
      expect(site?.jurisdiction, eu);
      expect(site?.source, contains('DPG Media Group NV'));
      expect(
        detectSiteJurisdiction(
          host: 'x.com',
          certificateSubject: {'JURISDICTIONC': 'US', 'Country': 'NL'},
        )?.jurisdiction,
        'US',
      );
    });

    test('schema.org addressCountry, then ccTLD', () {
      expect(
        detectSiteJurisdiction(host: 'shop.com', structuredData: [
          {
            '@type': 'Organization',
            'address': {'addressCountry': 'ca'},
          },
        ])?.jurisdiction,
        'CA',
      );
      expect(detectSiteJurisdiction(host: 'www.utrecht.nl')?.jurisdiction, eu);
      expect(detectSiteJurisdiction(host: 'bbc.co.uk')?.jurisdiction, 'GB');
      expect(detectSiteJurisdiction(host: 'europa.eu')?.source, 'Domain .eu');
    });

    test('no guess for generic domains', () {
      expect(detectSiteJurisdiction(host: 'github.com'), isNull);
      expect(detectSiteJurisdiction(host: 'example.io'), isNull);
      expect(
        detectSiteJurisdiction(
            host: 'bol.com',
            certificateSubject: {'Common Name': 'www.bol.com'}),
        isNull,
      );
    });
  });

  group('Task 9: rcode, PSL-lite, security.txt, concurrency, HSTS', () {
    Uint8List response(int rcode, {int answers = 0}) => Uint8List.fromList([
          0, 0, 0x81, 0x80 | rcode, 0, 1, 0, answers, 0, 0, 0, 0,
          3, 110, 111, 115, 2, 110, 108, 0, 0, 16, 0, 1, // question TXT
        ]);

    test('SERVFAIL / REFUSED are unknown (null), not a missing record', () {
      expect(SovereigntyService.dnsRcode(response(2)), 2);
      expect(SovereigntyService.classifyDnsResponse(response(2), 16), isNull);
      expect(SovereigntyService.classifyDnsResponse(response(5), 16), isNull);
    });

    test('NXDOMAIN and NOERROR-without-answers are a genuine "no record"', () {
      expect(SovereigntyService.classifyDnsResponse(response(3), 16), isEmpty);
      expect(SovereigntyService.classifyDnsResponse(response(0), 16), isEmpty);
    });

    test('an unknown record (null) gives CheckStatus.unknown, not fail', () {
      final checks = SovereigntyService.securityChecks(
          txt: null,
          dmarc: null,
          caa: null,
          ds: null,
          securityTxt: null,
          server: null);
      expect(checks.where((c) => c.title.contains('SPF')).single.status,
          CheckStatus.unknown);
      expect(checks.where((c) => c.title.contains('DMARC')).single.status,
          CheckStatus.unknown);
    });

    test('registrableDomain knows common multi-label public suffixes', () {
      expect(SovereigntyService.registrableDomain('foo.github.io'),
          'foo.github.io');
      expect(SovereigntyService.registrableDomain('a.b.foo.github.io'),
          'foo.github.io');
      expect(SovereigntyService.registrableDomain('x.example.ne.jp'),
          'example.ne.jp');
      expect(SovereigntyService.registrableDomain('www.app.vercel.app'),
          'app.vercel.app');
      expect(
          SovereigntyService.registrableDomain('www.bbc.co.uk'), 'bbc.co.uk');
      expect(SovereigntyService.registrableDomain('www.example.com.au'),
          'example.com.au');
      expect(SovereigntyService.registrableDomain('www.nos.nl'), 'nos.nl');
      expect(SovereigntyService.registrableDomain('localhost'), 'localhost');
      expect(SovereigntyService.registrableDomain('github.io'), 'github.io');
    });

    test('security.txt: published needs 200 + text/plain + Contact:', () {
      const body = 'Contact: mailto:sec@example.com\nExpires: 2030-01-01';
      bool? c(int? s, {String? ct, String? b}) =>
          SovereigntyService.classifySecurityTxt(s, contentType: ct, body: b);
      expect(c(200, ct: 'text/plain; charset=utf-8', b: body), isTrue);
      expect(c(200, ct: 'Text/Plain', b: '# x\ncontact: a@b.c'), isTrue);
      expect(c(200, ct: 'text/html', b: body), isFalse);
      expect(c(200, ct: 'text/plain', b: 'Not found page'), isFalse);
      expect(c(200), isFalse);
      expect(c(404), isFalse);
      expect(c(403), isNull);
      expect(c(429), isNull);
      expect(c(500), isNull);
      expect(c(null), isNull);
    });

    test('limited() never runs more than the limit at once', () async {
      var running = 0, peak = 0;
      Future<int> task(int i) async {
        running++;
        if (running > peak) peak = running;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        running--;
        return i;
      }

      final out = await SovereigntyService.limited(
          [for (var i = 0; i < 30; i++) () => task(i)],
          limit: 6);
      expect(out, List.generate(30, (i) => i));
      expect(peak, lessThanOrEqualTo(6));
      expect(peak, greaterThan(1));
    });

    test('HSTS uses the real server headers; no server is unknown', () {
      ServerSnapshot snapshot(Map<String, List<String>> headers) =>
          serverSnapshot(
              url: 'https://a.test/',
              hops: [hop('https://a.test/', 200, headers: headers)],
              body: 'x');
      SovereigntyCheck hsts(ServerSnapshot? server) =>
          SovereigntyService.securityChecks(
                  txt: const [],
                  dmarc: const [],
                  caa: const [],
                  ds: const [],
                  securityTxt: null,
                  server: server)
              .firstWhere((c) => c.title.startsWith('HSTS'));
      expect(hsts(null).status, CheckStatus.unknown);
      expect(
          hsts(snapshot({
            'strict-transport-security': ['max-age=31536000']
          })).status,
          CheckStatus.pass);
      expect(hsts(snapshot({})).status, CheckStatus.fail);
    });
  });

  group('Task 9 fix 1', () {
    test('registrableDomain generic ccTLD rule, IPs and case (I3)', () {
      String r(String h) => SovereigntyService.registrableDomain(h);
      expect(r('x.foo.com.mx'), 'foo.com.mx');
      expect(r('a.b.com.pl'), 'b.com.pl');
      expect(r('shop.co.at'), 'shop.co.at');
      expect(r('1.2.3.4'), '1.2.3.4');
      expect(r('2001:db8::1'), '2001:db8::1');
      expect(r('Foo.Example.COM'), 'example.com');
    });

    test('the production limiter is the tested one: ripeConcurrency <= 6', () {
      expect(SovereigntyService.ripeConcurrency, lessThanOrEqualTo(6));
    });

    test('a throwing task is unknown for that host, not a failed batch',
        () async {
      final out = await SovereigntyService.limited<int?>([
        () async => 1,
        () async => throw StateError('boom'),
        () async => 3,
      ], limit: 2);
      expect(out, [1, null, 3]);
    });

    test('RIPEstat gate runs at most 6 requests at once', () async {
      var running = 0, peak = 0;
      final tasks = [
        for (var i = 0; i < 20; i++)
          () => SovereigntyService.ripeLimitedForTest(() async {
                running++;
                if (running > peak) peak = running;
                await Future<void>.delayed(const Duration(milliseconds: 5));
                running--;
                return i;
              })
      ];
      await Future.wait(tasks.map((f) => f()));
      expect(peak, lessThanOrEqualTo(6));
    });
  });

  group('Task 9: certificate subject parsing (B28)', () {
    test('dart:io slash format keeps commas inside values', () {
      final p = ProbeService.parseX509String(
          '/C=US/ST=California/O=Example, Inc./CN=example.com');
      expect(p['Organization'], 'Example, Inc.');
      expect(p['Common Name'], 'example.com');
      expect(p['Country'], 'US');
    });

    test('RFC 4514 escaped comma', () {
      final p =
          ProbeService.parseX509String(r'CN=example.com,O=Example\, Inc.,C=US');
      expect(p['Organization'], 'Example, Inc.');
      expect(p['Country'], 'US');
    });

    test('RFC 4514 quoted value', () {
      final p =
          ProbeService.parseX509String('CN=example.com,O="Example, Inc.",C=US');
      expect(p['Organization'], 'Example, Inc.');
      expect(p['Common Name'], 'example.com');
    });

    test('hex escape and unknown keys survive', () {
      final p =
          ProbeService.parseX509String(r'O=A\2C B,1.3.6.1.4.1.311.60.2.1.3=NL');
      expect(p['Organization'], 'A, B');
      expect(p['1.3.6.1.4.1.311.60.2.1.3'], 'NL');
    });
  });

  group('Task 9: jurisdiction from a CDN certificate', () {
    test('CDN organisation: derived with a warning', () {
      final site = detectSiteJurisdiction(
          host: 'shop.com',
          certificateSubject: {
            'Country': 'US',
            'Organization': 'Cloudflare, Inc.'
          })!;
      expect(site.jurisdiction, 'US');
      expect(site.derived, isTrue);
      expect(site.warning, contains('may be the CDN'));
    });

    test('a normal organisation has no warning', () {
      final site = detectSiteJurisdiction(
          host: 'tweakers.net',
          certificateSubject: {
            'Country': 'BE',
            'Organization': 'DPG Media Group NV'
          })!;
      expect(site.warning, isNull);
    });

    test('issuer-looking CDN names are recognised', () {
      for (final o in [
        'Akamai Technologies',
        'Fastly, Inc.',
        'Amazon.com',
        'Google Trust Services LLC',
        'Microsoft Corporation'
      ]) {
        expect(
            detectSiteJurisdiction(
                    host: 'x.com',
                    certificateSubject: {'Country': 'US', 'Organization': o})!
                .warning,
            isNotNull,
            reason: o);
      }
    });
  });

  group('unknown is never 0 (10c)', () {
    SovereigntyReport report(List<SovereigntyCheck> checks,
            {List<HostInfo> hosts = const []}) =>
        SovereigntyReport(
          mainHost: 'a',
          hosts: hosts,
          cdn: null,
          nameServers: const [],
          mailServers: const [],
          tlsIssuer: null,
          tlsProvider: null,
          checks: checks,
        );

    test('nothing verifiable: no score and no grade, not "0 / Poor"', () {
      final r = report([
        const SovereigntyCheck(Pillar.security, 'c', CheckStatus.unknown, ''),
      ]);
      expect(r.score, isNull);
      expect(r.grade, isNull);
      expect(r.toJson()['score'], isNull);
      expect(r.toJson()['grade'], isNull);
    });

    test('a verified failing report really scores 0', () {
      final r = report([
        const SovereigntyCheck(Pillar.security, 'c', CheckStatus.fail, ''),
      ]);
      expect(r.score, 0);
      expect(r.grade, 'Poor');
    });

    test('host bytes: unknown stays null, known sums, mixed is partial', () {
      final hosts = SovereigntyService.collectHosts(
        pageUrl: 'https://a.test/',
        inspection: urlInspection(
          url: 'https://a.test/',
          serverResult: const Pending(),
          browserResult: browser(browserSnapshot(
            url: 'https://a.test/',
            dom: '',
            resources: [
              resource('https://cdn.test/a.js', 'script'),
              resource('https://cdn.test/b.js', 'script',
                  transfer: browser(100)),
              resource('https://img.test/c.png', 'img'),
              resource('https://ok.test/d.css', 'link', transfer: browser(50)),
              resource('https://ok.test/e.css', 'link', transfer: browser(25)),
            ],
          )),
        ),
        metadata: null,
      );
      HostInfo of(String h) => hosts.singleWhere((x) => x.host == h);
      expect(of('img.test').bytes, isNull);
      expect(of('img.test').bytesPartial, isFalse);
      expect(of('cdn.test').bytes, 100);
      expect(of('cdn.test').bytesPartial, isTrue);
      expect(of('ok.test').bytes, 75);
      expect(of('ok.test').bytesPartial, isFalse);
      expect(of('a.test').bytes, isNull); // the document itself: no size here
      expect(hosts.first.host, 'a.test');
    });
  });

  group('Audit fixes (V1-V15)', () {
    test('V1 DMARC reads the tag named exactly p', () {
      expect(classifyDmarc(['v=DMARC1; sp=none; p=reject']).$1,
          CheckStatus.pass);
      expect(classifyDmarc(['v=DMARC1; sp=reject']).$1, CheckStatus.fail);
    });

    test('V2 SPF per RFC 7208', () {
      expect(classifySpf(['v=spf1 include:foo-all.example ~all']).$1,
          CheckStatus.warn);
      final multi = classifySpf(['v=spf1 -all', 'v=spf1 ~all']);
      expect(multi.$1, CheckStatus.fail);
      expect(multi.$2, contains('Multiple SPF records'));
      expect(classifySpf(['v=spf1 redirect=_spf.example.com']).$1,
          CheckStatus.unknown);
      expect(classifySpf(['v=spf1x -all']).$2, 'No SPF record');
      expect(classifySpf(['V=SPF1 -all']).$1, CheckStatus.pass);
      expect(classifySpf(['v=spf1 ?all']).$1, CheckStatus.fail);
      expect(classifySpf(['v=spf1 all']).$1, CheckStatus.fail);
      expect(classifySpf(['v=spf1 mx ~all -all']).$1, CheckStatus.pass);
      final none = classifySpf(['v=spf1 mx']);
      expect(none.$1, CheckStatus.fail);
      expect(none.$2, contains('no all mechanism'));
    });

    test('V5 registrableDomain second-level labels and hosting suffixes', () {
      final cases = {
        'www.example.go.kr': 'example.go.kr',
        'www.example.or.kr': 'example.or.kr',
        'www.example.gob.mx': 'example.gob.mx',
        'www.example.gouv.fr': 'example.gouv.fr',
        'www.example.asso.fr': 'example.asso.fr',
        'www.example.nhs.uk': 'example.nhs.uk',
        'www.example.me.uk': 'example.me.uk',
        'www.example.ltd.uk': 'example.ltd.uk',
        'www.example.ac.jp': 'example.ac.jp',
        'x.example.s3.amazonaws.com': 'example.s3.amazonaws.com',
        'www.example.de': 'example.de',
      };
      cases.forEach((h, want) {
        expect(SovereigntyService.registrableDomain(h), want, reason: h);
      });
    });

    test('V6 provider patterns match whole words', () {
      for (final h in [
        'lawsociety.org.uk',
        'novhotels.com',
        'bunnyshop.nl',
        'oracleofbacon.org',
        'ionosphere.nl',
        'vercelli.it',
        'tencentral.nl',
        'azurelane.nl',
        'msftfans.nl',
      ]) {
        expect(matchProvider([h]), isNull, reason: h);
      }
      final real = {
        'ns-1582.awsdns-05.co.uk': 'Amazon (AWS)',
        'd111.cloudfront.net': 'Amazon (AWS)',
        'AMAZON-02': 'Amazon (AWS)',
        'bucket.s3.amazonaws.com': 'Amazon (AWS)',
        'CLOUDFLARENET': 'Cloudflare',
        'ns1.ovh.net': 'OVHcloud',
        'OVH SAS': 'OVHcloud',
        'HETZNER-AS': 'Hetzner',
        'aspmx.l.google.com': 'Google',
        'outlook-com.olc.protection.outlook.com': 'Microsoft',
        'Let\'s Encrypt': 'Let\'s Encrypt',
        'Sectigo Limited': 'Sectigo',
        'DigiCert Inc': 'DigiCert',
        'GlobalSign nv-sa': 'GlobalSign',
        'mail.protonmail.ch': 'Proton',
        'x.b-cdn.net': 'Bunny.net',
      };
      real.forEach((h, want) {
        expect(matchProvider([h])?.name, want, reason: h);
      });
    });

    test('V6 corrected provider countries', () {
      expect(matchProvider(['imperva'])?.country, 'FR');
      expect(matchProvider(['Sectigo Limited'])?.country, 'US');
      expect(matchProvider(['GlobalSign nv-sa'])?.country, 'JP');
    });

    test('V7 CDN header detection is strict', () {
      expect(
          detectCdnFromHeaders({'X-Served-By': 'varnish-01', 'X-Cache': 'HIT'}),
          isNull);
      expect(detectCdnFromHeaders({'x-fastly-request-id': 'a'})?.name,
          'Fastly');
      expect(
          detectCdnFromHeaders({
            'x-served-by': 'cache-ams21-AMS',
            'x-cache': 'HIT',
            'via': '1.1 varnish',
          })?.name,
          'Fastly');
      expect(detectCdnFromHeaders({'Via': '1.1 varnish'}), isNull);
      expect(detectCdnFromHeaders({'Server': 'nginx-gwsomething'}), isNull);
      expect(detectCdnFromHeaders({'Server': 'gws'})?.name, 'Google');
      expect(detectCdnFromHeaders({'x-goog-generation': '1'})?.name, 'Google');
      expect(detectCdnFromHeaders({'x-amz-request-id': 'abc'}), isNull);
      expect(detectCdnFromHeaders({'Server': 'AmazonS3'}), isNull);
      expect(detectCdnFromHeaders({'x-amz-cf-id': 'abc'})?.name,
          'Amazon (AWS)');
      expect(detectCdnFromHeaders({'Via': '1.1 x.cloudfront.net (CloudFront)'})
          ?.name, 'Amazon (AWS)');
    });

    test('V9 no response headers: CDN check is unknown, not pass', () async {
      final r = await SovereigntyService.analyze(
        pageUrl: '',
        inspection: const PageInspection.empty(),
        detections: const [],
        html: '',
      );
      final c = r.checks.firstWhere((c) => c.title.startsWith('CDN / proxy'));
      expect(c.status, CheckStatus.unknown);
      expect(c.weight, 3);
    });

    test('V11 residency: low located share is unknown; truncation stated', () {
      HostInfo h(String n, {String? ip, int r = 1}) => HostInfo(n)
        ..requests = r
        ..ipCountry = ip;
      Iterable<SovereigntyCheck> res(List<HostInfo> hs, {int? total}) =>
          SovereigntyService.residencyChecks(hs, null, eu, totalHosts: total);
      SovereigntyCheck req(List<HostInfo> hs, {int? total}) => res(hs,
              total: total)
          .firstWhere((c) => c.title.startsWith('Requests served'));

      final low = req([h('a', ip: 'NL'), for (var i = 0; i < 9; i++) h('b$i')]);
      expect(low.status, CheckStatus.unknown);
      expect(low.evidence, contains('10%'));

      final ok = req([h('a', ip: 'NL'), h('b', ip: 'DE')]);
      expect(ok.status, CheckStatus.pass);

      final cut = req([for (var i = 0; i < 40; i++) h('h$i', ip: 'NL')],
          total: 55);
      expect(cut.evidence, contains('first 40 of 55'));
      expect(ok.evidence, isNot(contains('first 40')));
    });

    test('V14 findPrivacyLink ignores non-pages', () {
      expect(findPrivacyLink('<a href="#" id="x">Cookie settings</a>'), isNull);
      expect(findPrivacyLink('<a href="#privacy">Privacy</a>'), isNull);
      expect(findPrivacyLink('<a href="javascript:void(0)">Privacy</a>'),
          isNull);
      expect(findPrivacyLink('<a href="/cookiebar.js">x</a>'), isNull);
      expect(findPrivacyLink('<a href="/privacy.css">x</a>'), isNull);
      expect(findPrivacyLink('<a href="/cookies">Cookies</a>'), isNull);
      expect(findPrivacyLink('<a href="/c">Cookie policy</a>'), '/c');
      expect(findPrivacyLink('<a href="/cookiebeleid">x</a>'),
          '/cookiebeleid');
      expect(findPrivacyLink('<a href="/cookieverklaring">x</a>'),
          '/cookieverklaring');
      expect(findPrivacyLink('<a href=/privacy>Privacy</a>'), '/privacy');
      expect(findPrivacyLink('<a href=/privacy >Privacy</a>'), '/privacy');
      expect(findPrivacyLink("<a\nhref='/privacy'>P</a>"), '/privacy');
    });

    test('V15 trackers are counted once', () async {
      Detection d(String name) => Detection(entityNamed(name)!);
      final ga = d('Google Analytics');
      final r = await SovereigntyService.analyze(
        pageUrl: '',
        inspection: const PageInspection.empty(),
        detections: [ga, ga, ga],
        html: '',
      );
      final c = r.checks.firstWhere((c) => c.title == 'Number of trackers');
      expect(c.status, CheckStatus.warn, reason: c.evidence);
      expect(c.evidence, 'Google Analytics');
    });

    test('Google Fonts evidence cites the LG München I ruling', () {
      final c = SovereigntyService.privacyChecks(
        [HostInfo('fonts.googleapis.com')],
        const [],
        null,
        eu,
      ).firstWhere((c) => c.title.startsWith('Fonts'));
      expect(c.evidence, contains('LG München I (20 Jan 2022, 3 O 17493/20)'));
    });
  });

  test('whole-word provider patterns still know compound tracker hosts', () {
    for (final (host, name) in [
      ('www.googletagmanager.com', 'Google'),
      ('pagead2.googlesyndication.com', 'Google'),
      ('www.googleadservices.com', 'Google'),
      ('rr3---sn-5hne6nsr.googlevideo.com', 'Google'),
      ('www.google-analytics.com', 'Google'),
      ('scontent.cdninstagram.com', 'Meta'),
      ('connect.facebook.net', 'Meta'),
      ('static.cloudflareinsights.com', 'Cloudflare'),
      ('a248.e.akamaihd.net', 'Akamai'),
    ]) {
      expect(matchProvider([host])?.name, name, reason: host);
    }
  });
}
