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
