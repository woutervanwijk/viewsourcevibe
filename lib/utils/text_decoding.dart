import 'dart:convert';

enum CharsetSource { header, bom, meta, fallback }

class DecodedText {
  final String text;
  final String charset;
  final CharsetSource charsetSource;
  final bool hadMalformed;
  final bool isBinary;
  final bool unsupportedCharset;

  /// Size of the raw input, never the length of [text].
  final int byteLength;

  const DecodedText({
    required this.text,
    required this.charset,
    required this.charsetSource,
    required this.byteLength,
    this.hadMalformed = false,
    this.isBinary = false,
    this.unsupportedCharset = false,
  });
}

// Windows-1252 code points for 0x80..0x9F (undefined ones map to themselves).
const _cp1252High = [
  0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
  0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
];

const _magicNumbers = <List<int>>[
  [0x89, 0x50, 0x4E, 0x47], // PNG
  [0xFF, 0xD8, 0xFF], // JPEG
  [0x47, 0x49, 0x46, 0x38], // GIF
  [0x25, 0x50, 0x44, 0x46], // PDF
  [0x50, 0x4B, 0x03, 0x04], // ZIP
];

String? _normalize(String name) {
  switch (name.trim().toLowerCase()) {
    case 'utf-8':
    case 'utf8':
      return 'utf-8';
    case 'utf-16le':
    case 'utf-16':
      return 'utf-16le';
    case 'utf-16be':
      return 'utf-16be';
    case 'iso-8859-1':
    case 'latin1':
    case 'iso_8859-1':
      return 'iso-8859-1';
    case 'windows-1252':
    case 'cp1252':
      return 'windows-1252';
  }
  return null;
}

bool _startsWith(List<int> b, List<int> prefix) {
  if (b.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (b[i] != prefix[i]) return false;
  }
  return true;
}

String? _headerCharset(String? contentType) {
  if (contentType == null) return null;
  final m = RegExp(r'charset\s*=\s*"?([^\s";]+)', caseSensitive: false)
      .firstMatch(contentType);
  return m?.group(1);
}

String? _metaCharset(List<int> bytes) {
  final head = latin1.decode(bytes.take(1024).toList(), allowInvalid: true);
  final m = RegExp(r'''<meta[^>]*?charset\s*=\s*["']?([\w\-]+)''',
          caseSensitive: false)
      .firstMatch(head);
  return m?.group(1);
}

String _decodeUtf16(List<int> b, bool bigEndian, void Function() malformed) {
  final units = <int>[];
  for (var i = 0; i + 1 < b.length; i += 2) {
    units.add(bigEndian ? (b[i] << 8) | b[i + 1] : (b[i + 1] << 8) | b[i]);
  }
  if (b.length.isOdd) malformed();
  return String.fromCharCodes(units);
}

/// Decodes [bytes] to text. Charset precedence: BOM > Content-Type header >
/// `<meta>` in the first 1024 bytes > UTF-8 fallback.
DecodedText decodeText(List<int> bytes, {String? contentType}) {
  var start = 0;
  String? charset;
  var source = CharsetSource.fallback;
  var unsupported = false;

  if (_startsWith(bytes, [0xEF, 0xBB, 0xBF])) {
    charset = 'utf-8';
    start = 3;
    source = CharsetSource.bom;
  } else if (_startsWith(bytes, [0xFF, 0xFE])) {
    charset = 'utf-16le';
    start = 2;
    source = CharsetSource.bom;
  } else if (_startsWith(bytes, [0xFE, 0xFF])) {
    charset = 'utf-16be';
    start = 2;
    source = CharsetSource.bom;
  } else {
    final declared = _headerCharset(contentType);
    final candidates = [
      (declared, CharsetSource.header),
      (declared == null ? _metaCharset(bytes) : null, CharsetSource.meta),
    ];
    for (final (name, src) in candidates) {
      if (name == null) continue;
      final known = _normalize(name);
      if (known != null) {
        charset = known;
        source = src;
      } else {
        unsupported = true;
      }
      break;
    }
  }
  charset ??= 'utf-8';
  final body = start == 0 ? bytes : bytes.sublist(start);

  final isUtf16 = charset.startsWith('utf-16');
  final head = bytes.take(1024);
  final binary = _magicNumbers.any((m) => _startsWith(bytes, m)) ||
      (!isUtf16 && head.contains(0));
  if (binary) {
    return DecodedText(
      text: '',
      charset: charset,
      charsetSource: source,
      byteLength: bytes.length,
      isBinary: true,
      unsupportedCharset: unsupported,
    );
  }

  var malformed = false;
  final String text;
  switch (charset) {
    case 'utf-16le':
    case 'utf-16be':
      text = _decodeUtf16(body, charset == 'utf-16be', () => malformed = true);
    case 'iso-8859-1':
      text = String.fromCharCodes(body);
    case 'windows-1252':
      text = String.fromCharCodes(
          body.map((b) => b >= 0x80 && b <= 0x9F ? _cp1252High[b - 0x80] : b));
    default:
      try {
        text = utf8.decode(body);
      } on FormatException {
        malformed = true;
        return DecodedText(
          text: utf8.decode(body, allowMalformed: true),
          charset: charset,
          charsetSource: source,
          byteLength: bytes.length,
          hadMalformed: true,
          unsupportedCharset: unsupported,
        );
      }
  }
  return DecodedText(
    text: text,
    charset: charset,
    charsetSource: source,
    byteLength: bytes.length,
    hadMalformed: malformed,
    unsupportedCharset: unsupported,
  );
}
