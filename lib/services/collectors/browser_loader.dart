/// Starts a navigation in the in-app browser. A seam so HtmlService can be
/// tested without a WebView.
abstract class BrowserLoader {
  void loadUrl(Uri url);
}
