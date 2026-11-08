import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/collectors/server_fetcher.dart';
import 'package:view_source_vibe/services/derive/security_audit.dart';

import '../fixtures/inspection/builders.dart';
import '../fixtures/inspection/full_page.dart';
import '../fixtures/inspection/local_file.dart';

SecurityModel security(PageInspection p, {DateTime? now}) =>
    (deriveSecurity(p, now: now) as Present<SecurityModel>).value;

SecurityAudit audit(PageInspection p) =>
    (security(p).audit as Present<SecurityAudit>).value;

PageInspection page(
  Map<String, List<String>> headers, {
  String url = 'https://a.test/',
  Observed<Map<String, dynamic>>? certificate,
  bool invalidCert = false,
}) {
  final h = HttpHop(
    url: Uri.parse(url),
    statusCode: 200,
    reasonPhrase: 'OK',
    headers: headers,
    setCookies: const [],
    remoteAddress: server('1.2.3.4'),
    certificate:
        certificate ?? const Unavailable(UnavailableReason.notApplicable),
  );
  final snap = ServerSnapshot(
    requestedUrl: Uri.parse(url),
    userAgent: kServerUserAgent,
    hops: [h],
    finalUrl: server(Uri.parse(url)),
    body: serverSnapshot(url: url, hops: [h], body: 'x').body,
    timingMs: server(5),
    certificate:
        certificate ?? const Unavailable(UnavailableReason.notApplicable),
    acceptedInvalidCertificate: invalidCert,
  );
  return urlInspection(
      url: url, serverResult: server(snap), browserResult: const Pending());
}

void main() {
  group('gate', () {
    test('local file', () {
      final o = deriveSecurity(localFile());
      expect((o as Unavailable).detail, contains('local file'));
    });
  });

  group('score only from a present response', () {
    for (final s in <Observed<ServerSnapshot>>[
      const Pending(),
      const Failed('network error: boom'),
    ]) {
      test('${s.runtimeType}: no score, no checks, no 0%', () {
        final m = security(fullPage().copyWith(server: s));
        expect(m.audit, isNot(isA<Present<SecurityAudit>>()));
        expect(m.certificate, isNot(isA<Present<CertificateModel>>()));
        expect(m.csp, isNot(isA<Present<CspModel>>()));
      });
    }
  });

  group('checks', () {
    test('everything missing on https: 0 of 5 applicable, honest', () {
      final a = audit(page({}));
      expect(a.total, 6);
      expect(a.passed, 0);
      expect(a.percentage, 0);
      expect(a.rows.every((r) => r.value == null), isTrue);
    });

    test('a good set', () {
      final a = audit(page({
        'strict-transport-security': ['max-age=1'],
        'content-security-policy': [
          "default-src 'self'; frame-ancestors 'none'"
        ],
        'x-content-type-options': ['nosniff'],
        'referrer-policy': ['no-referrer'],
        'permissions-policy': ['camera=()'],
      }));
      expect(a.passed, 6);
      expect(a.percentage, 100);
      expect(a.checks.singleWhere((c) => c.label == 'Frames').passing, isTrue);
    });

    test('http: HSTS is not applicable and not counted', () {
      final a = audit(page({}, url: 'http://a.test/'));
      final hsts = a.checks.singleWhere((c) => c.label == 'HSTS');
      expect(hsts.applicable, isFalse);
      expect(a.total, 5);
    });

    test('rows show the value as sent', () {
      final a = audit(page({
        'x-frame-options': ['DENY']
      }));
      final r = a.rows.singleWhere((r) => r.name == 'X-Frame-Options');
      expect(r.value, 'DENY');
    });
  });

  group('csp', () {
    CspModel csp(Map<String, List<String>> h) =>
        (security(page(h)).csp as Present<CspModel>).value;

    test('no header: no policy, no score', () {
      final c = csp({});
      expect(c.policies, isEmpty);
      expect(c.score, isNull);
    });

    test('findings and score', () {
      final c = csp({
        'content-security-policy': ["script-src 'unsafe-inline' *"]
      });
      expect(c.policies.single.findings.map((f) => f.text),
          contains("script-src allows 'unsafe-inline'."));
      expect(c.score, lessThan(100));
      expect(c.policies.single.directives.single, ('script-src', 2));
    });

    test('two policies are judged one by one', () {
      final c = csp({
        'content-security-policy': [
          "default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'",
          "script-src 'unsafe-eval'"
        ]
      });
      expect(c.policies, hasLength(2));
      expect(c.score,
          c.policies.map((p) => p.score).reduce((a, b) => a < b ? a : b));
    });
  });

  group('certificate', () {
    final cert = <String, dynamic>{
      'subjectParsed': {'Common Name': '*.a.test', 'Organization': 'A Inc'},
      'issuerParsed': {'Organization': 'Let\'s Encrypt'},
      'subject': 'raw-subject',
      'issuer': 'raw-issuer',
      'startValidity': '2026-01-01T00:00:00.000Z',
      'endValidity': '2026-12-31T00:00:00.000Z',
      'der': 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
      'pem': '-----BEGIN-----',
    };

    CertificateModel certOf(PageInspection p, {DateTime? now}) =>
        (security(p, now: now).certificate as Present<CertificateModel>).value;

    test('fields of the final hop', () {
      final c = certOf(
          page({}, url: 'https://www.a.test/', certificate: server(cert)),
          now: DateTime.utc(2026, 6, 1));
      expect(c.validityLabel, startsWith('Valid for '));
      expect(c.validityTone, CertTone.good);
      expect(c.hostLabel, 'CN matches host');
      expect(c.validFrom, '2026-01-01 00:00');
      expect(c.derHint, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345');
      expect(c.pem, '-----BEGIN-----');
      expect(c.subject['Organization'], 'A Inc');
    });

    test('expired and expiring', () {
      expect(
          certOf(page({}, certificate: server(cert)),
                  now: DateTime.utc(2027, 1, 10))
              .validityLabel,
          startsWith('Expired '));
      expect(
          certOf(page({}, certificate: server(cert)),
                  now: DateTime.utc(2026, 12, 25))
              .validityTone,
          CertTone.bad);
    });

    test('no common name is unknown, not "differs"', () {
      final c = certOf(
          page({}, certificate: server({...cert, 'subjectParsed': {}})),
          now: DateTime.utc(2026, 6, 1));
      expect(c.hostLabel, 'Common name unknown');
    });

    test('unparsable validity is unknown', () {
      final c =
          certOf(page({}, certificate: server({...cert, 'endValidity': ''})));
      expect(c.validityLabel, 'Validity unknown');
      expect(c.validUntil, 'Unknown');
    });

    test('http page: unavailable with a clear reason', () {
      final m = security(page({}, url: 'http://a.test/'));
      expect(m.certificate, isA<Unavailable<CertificateModel>>());
      expect((m.certificate as Unavailable).detail, contains('HTTP'));
    });

    test('a failed certificate read keeps its reason', () {
      final m = security(page({},
          certificate: const Unavailable(
              UnavailableReason.notReportedByPlatform, 'no peer certificate')));
      expect((m.certificate as Unavailable).detail, 'no peer certificate');
    });
  });

  group('tls warning', () {
    test('accepted invalid certificate on https', () {
      expect(security(page({}, invalidCert: true)).tlsWarning,
          contains('TLS certificate validation failed'));
      expect(security(page({})).tlsWarning, isNull);
      expect(
          security(page({}, url: 'http://a.test/', invalidCert: true))
              .tlsWarning,
          isNull);
    });
  });
}
