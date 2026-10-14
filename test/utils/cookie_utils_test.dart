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
      final cookie = CookieUtils.analyze('_gcl_au=1.1.123', 'Browser');
      expect(cookie.category, CookieCategory.advertising);
      expect(cookie.provider, 'Google Ads');
    });

    test('Generic first-party names are not labelled as ad cookies', () {
      for (final name in ['NID', 'token', 'A', 'visitor']) {
        final cookie = CookieUtils.analyze('$name=1', 'Server');
        expect(cookie.category, CookieCategory.unknown, reason: name);
        expect(cookie.provider, null, reason: name);
      }
    });

    test('Providers use the catalogue names', () {
      expect(CookieUtils.analyze('_uetsid=1', 'Browser').provider,
          'Microsoft Advertising');
      expect(CookieUtils.analyze('_ym_uid=1', 'Browser').provider,
          'Yandex Metrica');
    });

    test('Should identify Facebook cookies', () {
      final cookie = CookieUtils.analyze('_fbp=fb.1.123456789', 'Server');
      expect(cookie.category, CookieCategory.advertising);
      expect(cookie.provider, 'Meta Pixel');
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
