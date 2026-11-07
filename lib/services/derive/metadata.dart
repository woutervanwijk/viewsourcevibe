import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/file_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';
import '../metadata_parser.dart';

/// A relative link that could not be resolved to an absolute URL.
class UnresolvedLink {
  final String url;
  final String reason;
  const UnresolvedLink(this.url, this.reason);

  Map<String, String> toMap() => {'url': url, 'reason': reason};
}

/// Metadata of one document, and which document that was.
class DerivedMetadata {
  /// The parser's map (links, media, OpenGraph, ...), plus `canonical`,
  /// `docSource` and `unresolvedLinks`.
  final Map<String, dynamic> data;
  final DataSource docSource;

  /// From `<link rel=canonical>`; null when the page has none.
  final String? canonical;

  /// Relative links that stay unresolved (local file, no usable base).
  final List<UnresolvedLink> unresolvedLinks;

  const DerivedMetadata(
      this.data, this.docSource, this.canonical, this.unresolvedLinks);
}

typedef MetadataExtractor = Future<Map<String, dynamic>>
    Function(String html, String baseUrl, {Map<String, String>? headers});

bool _isAbsolute(String s) => RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(s);

Iterable<String> _linkStrings(Map<String, dynamic> m) sync* {
  Iterable<String> strings(dynamic v) sync* {
    if (v is String) yield v;
    if (v is List) {
      for (final x in v) {
        yield* strings(x);
      }
    }
    if (v is Map) {
      for (final x in v.values) {
        yield* strings(x);
      }
    }
  }

  for (final k in [
    'cssLinks',
    'jsLinks',
    'iframeLinks',
    'externalCssLinks',
    'externalJsLinks',
    'externalIframeLinks',
    'rssLinks',
    'icons',
    'resourceHints',
  ]) {
    yield* strings(m[k]);
  }
  // pageConfig also holds viewport / theme-color / msapplication-* values,
  // which are not links.
  final config = m['pageConfig'];
  if (config is Map) {
    for (final k in const ['canonical', 'manifest', 'opensearch']) {
      yield* strings(config[k]);
    }
  }
  final media = m['media'];
  if (media is Map) {
    for (final key in ['images', 'videos']) {
      final list = media[key];
      if (list is List) {
        for (final item in list) {
          if (item is Map && item['src'] is String) yield item['src'] as String;
        }
      }
    }
  }
}

/// Metadata of [text], the document of [docSource], at [baseUrl] ('' for a
/// local file). `<base href>` is honoured by the parser. A relative link
/// that has nothing to resolve against is listed in [DerivedMetadata
/// .unresolvedLinks] (never turned into `https://img/a.png`).
Future<DerivedMetadata> deriveMetadata(
  String text,
  String baseUrl,
  DataSource docSource, {
  Map<String, String>? headers,
  MetadataExtractor extractor = extractMetadataInIsolate,
}) async {
  final data = Map<String, dynamic>.from(
      await extractor(text, baseUrl, headers: headers));
  final localBase =
      !(baseUrl.startsWith('http://') || baseUrl.startsWith('https://'));
  final reason = localBase
      ? 'relative link in local file'
      : 'relative link could not be resolved';
  final seen = <String>{};
  final unresolved = [
    for (final s in _linkStrings(data))
      if (s.isNotEmpty && !s.startsWith('<') && !_isAbsolute(s) && seen.add(s))
        UnresolvedLink(s, reason),
  ];
  final canonical =
      data['canonical'] is String && (data['canonical'] as String).isNotEmpty
          ? data['canonical'] as String
          : null;
  data['docSource'] = docSource.name;
  data['unresolvedLinks'] = [for (final u in unresolved) u.toMap()];
  return DerivedMetadata(data, docSource, canonical, unresolved);
}

/// The document an analysis runs on: its text, the URL it resolves links
/// against ('' for a file or a non-http page) and where it came from.
class PageDocumentInput {
  final String text;
  final String baseUrl;
  final DataSource source;
  const PageDocumentInput(this.text, this.baseUrl, this.source);
}

String _httpOrEmpty(Uri u) =>
    u.scheme == 'http' || u.scheme == 'https' ? u.toString() : '';

/// The store's primary document (rendered DOM, else server body, else file)
/// as input for [deriveMetadata] and the detection scan; null when none.
PageDocumentInput? primaryDocumentInput(PageInspection p) {
  switch (p.primaryDocument) {
    case DataSource.browser:
      final b = (p.browser as Present<BrowserSnapshot>).value;
      final dom = b.renderedDom as Present<RenderedDom>;
      return PageDocumentInput(
          dom.value.text, _httpOrEmpty(b.url), DataSource.browser);
    case DataSource.server:
      final s = (p.server as Present<ServerSnapshot>).value;
      final body = (s.body as Present<ServerBody>).value;
      if (body.decoded.isBinary) return null;
      final fin = s.finalUrl;
      return PageDocumentInput(
          body.decoded.text,
          _httpOrEmpty(fin is Present<Uri> ? fin.value : s.requestedUrl),
          DataSource.server);
    case DataSource.file:
      final f = (p.file as Present<FileSnapshot>).value;
      if (f.isBinary) return null;
      return PageDocumentInput(f.text.text, '', DataSource.file);
    case null:
      return null;
  }
}
