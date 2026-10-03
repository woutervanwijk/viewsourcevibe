import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
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
    test('classifies countries', () {
      expect(jurisdictionFor('NL'), Jurisdiction.eu);
      expect(jurisdictionFor('NO'), Jurisdiction.eu);
      expect(jurisdictionFor('US'), Jurisdiction.us);
      expect(jurisdictionFor('CN'), Jurisdiction.other);
      expect(jurisdictionFor(null), Jurisdiction.unknown);
    });

    test('company HQ wins over IP location and flags CLOUD Act', () {
      final host = HostInfo('x.example')
        ..ipCountry = 'DE'
        ..provider = matchProvider(['cloudfront.net']);
      expect(host.jurisdiction, Jurisdiction.us);
      expect(host.cloudActRisk, isTrue);

      final eu = HostInfo('y.example')
        ..ipCountry = 'DE'
        ..provider = matchProvider(['hetzner']);
      expect(eu.jurisdiction, Jurisdiction.eu);
      expect(eu.cloudActRisk, isFalse);
    });

    test('share sums to 1 per weight', () {
      final report = SovereigntyReport(
        mainHost: 'a',
        hosts: [
          HostInfo('a')
            ..requests = 3
            ..ipCountry = 'NL',
          HostInfo('b')
            ..requests = 1
            ..ipCountry = 'US',
        ],
        cdn: null,
        nameServers: const [],
        mailServers: const [],
        tlsIssuer: null,
        tlsProvider: null,
        notes: const [],
      );
      final share = report.share((h) => h.requests);
      expect(share[Jurisdiction.eu], 0.75);
      expect(share[Jurisdiction.us], 0.25);
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
      expect(SovereigntyService.parseDnsNames(data, 2),
          ['ns-311.awsdns-38.com', 'ns-823.awsdns-38.com']);
    });

    test('tolerates garbage', () {
      expect(SovereigntyService.parseDnsNames(Uint8List(3), 2), isEmpty);
    });
  });

  test('registrable domain', () {
    expect(SovereigntyService.registrableDomain('www.nos.nl'), 'nos.nl');
    expect(SovereigntyService.registrableDomain('a.b.bbc.co.uk'), 'bbc.co.uk');
    expect(SovereigntyService.registrableDomain('nos.nl'), 'nos.nl');
  });
}
