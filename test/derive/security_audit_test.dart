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
        'strict-transport-security': ['max-age=31536000'],
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

    test('http: HSTS stays applicable and fails', () {
      final a = audit(page({}, url: 'http://a.test/'));
      final hsts = a.checks.singleWhere((c) => c.label == 'HSTS');
      expect(hsts.applicable, isTrue);
      expect(a.total, 6);
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

  group('audit validates values', () {
    bool passes(Map<String, List<String>> h, String label,
            {String url = 'https://a.test/'}) =>
        audit(page(h, url: url))
            .checks
            .firstWhere((c) => c.label == label)
            .passing;
    String detail(Map<String, List<String>> h, String label) =>
        audit(page(h)).checks.firstWhere((c) => c.label == label).detail;

    test('HSTS needs max-age >= 6 months', () {
      expect(
          passes({
            'strict-transport-security': ['max-age=0']
          }, 'HSTS'),
          isFalse);
      expect(
          detail({
            'strict-transport-security': ['max-age=60']
          }, 'HSTS'),
          contains('60'));
      expect(
          passes({
            'strict-transport-security': ['max-age=15552000']
          }, 'HSTS'),
          isTrue);
      expect(
          passes({
            'strict-transport-security': ['includeSubDomains; max-age=31536000']
          }, 'HSTS'),
          isTrue);
      expect(
          passes({
            'strict-transport-security': ['includeSubDomains']
          }, 'HSTS'),
          isFalse);
    });

    test('Referrer-Policy: last recognised token, unsafe values fail', () {
      for (final v in ['unsafe-url', 'no-referrer-when-downgrade']) {
        expect(
            passes({
              'referrer-policy': [v]
            }, 'Referrer'),
            isFalse,
            reason: v);
      }
      for (final v in [
        'no-referrer',
        'same-origin',
        'strict-origin',
        'strict-origin-when-cross-origin',
        'origin',
        'origin-when-cross-origin',
        'unsafe-url, strict-origin',
      ]) {
        expect(
            passes({
              'referrer-policy': [v]
            }, 'Referrer'),
            isTrue,
            reason: v);
      }
      expect(
          passes({
            'referrer-policy': ['no-referrer, unsafe-url']
          }, 'Referrer'),
          isFalse);
      expect(
          passes({
            'referrer-policy': ['bogus']
          }, 'Referrer'),
          isFalse);
    });

    test('Frames: DENY/SAMEORIGIN (any case) or frame-ancestors', () {
      expect(
          passes({
            'x-frame-options': ['ALLOWALL']
          }, 'Frames'),
          isFalse);
      expect(
          passes({
            'x-frame-options': ['deny']
          }, 'Frames'),
          isTrue);
      expect(
          passes({
            'x-frame-options': ['SameOrigin']
          }, 'Frames'),
          isTrue);
      expect(
          passes({
            'content-security-policy': ["frame-ancestors 'self'"]
          }, 'Frames'),
          isTrue);
    });

    test('CSP needs default-src or script-src', () {
      expect(
          passes({
            'content-security-policy': ['upgrade-insecure-requests']
          }, 'CSP'),
          isFalse);
      expect(
          passes({
            'content-security-policy': ["script-src 'self'"]
          }, 'CSP'),
          isTrue);
      expect(
          passes({
            'content-security-policy': ["default-src 'self'"]
          }, 'CSP'),
          isTrue);
    });

    test('plain HTTP: HSTS applies and fails, never 100%', () {
      final a = audit(page({
        'content-security-policy': ["default-src 'none'"],
        'x-frame-options': ['DENY'],
        'x-content-type-options': ['nosniff'],
        'referrer-policy': ['no-referrer'],
        'permissions-policy': ['camera=()'],
      }, url: 'http://a.test/'));
      final hsts = a.checks.singleWhere((c) => c.label == 'HSTS');
      expect(hsts.applicable, isTrue);
      expect(hsts.passing, isFalse);
      expect(hsts.detail, contains('not served over HTTPS'));
      expect(a.percentage, lessThan(100));
    });

    test('nosniff: first comma value, case-insensitive', () {
      expect(
          passes({
            'x-content-type-options': ['nosniff, nosniff']
          }, 'No Sniff'),
          isTrue);
      expect(
          passes({
            'x-content-type-options': ['NoSniff']
          }, 'No Sniff'),
          isTrue);
      expect(
          passes({
            'x-content-type-options': ['nonsniff-nosniffx']
          }, 'No Sniff'),
          isFalse);
      expect(
          passes({
            'x-content-type-options': ['other, nosniff']
          }, 'No Sniff'),
          isFalse);
    });
  });

  group('csp findings', () {
    CspModel csp(Map<String, List<String>> h) =>
        (security(page(h)).csp as Present<CspModel>).value;
    Map<String, List<String>> cspH(String v) => {
          'content-security-policy': [v]
        };
    bool has(CspModel m, CspSeverity s, String sub) => m.policies.first.findings
        .any((f) => f.severity == s && f.text.contains(sub));
    const tail = "object-src 'none'; base-uri 'none'; frame-ancestors 'none'";

    test('unsafe-inline with nonce/hash/strict-dynamic is only low', () {
      for (final src in [
        "'unsafe-inline' 'nonce-abc'",
        "'unsafe-inline' 'sha256-x'",
        "'unsafe-inline' 'strict-dynamic'"
      ]) {
        final m = csp(cspH('script-src $src; $tail'));
        expect(has(m, CspSeverity.high, 'unsafe-inline'), isFalse, reason: src);
        expect(has(m, CspSeverity.low, 'old browsers'), isTrue, reason: src);
      }
      expect(
          has(csp(cspH("script-src 'unsafe-inline'; $tail")), CspSeverity.high,
              'unsafe-inline'),
          isTrue);
    });

    test("object-src falls back to default-src 'none'", () {
      final m = csp(
          cspH("default-src 'none'; base-uri 'none'; frame-ancestors 'none'"));
      expect(has(m, CspSeverity.medium, 'object-src'), isFalse);
      expect(
          has(csp(cspH("default-src 'self'; base-uri 'none'")),
              CspSeverity.medium, 'object-src'),
          isTrue);
    });

    for (final src in ['https:', 'http:', 'data:', '*.example.com', '*']) {
      test('script-src $src is a wildcard finding', () {
        final m = csp(cspH('script-src $src; $tail'));
        expect(has(m, CspSeverity.medium, 'Wildcard'), isTrue);
      });
    }

    test('duplicate directive: first wins', () {
      final m =
          csp(cspH("script-src 'self'; script-src 'unsafe-inline'; $tail"));
      expect(has(m, CspSeverity.high, 'unsafe-inline'), isFalse);
    });

    test('missing frame-ancestors is low when X-Frame-Options covers it', () {
      CspModel withXfo(String? xfo) => (security(page({
            'content-security-policy': ["default-src 'self'"],
            if (xfo != null) 'x-frame-options': [xfo],
          })).csp as Present<CspModel>)
              .value;
      expect(has(withXfo('DENY'), CspSeverity.low, 'frame-ancestors'), isTrue);
      expect(
          has(withXfo('DENY'), CspSeverity.medium, 'frame-ancestors'), isFalse);
      expect(has(withXfo(null), CspSeverity.medium, 'frame-ancestors'), isTrue);
    });
  });

  group('certificate host (SAN not collected)', () {
    CertificateModel certOf(Map<String, dynamic> c) =>
        (security(page({}, certificate: server(c)),
                    now: DateTime.utc(2026, 1, 1))
                .certificate as Present<CertificateModel>)
            .value;

    test('a CN mismatch says SAN was not checked', () {
      final c = certOf({
        'subjectParsed': {'Common Name': 'Some Org'},
        'issuerParsed': {},
        'endValidity': '2027-01-01T00:00:00Z',
      });
      expect(c.hostMatches, isFalse);
      expect(c.hostLabel, 'CN differs from host (SAN not checked)');
    });
  });
}
