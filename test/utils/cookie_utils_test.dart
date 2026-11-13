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
      expect(cookie.provider, 'Amazon Web Services'); // OCD platform name
    });

    test('Should identify Cloudflare cookies', () {
      final cookie = CookieUtils.analyze('__cf_bm=12345', 'Server');
      expect(cookie.category, CookieCategory.functional); // OCD: Functional
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

    test('consent wildcard only matches consent-manager state names (K7)', () {
      for (final n in [
        'consent_ad_id',
        'trackingconsent_ads',
        'ad_consent_id',
        'user_consent_tracking_uid'
      ]) {
        expect(CookieUtils.analyze('$n=1', 'Server').category,
            isNot(CookieCategory.essential),
            reason: n);
      }
      for (final n in ['consentmanager_x', 'cmp_state', 'ConsentMode']) {
        expect(
            CookieUtils.analyze('$n=1', 'Server').provider, 'Consent Manager',
            reason: n);
      }
    });

    test('longest matching prefix wins (K8)', () {
      final prefixes = CookieUtils.prefixKeysForTest;
      for (var i = 0; i < prefixes.length; i++) {
        for (var j = i + 1; j < prefixes.length; j++) {
          expect(
              prefixes[j].startsWith(prefixes[i]) && prefixes[j] != prefixes[i],
              isFalse,
              reason: '${prefixes[i]} listed before longer ${prefixes[j]}');
        }
      }
    });

    test('Set-Cookie is split at the first semicolon, quotes are not special',
        () {
      // RFC 6265 5.2: browsers split the string at the first ";" even inside
      // a quoted value.
      final cookie = CookieUtils.analyze('a="x;y"; Secure', 'Server');
      expect(cookie.name, 'a');
      expect(cookie.value, '"x');
      expect(cookie.secure, isTrue);
    });

    test('Max-Age and Expires handling (K9)', () {
      final now = DateTime.utc(2026, 1, 1);
      String? e(String a) =>
          CookieUtils.analyze('a=1; $a', 'Server', now: now).expires;
      expect(e('Max-Age=0'), 'expired (deleted)');
      expect(e('Max-Age=-5'), 'expired (deleted)');
      expect(e('Max-Age=60'), '2026-01-01T00:01:00.000Z');
      expect(e('Expires=Wed, 01 Jan 2031 00:00:00 GMT'),
          '2031-01-01T00:00:00.000Z');
      expect(e('Expires=garbage'), 'garbage');
      expect(e('Max-Age=0; Expires=Wed, 01 Jan 2031 00:00:00 GMT'),
          'expired (deleted)');
    });
  });
}
