import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/certificate_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CertificateSecurityService.resetSessionTrust();
  });

  group('CertificateSecurityService', () {
    test('rejects untrusted hosts by default', () {
      expect(
        CertificateSecurityService.isHostTrustedThisSession('example.com'),
        isFalse,
      );
    });

    test('default callback is strict for unknown hosts', () {
      final callback = CertificateSecurityService.defaultBadCertificateCallback;
      expect(callback(_FakeCert(), 'example.com', 443), isFalse);
    });

    test('per-session trust is never persisted across resets', () async {
      // Simulate a user accepting a host for this session by using the prompt
      // path with no UI available: it must fail closed (return false).
      final accepted = await CertificateSecurityService.requestTrustForHost(
        'example.com',
        null,
      );
      expect(accepted, isFalse);
      expect(
        CertificateSecurityService.isHostTrustedThisSession('example.com'),
        isFalse,
      );
    });

    test('withCertificatePrompt rethrows non-TLS errors', () async {
      expect(
        () => CertificateSecurityService.withCertificatePrompt(
          'example.com',
          () async => throw const SocketException('connection refused'),
        ),
        throwsA(isA<SocketException>()),
      );
    });

    test('withCertificatePrompt rethrows TLS errors when declined (no UI)', () async {
      expect(
        () => CertificateSecurityService.withCertificatePrompt(
          'example.com',
          () async => throw HandshakeException('bad certificate'),
        ),
        throwsA(isA<HandshakeException>()),
      );
      expect(
        CertificateSecurityService.isHostTrustedThisSession('example.com'),
        isFalse,
      );
    });
  });
}

class _FakeCert implements X509Certificate {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
