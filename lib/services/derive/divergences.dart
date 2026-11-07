import '../../models/inspection/browser_snapshot.dart';
import '../../models/inspection/observed.dart';
import '../../models/inspection/page_inspection.dart';
import '../../models/inspection/server_snapshot.dart';

enum DivergenceKind { serverStatus, finalUrl, contentType }

/// A place where the app's own request (the "server" core) and the browser
/// disagree. Shown as a note, never as an error.
class Divergence {
  final DivergenceKind kind;
  final String message;
  const Divergence(this.kind, this.message);

  Map<String, String> toMap() => {'kind': kind.name, 'message': message};
}

String _hostKey(Uri u) {
  final h = u.host.toLowerCase();
  return h.startsWith('www.') ? h.substring(4) : h;
}

String _pathKey(Uri u) {
  final p = u.path;
  return p.length > 1 && p.endsWith('/') ? p.substring(0, p.length - 1) : p;
}

bool _isHtmlType(String? ct) {
  final t = (ct ?? '').toLowerCase();
  return t.contains('text/html') || t.contains('application/xhtml');
}

/// Differences between what the server fetch and the browser saw.
///  1. the server answered >= 400 while the browser has a rendered DOM,
///  2. the server's final URL and the browser URL differ by host or path
///     (scheme, `www.`, a trailing slash, query and fragment are ignored),
///  3. the server did not send HTML while the browser's document is HTML.
List<Divergence> deriveDivergences(PageInspection p) {
  final server = p.server;
  final browser = p.browser;
  if (server is! Present<ServerSnapshot> ||
      browser is! Present<BrowserSnapshot> ||
      server.value.hops.isEmpty) {
    return const [];
  }
  final s = server.value;
  final b = browser.value;
  final last = s.hops.last;
  final hasDom = b.renderedDom is Present<RenderedDom>;
  final out = <Divergence>[];

  if (last.statusCode >= 400 && hasDom) {
    out.add(Divergence(
        DivergenceKind.serverStatus,
        "server returned ${last.statusCode} to the app's request "
        '(UA ${s.userAgent}) but the browser loaded the page'));
  }

  final fin = s.finalUrl;
  if (fin is Present<Uri> &&
      (b.url.scheme == 'http' || b.url.scheme == 'https')) {
    final u = fin.value;
    if (_hostKey(u) != _hostKey(b.url) || _pathKey(u) != _pathKey(b.url)) {
      out.add(Divergence(DivergenceKind.finalUrl,
          "the app's request ended at $u but the browser is at ${b.url}"));
    }
  }

  final serverType = last.header('content-type');
  final browserType = b.contentType;
  final browserIsHtml =
      browserType is Present<String> ? _isHtmlType(browserType.value) : hasDom;
  if (hasDom &&
      s.body is Present<ServerBody> &&
      serverType != null &&
      !_isHtmlType(serverType) &&
      browserIsHtml) {
    out.add(Divergence(DivergenceKind.contentType,
        'server sent $serverType but the browser document is HTML'));
  }
  return out;
}
