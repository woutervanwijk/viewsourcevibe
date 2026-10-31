import 'dart:io';

import 'package:flutter/material.dart';
import 'package:view_source_vibe/main.dart';

/// Per-session TLS certificate trust handling.
///
/// Invalid certificates are rejected by default. A user can explicitly accept
/// an invalid certificate for a single host for the remainder of the app
/// session. Trust decisions are kept in memory only and are never persisted.
class CertificateSecurityService {
  static final Set<String> _sessionTrustedHosts = <String>{};

  /// Default [HttpClient.badCertificateCallback]: strict, unless the user
  /// explicitly accepted the certificate for this host during this session.
  static bool defaultBadCertificateCallback(
    X509Certificate cert,
    String host,
    int port,
  ) {
    return isHostTrustedThisSession(host);
  }

  static bool isHostTrustedThisSession(String host) {
    return _sessionTrustedHosts.contains(host.toLowerCase());
  }

  /// Forget all per-session trust decisions.
  static void resetSessionTrust() {
    _sessionTrustedHosts.clear();
  }

  /// Ask the user whether to accept an invalid certificate for [host] for the
  /// rest of this session only. Returns true when accepted. When no UI is
  /// available (headless/tests) it returns false, keeping the safe default.
  static Future<bool> requestTrustForHost(
    String host,
    X509Certificate? cert,
  ) async {
    final context = MyApp.navigatorKey.currentContext;
    if (context == null || !context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final subject = cert != null ? _certificateSubject(cert) : '';
        return AlertDialog(
          title: const Text('Onveilig certificaat'),
          content: Text(
            'De server "$host" presenteerde een certificaat dat niet wordt '
            'vertrouwd door dit apparaat.\n\n'
            '${subject.isNotEmpty ? '$subject\n\n' : ''}'
            'Wil je dit onveilige certificaat accepteren voor "$host" '
            'gedurende de rest van deze sessie?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Accepteren (alleen deze sessie)'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _sessionTrustedHosts.add(host.toLowerCase());
      return true;
    }
    return false;
  }

  /// Run [operation]. When it fails because of an untrusted certificate, ask
  /// the user once and retry the operation. Any other error, or a declined
  /// prompt, is rethrown.
  static Future<T> withCertificatePrompt<T>(
    String host,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on HandshakeException catch (e) {
      final accepted =
          await requestTrustForHost(host, _extractCertificate(e));
      if (!accepted) rethrow;
      return await operation();
    } on CertificateException catch (e) {
      final accepted =
          await requestTrustForHost(host, _extractCertificate(e));
      if (!accepted) rethrow;
      return await operation();
    }
  }

  static X509Certificate? _extractCertificate(dynamic error) {
    try {
      final dynamic cert = error.certificate;
      return cert is X509Certificate ? cert : null;
    } catch (_) {
      return null;
    }
  }

  static String _certificateSubject(X509Certificate cert) {
    try {
      return 'Certificaat: ${cert.subject}';
    } catch (_) {
      return '';
    }
  }
}
