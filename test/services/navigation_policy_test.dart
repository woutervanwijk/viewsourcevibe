import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/services/navigation_policy.dart';

void main() {
  NavigationDecision decide(
    String url, {
    bool isMainFrame = true,
    bool isPendingLoad = false,
    bool isCurrentFile = false,
  }) =>
      decideMainFrameNavigation(
        uri: Uri.parse(url),
        isMainFrame: isMainFrame,
        isPendingLoad: isPendingLoad,
        isCurrentFile: isCurrentFile,
      );

  test('a navigation started inside the WebView proceeds and is announced', () {
    expect(decide('https://www.ad.nl/privacy-gate/accept-tcf2?authId=1'),
        NavigationDecision.allowAndNotify);
  });

  test('non-http schemes are cancelled', () {
    for (final u in [
      'javascript:alert(1)',
      'data:text/html,hi',
      'file:///etc/passwd',
      'blob:https://a.test/x',
      'intent://x#Intent;end',
    ]) {
      expect(decide(u), NavigationDecision.cancel, reason: u);
    }
  });

  test('the load the app started itself is allowed without notice', () {
    expect(decide('https://a.test/', isPendingLoad: true),
        NavigationDecision.allow);
    expect(decide('https://a.test/', isCurrentFile: true),
        NavigationDecision.allow);
  });

  test('about:blank is allowed', () {
    expect(decide('about:blank'), NavigationDecision.allow);
  });

  test('sub-frame navigations are allowed', () {
    expect(decide('https://a.test/frame', isMainFrame: false),
        NavigationDecision.allow);
  });

  // Validation run 2026-11-13 (rijksoverheid.nl): the typed URL had no
  // trailing slash, the WebView reported one, and the view loaded the page a
  // second time after it finished. The cached second load ran the trackers
  // again and the page ended up with 1 cookie instead of 5.
  group('the browser already has the page', () {
    final same = HtmlService(store: InspectionStore()).areUrlsEqual;
    bool has(String target, {String? issued, String? current}) =>
        browserAlreadyHas(
            targetUrl: target,
            issuedUrl: issued,
            currentUrl: current,
            same: same);

    test('the WebView is on it, up to a trailing slash', () {
      expect(has('https://www.rijksoverheid.nl',
              current: 'https://www.rijksoverheid.nl/'),
          isTrue);
    });

    test('the app issued this load; the WebView followed a redirect', () {
      expect(has('http://kvk.nl',
              issued: 'http://kvk.nl', current: 'https://www.kvk.nl/'),
          isTrue);
    });

    test('another page is loaded', () {
      expect(has('https://b.test/', issued: 'https://a.test/',
              current: 'https://a.test/'),
          isFalse);
      expect(has('https://a.test/x', current: 'https://a.test/y'), isFalse);
    });

    test('a bare domain and its root are the same page', () {
      expect(same('https://a.test', 'https://a.test/'), isTrue);
      expect(same('https://a.test/x/', 'https://a.test/x'), isTrue);
      expect(same('https://a.test/x', 'https://a.test/'), isFalse);
    });

    test('nothing to load', () {
      expect(has('', current: ''), isFalse);
    });
  });
}
