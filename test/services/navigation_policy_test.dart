import 'package:flutter_test/flutter_test.dart';
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
}
