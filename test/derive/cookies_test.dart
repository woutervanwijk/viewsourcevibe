import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/cookies.dart';

import 'fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  test('Max-Age becomes expires (and wins over Expires)', () {
    final c = deriveCookies(
        inspection(
            server: serverSnap(setCookies: [
          'a=1; Max-Age=3600; Expires=Wed, 01 Jan 2020 00:00:00 GMT; Path=/'
        ])),
        now: now);
    expect(c.single.expires, '2026-01-01T13:00:00.000Z');
    expect(c.single.path, '/');
  });

  test('key is name + domain + path', () {
    final c = deriveCookies(
        inspection(
            server: serverSnap(setCookies: [
              'a=1; Path=/x; Domain=a.test',
              'a=2; Path=/y; Domain=a.test',
            ]),
            browser: browserSnap(cookies: [
              cookie('a',
                  value: '3',
                  domain: b('a.test'),
                  path: b('/x'),
                  secure: b(true),
                  httpOnly: b(false)),
              cookie('a', value: '4', domain: b('other.test'), path: b('/x')),
            ])),
        now: now);
    expect(c.length, 3); // /x merged, /y server only, other.test separate
    final merged = c.firstWhere((x) => x.path == '/x' && x.domain == 'a.test');
    expect(merged.source, 'Server + Browser');
    expect(merged.value, '3');
    expect(merged.secure, isTrue);
    expect(c.where((x) => x.domain == 'other.test'), hasLength(1));
  });

  // Validation run 2026-11-13 (kvk.nl, nl.wikipedia.org): WebKit reports a
  // cookie whose Set-Cookie has no SameSite as "None". Merged, that made the
  // same cookie "None" (weak) when the browser saw it and "not set" when
  // only the server did.
  group('SameSite of a merged cookie', () {
    List<String?> merged(String header, String browser) => deriveCookies(
            inspection(
                server: serverSnap(setCookies: [header]),
                browser: browserSnap(cookies: [
                  cookie('a', sameSite: b(browser)),
                ])),
            now: now)
        .map((c) => c.sameSite)
        .toList();

    test('header without SameSite + browser "None" stays not set', () {
      expect(merged('a=1', 'None'), [null]);
    });

    test('header without SameSite + browser "Lax" keeps the browser value',
        () {
      expect(merged('a=1', 'Lax'), ['Lax']);
    });

    test('the header value wins', () {
      expect(merged('a=1; SameSite=Strict', 'None'), ['Strict']);
    });
  });

  test('unknown browser flags stay null, never false', () {
    final c = deriveCookies(
        inspection(browser: browserSnap(cookies: [cookie('x')])),
        now: now);
    expect(c.single.secure, isNull);
    expect(c.single.httpOnly, isNull);
    expect(c.single.path, isNull);
  });

  test('no server and no browser: no cookies', () {
    expect(deriveCookies(inspection()), isEmpty);
  });

  test('browser Max-Age style expiry maps to ISO', () {
    final c = deriveCookies(
        inspection(
            browser: browserSnap(cookies: [
          cookie('x', expires: Present(now, source: DataSource.browser))
        ])),
        now: now);
    expect(c.single.expires, '2026-01-01T12:00:00.000Z');
  });
}
