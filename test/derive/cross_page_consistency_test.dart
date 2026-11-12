// The same response must lead to the same verdict on every page that
// judges it: Security, Headers and Sovereignty.
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/header_insights.dart';
import 'package:view_source_vibe/services/derive/security_audit.dart';
import 'package:view_source_vibe/services/sovereignty_service.dart';

import '../fixtures/inspection/builders.dart';

PageInspection _page(Map<String, List<String>> headers,
    {String url = 'https://a.test/'}) {
  final snap = serverSnapshot(
      url: url, hops: [hop(url, 200, headers: headers)], body: 'x');
  return urlInspection(
      url: url, serverResult: server(snap), browserResult: const Pending());
}

bool _auditPasses(PageInspection p, String label) {
  final s = (deriveSecurity(p) as Present<SecurityModel>).value;
  return (s.audit as Present<SecurityAudit>)
      .value
      .checks
      .firstWhere((c) => c.label == label)
      .passing;
}

CheckStatus _sovereigntyHsts(PageInspection p) =>
    SovereigntyService.securityChecks(
            txt: const [],
            dmarc: const [],
            caa: const [],
            ds: const [],
            securityTxt: null,
            server: SovereigntyService.serverOf(p))
        .firstWhere((c) => c.title.startsWith('HSTS'))
        .status;

HeadersModel _headers(PageInspection p) =>
    (deriveHeaders(p) as Present<HeadersModel>).value;

void main() {
  group('HSTS: Security score and Sovereignty agree', () {
    for (final (value, url, passes) in [
      ('max-age=31536000', 'https://a.test/', true),
      ('max-age=0', 'https://a.test/', false),
      ('max-age=60', 'https://a.test/', false),
      (null, 'https://a.test/', false),
      ('max-age=31536000', 'http://a.test/', false),
    ]) {
      test('$value on $url', () {
        final p = _page({
          if (value != null) 'strict-transport-security': [value],
        }, url: url);
        expect(_auditPasses(p, 'HSTS'), passes);
        expect(_sovereigntyHsts(p) == CheckStatus.pass, passes);
      });
    }
  });

  test('nosniff: Security score and Headers notes agree', () {
    for (final (value, ok) in [
      ('nosniff', true),
      ('nosniff, nosniff', true),
      ('nonsniff-nosniffx', false),
    ]) {
      final p = _page({
        'x-content-type-options': [value]
      });
      final warned = _headers(p).notes.any((n) => n.text.contains('nosniff'));
      expect(_auditPasses(p, 'No Sniff'), ok, reason: value);
      expect(warned, !ok, reason: value);
    }
  });

  test('CDN: Headers insight names the same CDN as Sovereignty', () {
    for (final h in <Map<String, List<String>>>[
      {
        'x-vercel-id': ['fra1::abc']
      },
      {
        'x-nf-request-id': ['01H']
      },
      {
        'cf-ray': ['8a-AMS']
      },
      {
        'x-amz-cf-id': ['abc'],
        'via': ['1.1 abc.cloudfront.net (CloudFront)']
      },
      {
        'x-akamai-transformed': ['9 - 0 pmb=mRUM,1']
      },
    ]) {
      final flat = h.map((k, v) => MapEntry(k, v.join(', ')));
      final cdn =
          _headers(_page(h)).insights.firstWhere((i) => i.id == InsightId.cdn);
      expect(cdn.label, detectCdnFromHeaders(flat)!.name, reason: '$h');
    }
  });
}
