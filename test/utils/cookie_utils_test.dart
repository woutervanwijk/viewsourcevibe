import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/utils/cookie_utils.dart';

void main() {
  group('CookieUtils Tests', () {
    test('Should identify Google Analytics cookies', () {
      final cookie =
          CookieUtils.analyze('_ga=GA1.2.123456789.123456789', 'Server');
      expect(cookie.category, CookieCategory.analytics);
      expect(cookie.provider, 'Google Analytics');
    });

    test('Should identify Google Ads cookies', () {
      final cookie = CookieUtils.analyze('NID=12345', 'Server');
      expect(cookie.category, CookieCategory.advertising);
      expect(cookie.provider, 'Google');
    });

    test('Should identify Facebook cookies', () {
      final cookie = CookieUtils.analyze('_fbp=fb.1.123456789', 'Server');
      expect(cookie.category, CookieCategory.advertising);
      expect(cookie.provider, 'Facebook');
    });

    test('Should identify AWS/Amazon cookies', () {
      final cookie = CookieUtils.analyze('AWSALB=1234567890', 'Server');
      expect(cookie.category, CookieCategory.functional);
      expect(cookie.provider, 'AWS Load Balancer');
    });

    test('Should identify Cloudflare cookies', () {
      final cookie = CookieUtils.analyze('__cf_bm=12345', 'Server');
      expect(cookie.category, CookieCategory.essential);
      expect(cookie.provider, 'Cloudflare');
    });

    test('Should identify Unknown cookies', () {
      final cookie = CookieUtils.analyze('random_cookie=value', 'Server');
      expect(cookie.category, CookieCategory.unknown);
      expect(cookie.provider, null);
    });

    test('Should handle keys with extra characters (partial match)', () {
      // Logic in CookieUtils uses startsWith?
      // "final known = _knownCookies[name] ?? _knownCookies.entries.firstWhere((e) => name.startsWith(e.key)..."

      final cookie = CookieUtils.analyze('wp-settings-123=editor', 'Server');
      expect(cookie.category, CookieCategory.functional);
      expect(cookie.provider, 'WordPress');
    });
  });
}
