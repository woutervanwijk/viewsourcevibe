import '../../utils/text_decoding.dart';
import '../html_file.dart';
import 'observed.dart';

/// How a file reached the app.
enum FileOrigin { picker, share, deepLink, restore }

/// A local/shared file as read from disk or delivered by the OS: the raw
/// bytes, the decoded text and what is known about it. The snapshot is the
/// truth; [toHtmlFile] is only an adapter for code that still uses HtmlFile.
class FileSnapshot {
  final String name;

  /// Filesystem path or pseudo path (`shared://text`, `content://...`);
  /// '' when there is none.
  final String path;
  final FileOrigin origin;

  /// The raw bytes, kept for binary files too.
  final List<int> bytes;

  /// The decoded text. For binary files `text.text` is '' and
  /// `text.isBinary` is true.
  final DecodedText text;

  /// Present(measured) for real paths; Unavailable for picker/share/text.
  final Observed<DateTime> lastModified;

  /// True for generated error pages (e.g. an unreadable content:// URI).
  final bool isError;

  const FileSnapshot({
    required this.name,
    required this.path,
    required this.origin,
    required this.bytes,
    required this.text,
    required this.lastModified,
    this.isError = false,
  });

  bool get isBinary => text.isBinary;

  /// Size in bytes (never the text length).
  int get byteLength => text.byteLength;

  bool get isShared => origin == FileOrigin.share;

  /// Media by extension or by image magic bytes.
  bool get isMedia => toHtmlFile().isMedia || _hasImageMagic(bytes);

  /// The HtmlFile view of this snapshot.
  ///
  /// `content` is the decoded text ('' for binary) and `size` the byte
  /// length. HtmlFile requires a `lastModified`, so when the real value is
  /// not available it is DateTime.now(); that is a placeholder only, the
  /// snapshot's [lastModified] is the truth.
  HtmlFile toHtmlFile() {
    final lm = lastModified;
    return HtmlFile(
      name: name,
      path: path,
      content: isBinary ? '' : text.text,
      lastModified: lm is Present<DateTime> ? lm.value : DateTime.now(),
      size: byteLength,
      isUrl: false,
      isError: isError,
      isShared: isShared,
    );
  }
}

bool _startsWith(List<int> b, List<int> p) {
  if (b.length < p.length) return false;
  for (var i = 0; i < p.length; i++) {
    if (b[i] != p[i]) return false;
  }
  return true;
}

bool _hasImageMagic(List<int> b) =>
    _startsWith(b, [0x89, 0x50, 0x4E, 0x47]) || // PNG
    _startsWith(b, [0xFF, 0xD8, 0xFF]) || // JPEG
    _startsWith(b, [0x47, 0x49, 0x46, 0x38]); // GIF
