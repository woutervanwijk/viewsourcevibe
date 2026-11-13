import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';

/// What the browser got instead of the site: an HTTP error status, or a bot
/// manager's block or challenge page. Analyses of its content describe that
/// page, not the site.
class BlockPage {
  /// The browser's main-document status, when it is an error (>= 400).
  final int? status;

  /// The bot manager whose page it is, when a marker names one.
  final String? vendor;

  /// A challenge (the visitor may pass after a check) rather than a block.
  final bool challenge;

  /// A block or challenge marker matched; a status alone is an error page.
  final bool byMarker;

  const BlockPage(
      {this.status,
      this.vendor,
      this.challenge = false,
      this.byMarker = false});

  /// "block page (HTTP 403, Akamai)", "challenge page (Cloudflare)",
  /// "error page (HTTP 404)".
  String get label {
    final kind = challenge
        ? 'challenge page'
        : byMarker
            ? 'block page'
            : 'error page';
    final why = [
      if (status != null) 'HTTP $status',
      if (vendor != null) vendor!
    ];
    return why.isEmpty ? kind : '$kind (${why.join(', ')})';
  }

  /// [label] with its article: "a block page (…)", "an error page (…)".
  String get aLabel => '${byMarker || challenge ? 'a' : 'an'} $label';

  /// One sentence for banners and Unavailable details.
  String get detail => 'the browser got $aLabel instead of the site; '
      'what depends on the page content describes that page';

  Map<String, Object?> toMap() => {
        'status': status,
        'vendor': vendor,
        'challenge': challenge,
        'label': label,
      };

  @override
  bool operator ==(Object other) =>
      other is BlockPage &&
      other.status == status &&
      other.vendor == vendor &&
      other.challenge == challenge &&
      other.byMarker == byMarker;

  @override
  int get hashCode => Object.hash(status, vendor, challenge, byMarker);
}

typedef _Marker = ({RegExp pattern, String? vendor, bool challenge});

_Marker _m(String pattern, {String? vendor, bool challenge = false}) => (
      pattern: RegExp(pattern, caseSensitive: false),
      vendor: vendor,
      challenge: challenge
    );

/// Markers that only appear on block and challenge pages, not on normal pages
/// that merely load the vendor's script (Akamai's `sbsd` cookie and script,
/// Cloudflare's `/cdn-cgi/challenge-platform/scripts/jsd/`, DataDome's
/// `tags.js` and PerimeterX's client run on real pages too).
final List<_Marker> _markers = [
  _m(r'<title>\s*Just a moment(\.\.\.|…)\s*</title>',
      vendor: 'Cloudflare', challenge: true),
  _m(r'_cf_chl_opt', vendor: 'Cloudflare', challenge: true),
  _m(r'<title>\s*Attention Required! \| Cloudflare', vendor: 'Cloudflare'),
  _m(r'Sorry, you have been blocked', vendor: 'Cloudflare'),
  _m(r'errors\.edgesuite\.net', vendor: 'Akamai'),
  _m(r"You don't have permission to access", vendor: 'Akamai'),
  _m(r'(geo|ct)\.captcha-delivery\.com', vendor: 'DataDome'),
  _m(r'id="px-captcha"', vendor: 'HUMAN (PerimeterX)', challenge: true),
  _m(r'Incapsula incident ID', vendor: 'Imperva'),
  _m(r'<title>\s*Access Denied\s*</title>'),
  _m(r'\b(access|IP address)\b[^<]{0,60}\b(has been|is)\s+(temporarily\s+)?blocked'),
];

/// Block and challenge pages are small; the markers are only trusted on a
/// document below this size, so an article about blocking is not one.
const blockPageMaxDomChars = 100000;

/// Classifies the browser's page: an error status (>= 400) or a known block
/// or challenge marker in a small rendered DOM. Null when it looks like the
/// site itself (or nothing is known).
BlockPage? classifyBlockPage({required Observed<int> status, String? dom}) {
  final code =
      status is Present<int> && status.value >= 400 ? status.value : null;
  _Marker? hit;
  if (dom != null && dom.length <= blockPageMaxDomChars) {
    for (final m in _markers) {
      if (m.pattern.hasMatch(dom)) {
        // A marker naming a vendor beats a generic one.
        if (hit == null || (hit.vendor == null && m.vendor != null)) hit = m;
        if (hit.vendor != null) break;
      }
    }
  }
  if (code == null && hit == null) return null;
  return BlockPage(
      status: code,
      vendor: hit?.vendor,
      challenge: hit?.challenge ?? false,
      byMarker: hit != null);
}

/// [classifyBlockPage] for the browser of a URL inspection; null otherwise.
BlockPage? browserBlockPage(PageInspection p) {
  final b = p.browser;
  if (p.target is! UrlTarget || b is! Present<BrowserSnapshot>) return null;
  final dom = b.value.renderedDom;
  return classifyBlockPage(
      status: b.value.mainStatus,
      dom: dom is Present<RenderedDom> ? dom.value.text : null);
}
