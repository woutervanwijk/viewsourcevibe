import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ProbeService {
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
    for (final part in _splitDistinguishedName(x509)) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      final key = part.substring(0, eq).trim().toUpperCase();
      final value = _unquoteDnValue(part.substring(eq + 1).trim());
      if (key.isNotEmpty && value.isNotEmpty) {
        parsed[labels[key] ?? key] = value;
      }
    }
    return parsed;
  }

  /// Splits a distinguished name into `KEY=value` parts. Two forms occur:
  /// the OpenSSL one-line form dart:io uses (`/C=US/O=Example, Inc./CN=x`:
  /// '/' separates, commas are plain characters) and RFC 4514
  /// (`CN=x,O=Example\, Inc.`: ',' or ';' separates; `\,` and quoted values
  /// keep the separator).
  static List<String> _splitDistinguishedName(String dn) {
    final s = dn.trim();
    if (s.startsWith('/')) {
      // A '/' only starts a new part when a `KEY=` follows.
      return s
          .split(RegExp(r'/(?=[A-Za-z][A-Za-z0-9-]*=|\d+(?:\.\d+)+=)'))
          .where((p) => p.isNotEmpty)
          .toList();
    }
    final parts = <String>[];
    final cur = StringBuffer();
    var quoted = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == r'\' && i + 1 < s.length) {
        cur
          ..write(c)
          ..write(s[++i]);
      } else if (c == '"') {
        quoted = !quoted;
        cur.write(c);
      } else if ((c == ',' || c == ';') && !quoted) {
        parts.add(cur.toString());
        cur.clear();
      } else {
        cur.write(c);
      }
    }
    if (cur.isNotEmpty) parts.add(cur.toString());
    return parts;
  }

  /// Removes surrounding quotes and resolves `\,` and `\2C` style escapes.
  static String _unquoteDnValue(String v) {
    if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) {
      v = v.substring(1, v.length - 1);
    }
    final out = StringBuffer();
    for (var i = 0; i < v.length; i++) {
      if (v[i] == r'\' && i + 1 < v.length) {
        final hex = i + 2 < v.length ? v.substring(i + 1, i + 3) : '';
        if (RegExp(r'^[0-9a-fA-F]{2}$').hasMatch(hex)) {
          out.writeCharCode(int.parse(hex, radix: 16));
          i += 2;
        } else {
          out.write(v[++i]);
        }
      } else {
        out.write(v[i]);
      }
    }
    return out.toString();
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

  static const _typesByExtension = {
    'script': ['js', 'mjs', 'cjs'],
    'style': ['css'],
    'image': [
      'png', 'jpg', 'jpeg', 'jfif', 'pjpeg', 'gif', 'webp', 'svg', 'ico', //
      'avif', 'bmp', 'apng', 'tif', 'tiff', 'heic', 'heif',
      'mp4', 'webm', 'mov', 'm4v', 'ogv', 'mp3', 'ogg', 'wav', 'm4a', 'aac',
    ],
    'font': ['woff', 'woff2', 'ttf', 'otf', 'eot'],
    'document': ['html', 'htm', 'xhtml'],
  };

  /// Resource type from the URL path's file extension (query and fragment
  /// ignored): script, style, image (incl. audio/video), font or document.
  /// Null when the extension is missing or unknown.
  static String? resourceTypeFromExtension(String url) {
    final path = (Uri.tryParse(url)?.path ?? url.split(RegExp('[?#]')).first)
        .toLowerCase();
    final lastSegment = path.substring(path.lastIndexOf('/') + 1);
    final dot = lastSegment.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = lastSegment.substring(dot + 1);
    for (final MapEntry(:key, :value) in _typesByExtension.entries) {
      if (value.contains(ext)) return key;
    }
    return null;
  }

  static String categorizeResource(String name, String pageUrl) {
    final byExtension = resourceTypeFromExtension(name);
    if (byExtension != null) {
      return byExtension == 'font' ? 'other' : byExtension;
    }

    name = name.toLowerCase();
    pageUrl = pageUrl.toLowerCase();

    if (name.endsWith('.js') ||
        name.contains('.js?') ||
        name.contains('.js#') ||
        name.contains('script')) {
      return 'script';
    }
    if (name.endsWith('.css') ||
        name.contains('.css?') ||
        name.contains('.css#') ||
        name.contains('style')) {
      return 'style';
    }
    if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp') ||
        name.endsWith('.svg') ||
        name.endsWith('.ico') ||
        name.endsWith('.avif') ||
        name.contains('image/') ||
        name.contains('img_') ||
        name.contains('/images/')) {
      return 'image';
    }
    if (name == pageUrl ||
        name == '$pageUrl/' ||
        name.endsWith('.html') ||
        name.endsWith('.htm') ||
        name.contains('document') ||
        (!name.contains('.') && name.startsWith('http'))) {
      return 'document';
    }
    return 'other';
  }
}
