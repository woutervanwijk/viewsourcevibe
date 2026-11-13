/// What the WebView layer does with a navigation it is about to make.
enum NavigationDecision {
  /// Let it proceed; the app has nothing to do.
  allow,

  /// Let it proceed unchanged and tell HtmlService it happened (link click,
  /// JS location, form, server redirect). The browser keeps its redirects,
  /// cookies, POST bodies and Referer; the app never re-issues the request.
  allowAndNotify,

  /// Block it.
  cancel,
}

/// Pure policy for `shouldOverrideUrlLoading`, so it can be tested without a
/// WebView. Only http/https is ever navigated to.
NavigationDecision decideMainFrameNavigation({
  required Uri uri,
  required bool isMainFrame,
  required bool isPendingLoad,
  required bool isCurrentFile,
}) {
  if (uri.toString() == 'about:blank') return NavigationDecision.allow;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return NavigationDecision.cancel;
  if (!isMainFrame) return NavigationDecision.allow;
  // The load the app started itself (or the current file, e.g. an RSS
  // template with a baseUrl).
  if (isPendingLoad || isCurrentFile) return NavigationDecision.allow;
  return NavigationDecision.allowAndNotify;
}

/// Whether the WebView already has [targetUrl] (loaded or loading), so the
/// view must not load it again. [issuedUrl] is the load the app gave the
/// WebView for the current navigation; [currentUrl] is where the WebView is.
/// A second load of the same page runs its scripts twice and reads the page
/// from cache: trackers then set other cookies than on a real visit
/// (validation run 2026-11-13, rijksoverheid.nl). URLs are compared with
/// [same] (trailing slash and redirect-insensitive where the caller wants).
bool browserAlreadyHas({
  required String targetUrl,
  required String? issuedUrl,
  required String? currentUrl,
  required bool Function(String a, String b) same,
}) =>
    targetUrl.isNotEmpty &&
    ((issuedUrl != null && same(issuedUrl, targetUrl)) ||
        (currentUrl != null && same(currentUrl, targetUrl)));
