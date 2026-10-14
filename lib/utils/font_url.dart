/// Recognises web font files by URL and describes them for display.
library;

final _fontExtension = RegExp(r'\.(woff2?|ttf|otf|eot)$', caseSensitive: false);

/// Adobe Fonts (Typekit) serves fonts without an extension:
/// `use.typekit.net/af/<id>/<id>/<n>/l?…&fvd=n4` (l = WOFF2, d = WOFF, a = OTF).
final _adobeFont = RegExp(r'^/af/[^/]+/[^/]+/\d+/([lda])$');

bool isFontUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return _fontExtension.hasMatch(uri.path) ||
      (uri.host.endsWith('typekit.net') && _adobeFont.hasMatch(uri.path));
}

/// Display name and format of a font URL, e.g. ("Inter-Bold", "WOFF2") or
/// ("Adobe Fonts · 700 italic", "WOFF2").
(String, String) describeFontUrl(String url) {
  final uri = Uri.tryParse(url);
  final adobe = uri == null ? null : _adobeFont.firstMatch(uri.path);
  if (uri != null && adobe != null) {
    final format = const {'l': 'WOFF2', 'd': 'WOFF', 'a': 'OTF'}[adobe[1]]!;
    // fvd: n/i for normal/italic, then the weight in hundreds.
    final fvd =
        RegExp(r'^([ni])(\d)$').firstMatch(uri.queryParameters['fvd'] ?? '');
    final style =
        fvd == null ? '' : ' · ${fvd[2]}00${fvd[1] == 'i' ? ' italic' : ''}';
    return ('Adobe Fonts$style', format);
  }
  final path = uri?.pathSegments.lastOrNull ?? url;
  final dot = path.lastIndexOf('.');
  return (
    Uri.decodeComponent(dot > 0 ? path.substring(0, dot) : path),
    dot > 0 ? path.substring(dot + 1).toUpperCase() : '',
  );
}
