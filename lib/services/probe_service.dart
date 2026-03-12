import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ProbeService {
  static Future<Map<String, dynamic>> probeUrl(String url) async {
    HttpClient? client;
    try {
      String targetUrl = url.trim();
      if (!targetUrl.contains('://') && !targetUrl.startsWith('about:') && !targetUrl.startsWith('data:')) {
        targetUrl = 'https://$targetUrl';
      }

      final uri = Uri.parse(targetUrl);
      client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      client.connectionTimeout = const Duration(seconds: 10);

      final stopwatch = Stopwatch()..start();
      String? ipAddress;

      if (uri.host.isNotEmpty) {
        try {
          final addresses = await InternetAddress.lookup(uri.host).timeout(const Duration(seconds: 2));
          if (addresses.isNotEmpty) {
            ipAddress = addresses.first.address;
          }
        } catch (e) {
          debugPrint('DNS Lookup failed for ${uri.host}: $e');
        }
      }

      const userAgent = 'curl/7.88.1';
      HttpClientRequest request;
      HttpClientResponse response;

      try {
        request = await client.openUrl('HEAD', uri);
        request.headers.set('User-Agent', userAgent);
        request.headers.set('Accept', '*/*');
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 15));
      } catch (e) {
        request = await client.openUrl('GET', uri);
        request.headers.set('User-Agent', userAgent);
        request.headers.set('Accept', '*/*');
        request.headers.set('Range', 'bytes=0-0');
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 15));
      }

      Map<String, dynamic>? certInfo;
      try {
        if (response.certificate != null) {
          certInfo = extractCertificateInfo(response.certificate!);
        }
      } catch (e) {
        debugPrint('Could not read SSL certificate: $e');
      }

      stopwatch.stop();

      try {
        await response.drain().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Response drain timed out or failed: $e');
      }

      int? contentLength = response.contentLength;
      if (contentLength <= 0) {
        final lengthHeader = response.headers.value('content-length');
        if (lengthHeader != null) {
          contentLength = int.tryParse(lengthHeader) ?? 0;
        } else {
          contentLength = 0;
        }
      }

      final normalizedHeaders = <String, String>{};
      final List<String> serverCookies = [];
      response.headers.forEach((key, values) {
        final lowerKey = key.toLowerCase();
        if (lowerKey == 'set-cookie') {
          serverCookies.addAll(values);
        } else {
          normalizedHeaders[lowerKey] = values.join(', ');
        }
      });

      final securityHeaders = {
        'Strict-Transport-Security': normalizedHeaders['strict-transport-security'],
        'Content-Security-Policy': normalizedHeaders['content-security-policy'],
        'X-Frame-Options': normalizedHeaders['x-frame-options'],
        'X-Content-Type-Options': normalizedHeaders['x-content-type-options'],
        'Referrer-Policy': normalizedHeaders['referrer-policy'],
        'Permissions-Policy': normalizedHeaders['permissions-policy'],
      };

      return {
        'statusCode': response.statusCode,
        'reasonPhrase': response.reasonPhrase,
        'headers': normalizedHeaders,
        'isRedirect': response.isRedirect,
        'contentLength': contentLength,
        'url': url,
        'finalUrl': url,
        'ip': ipAddress,
        'ipAddress': ipAddress,
        'timing': {
          'total': stopwatch.elapsedMilliseconds,
        },
        'responseTime': stopwatch.elapsedMilliseconds,
        'security': securityHeaders,
        'cookies': serverCookies,
        'certificate': certInfo,
        'analyzedCookies': <Map<String, dynamic>>[],
      };
    } catch (e) {
      debugPrint('Error probing URL $url: $e');
      rethrow;
    } finally {
      client?.close(force: true);
    }
  }

  static Map<String, dynamic> extractCertificateInfo(X509Certificate cert) {
    try {
      return {
        'subject': cert.subject,
        'subjectParsed': parseX509String(cert.subject),
        'issuer': cert.issuer,
        'issuerParsed': parseX509String(cert.issuer),
        'validFrom': cert.startValidity.toIso8601String(),
        'startValidity': cert.startValidity.toIso8601String(),
        'validTo': cert.endValidity.toIso8601String(),
        'endValidity': cert.endValidity.toIso8601String(),
        'der': base64Encode(cert.der),
        'pem': convertToPem(cert.der),
      };
    } catch (e) {
      debugPrint('Error extracting certificate info: $e');
      return {'error': e.toString()};
    }
  }

  static Map<String, String> parseX509String(String x509) {
    final Map<String, String> labels = {
      'CN': 'Common Name',
      'O': 'Organization',
      'OU': 'Organizational Unit',
      'C': 'Country',
      'L': 'Locality',
      'ST': 'State/Province',
      'E': 'Email',
      'SERIALNUMBER': 'Serial Number',
    };

    final Map<String, String> parsed = {};
    final parts = x509.split(RegExp(r'[/,]\s*'));
    for (var part in parts) {
      if (part.contains('=')) {
        final kv = part.split('=');
        if (kv.length >= 2) {
          final key = kv[0].trim().toUpperCase();
          final value = kv.sublist(1).join('=').trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            parsed[labels[key] ?? key] = value;
          }
        }
      }
    }
    return parsed;
  }

  static String convertToPem(List<int> der) {
    final base64String = base64Encode(der);
    final chunks = <String>[];
    for (var i = 0; i < base64String.length; i += 64) {
      final end = (i + 64 > base64String.length) ? base64String.length : i + 64;
      chunks.add(base64String.substring(i, end));
    }
    return '-----BEGIN CERTIFICATE-----\n${chunks.join('\n')}\n-----END CERTIFICATE-----';
  }

  static String categorizeResource(String name, String pageUrl) {
    name = name.toLowerCase();
    pageUrl = pageUrl.toLowerCase();

    if (name.endsWith('.js') || name.contains('.js?') || name.contains('.js#') || name.contains('script')) {
      return 'script';
    }
    if (name.endsWith('.css') || name.contains('.css?') || name.contains('.css#') || name.contains('style')) {
      return 'style';
    }
    if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.gif') ||
        name.endsWith('.webp') || name.endsWith('.svg') || name.endsWith('.ico') || name.endsWith('.avif') ||
        name.contains('image/') || name.contains('img_') || name.contains('/images/')) {
      return 'image';
    }
    if (name == pageUrl || name == '$pageUrl/' || name.endsWith('.html') || name.endsWith('.htm') ||
        name.contains('document') || (!name.contains('.') && name.startsWith('http'))) {
      return 'document';
    }
    return 'other';
  }
}
