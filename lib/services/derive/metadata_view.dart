import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../models/inspection/observed.dart';
import 'metadata.dart';
import 'page_size.dart';

/// Accessibility and SEO facts counted in the document the metadata was
/// extracted from (so the widget never parses HTML).
class DocumentChecks {
  final int imageCount;
  final int imagesMissingAlt;
  final int h1Count;
  final int headingCount;
  final int controlCount;
  final int unlabeledControls;
  final int landmarkCount;

  /// Content of `<meta name=robots|googlebot>`; null when the page has none.
  final String? robotsMeta;

  const DocumentChecks({
    required this.imageCount,
    required this.imagesMissingAlt,
    required this.h1Count,
    required this.headingCount,
    required this.controlCount,
    required this.unlabeledControls,
    required this.landmarkCount,
    required this.robotsMeta,
  });
}

bool _isUnlabeledControl(dom.Document doc, dom.Element element) {
  final type = element.attributes['type']?.toLowerCase();
  if (type == 'hidden' || type == 'submit' || type == 'button') return false;
  if ((element.attributes['aria-label'] ?? '').trim().isNotEmpty) return false;
  if ((element.attributes['aria-labelledby'] ?? '').trim().isNotEmpty) {
    return false;
  }
  final id = element.attributes['id'];
  if (id != null && id.isNotEmpty) {
    final escaped = id.replaceAll('"', r'\"');
    if (doc.querySelector('label[for="$escaped"]') != null) return false;
  }
  return element.parent?.localName != 'label';
}

/// Counts for the Accessibility snapshot and the robots meta of [html].
/// Top-level and pure, so it can run in an isolate.
DocumentChecks deriveDocumentChecks(String html) {
  final doc = html_parser.parse(html);
  final images = doc.querySelectorAll('img');
  final controls = doc.querySelectorAll('input,select,textarea');
  final robots = doc
      .querySelector('meta[name="robots"],meta[name="googlebot"]')
      ?.attributes['content'];
  return DocumentChecks(
    imageCount: images.length,
    imagesMissingAlt:
        images.where((i) => (i.attributes['alt'] ?? '').trim().isEmpty).length,
    h1Count: doc.querySelectorAll('h1').length,
    headingCount: doc.querySelectorAll('h1,h2,h3,h4,h5,h6').length,
    controlCount: controls.length,
    unlabeledControls:
        controls.where((e) => _isUnlabeledControl(doc, e)).length,
    landmarkCount: doc
        .querySelectorAll('main,nav,header,footer,aside,[role="main"],'
            '[role="navigation"],[role="banner"],[role="contentinfo"]')
        .length,
    robotsMeta: robots,
  );
}

/// "rendered DOM", "server HTML" or "file": which document was analysed.
String documentLabel(DataSource s) => switch (s) {
      DataSource.browser => 'rendered DOM',
      DataSource.server => 'server HTML',
      DataSource.file => 'file',
    };

/// The size line of a linked resource: "12 KB (↓ 4 KB)", "≈ ↓ 4 KB" for our
/// own estimate, or "size unknown" with the reason. [size] is the metadata item's
/// `size` map; [unknownReason] says why when there is none. Never "0 KB".
String linkSizeLabel(Object? size, {required String unknownReason}) {
  if (size is Map) {
    final text = formatSizePair(
        decoded: size['decoded'] as int?, transfer: size['transfer'] as int?);
    if (text != null) return size['estimated'] == true ? '≈ $text' : text;
    final own = size['unknownReason'];
    if (own is String && own.isNotEmpty) return 'size unknown ($own)';
  }
  return 'size unknown ($unknownReason)';
}

/// The Metadata tab's data: the extraction and which document it came from.
class MetadataModel {
  /// The parser's map (links, OpenGraph, structured data, ...) with sizes.
  final Map<String, dynamic> data;
  final DataSource docSource;
  final DocumentChecks checks;
  final List<UnresolvedLink> unresolved;

  /// Why a link has no size when the browser said nothing about it.
  final String sizeUnknownReason;

  MetadataModel({
    required this.data,
    required this.docSource,
    required this.checks,
    required this.unresolved,
    required this.sizeUnknownReason,
  });

  /// `<title>` exists (possibly empty); false = the page has none.
  bool get hasTitle => data['title'] is String;
  String get title => (data['title'] as String?) ?? '';
  bool get hasDescription => data['description'] is String;

  /// "From: rendered DOM".
  String get sourceLine => 'From: ${documentLabel(docSource)}';

  late final Map<String, String> _unresolvedNotes = {
    for (final u in unresolved)
      u.url: u.reason == 'relative link in local file'
          ? 'relative link — cannot be resolved for a local file'
          : 'relative link — cannot be resolved',
  };

  /// Why [url] cannot be opened (a relative link without a base); null for
  /// a link that resolves.
  String? unresolvedNote(String url) => _unresolvedNotes[url];
}
