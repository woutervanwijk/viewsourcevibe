/// Parsers for `Permissions-Policy`, `Feature-Policy` and iframe `allow`.
library;

class Allowlist {
  final bool all; // *
  final bool self; // self / 'self'
  final bool src; // 'src' (iframe allow only)
  final List<String> origins;
  bool get none => !all && !self && !src && origins.isEmpty;
  const Allowlist(
      {this.all = false,
      this.self = false,
      this.src = false,
      this.origins = const []});
}

class ParsedPolicy {
  final Map<String, Allowlist> features; // header order
  final List<String> invalid; // members that could not be parsed
  const ParsedPolicy(this.features, this.invalid);
}

/// Features that reach the device or the user: shown first, flagged when
/// delegated to a third party.
const Set<String> powerfulFeatures = {
  'camera',
  'microphone',
  'geolocation',
  'display-capture',
  'payment',
  'usb',
  'serial',
  'hid',
  'bluetooth',
  'midi',
  'clipboard-read',
  'publickey-credentials-get',
  'screen-wake-lock',
  'idle-detection',
  'accelerometer',
  'gyroscope',
  'magnetometer',
  'browsing-topics',
  'attribution-reporting',
  'local-fonts',
};

final _featureName = RegExp(r'^[a-z][a-z0-9_.-]*$');
final _origin = RegExp(r'^[a-z][a-z0-9+.-]*://[^\s/"]+$', caseSensitive: false);

/// Splits [s] on [sep] outside double quotes; empty parts are dropped.
List<String> _split(String s, Pattern sep, {bool quotes = true}) {
  final parts = <String>[];
  final buf = StringBuffer();
  var inQuote = false;
  for (final rune in s.split('')) {
    if (quotes && rune == '"') inQuote = !inQuote;
    if (!inQuote && _isSep(rune, sep)) {
      parts.add(buf.toString());
      buf.clear();
    } else {
      buf.write(rune);
    }
  }
  parts.add(buf.toString());
  return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
}

bool _isSep(String ch, Pattern sep) =>
    sep is String ? ch == sep : sep.allMatches(ch).isNotEmpty;

/// Drops structured-field parameters (`;report-to=x`) outside quotes.
String _dropParams(String s) {
  var inQuote = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '"') inQuote = !inQuote;
    if (c == ';' && !inQuote) return s.substring(0, i).trim();
  }
  return s.trim();
}

/// Adds [name] -> [list]; a repeat keeps the first and is reported invalid.
void _add(Map<String, Allowlist> features, List<String> invalid, String name,
    Allowlist list) {
  if (features.containsKey(name)) {
    invalid.add('$name (repeated)');
  } else {
    features[name] = list;
  }
}

/// `Permissions-Policy: geolocation=(), camera=(self "https://a.test"), fullscreen=*`
ParsedPolicy parsePermissionsPolicy(String header) {
  final features = <String, Allowlist>{};
  final invalid = <String>[];
  // Commas are only valid between members; a stray unclosed "(" must not
  // swallow the members after it, so parentheses are not tracked here.
  for (final member in _split(header, ',')) {
    final eq = member.indexOf('=');
    final name =
        (eq < 0 ? member : member.substring(0, eq)).trim().toLowerCase();
    if (eq < 0 || !_featureName.hasMatch(name)) {
      invalid.add(member);
      continue;
    }
    final list = _parseValue(member.substring(eq + 1).trim());
    if (list == null) {
      invalid.add(member);
    } else {
      _add(features, invalid, name, list);
    }
  }
  return ParsedPolicy(features, invalid);
}

Allowlist? _parseValue(String value) {
  List<String> items;
  if (value.startsWith('(')) {
    final close = value.lastIndexOf(')');
    if (close < 0) return null;
    // Parameters may only follow the closing parenthesis.
    final rest = value.substring(close + 1).trim();
    if (rest.isNotEmpty && !rest.startsWith(';')) return null;
    items = _split(value.substring(1, close), RegExp(r'\s'));
  } else {
    items = [_dropParams(value)];
  }
  var all = false, self = false;
  final origins = <String>[];
  for (final raw in items) {
    final item = _dropParams(raw);
    if (item == '*') {
      all = true;
    } else if (item == 'self') {
      self = true;
    } else if (item.length > 1 &&
        item.startsWith('"') &&
        item.endsWith('"') &&
        _origin.hasMatch(item.substring(1, item.length - 1))) {
      origins.add(item.substring(1, item.length - 1));
    } else {
      return null;
    }
  }
  return Allowlist(all: all, self: self, origins: origins);
}

/// `Feature-Policy` header and iframe `allow` attribute:
/// `geolocation 'none'; camera 'self' https://a.test; fullscreen *`.
/// A feature without a value means 'src' for [iframeAllow], 'self' otherwise.
ParsedPolicy parseFeaturePolicy(String value, {bool iframeAllow = false}) {
  final features = <String, Allowlist>{};
  final invalid = <String>[];
  for (final directive in _split(value, ';', quotes: false)) {
    final tokens = directive.split(RegExp(r'\s+'));
    final name = tokens.first.toLowerCase();
    if (!_featureName.hasMatch(name)) {
      invalid.add(directive);
      continue;
    }
    final values = tokens.skip(1);
    if (values.isEmpty) {
      _add(
          features,
          invalid,
          name,
          iframeAllow
              ? const Allowlist(src: true)
              : const Allowlist(self: true));
      continue;
    }
    var all = false, self = false, src = false;
    final origins = <String>[];
    for (final t in values) {
      switch (t) {
        case '*':
          all = true;
        case "'self'":
          self = true;
        case "'src'":
          src = true;
        case "'none'":
          break;
        default:
          if (_origin.hasMatch(t)) {
            origins.add(t);
          } else {
            invalid.add('$name: $t (invalid token)');
          }
      }
    }
    _add(features, invalid, name,
        Allowlist(all: all, self: self, src: src, origins: origins));
  }
  return ParsedPolicy(features, invalid);
}
