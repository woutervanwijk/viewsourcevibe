import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/utils/site.dart';

import '../../tool/gen_public_suffix.dart';

void main() {
  test('registrable domain', () {
    expect(registrableDomain('www.example.co.uk'), 'example.co.uk');
    expect(registrableDomain('a.b.rijksoverheid.nl'), 'rijksoverheid.nl');
    expect(registrableDomain('foo.github.io'), 'foo.github.io');
    expect(registrableDomain('x.y.kawasaki.jp'), 'x.y.kawasaki.jp');
    expect(registrableDomain('www.city.kawasaki.jp'), 'city.kawasaki.jp');
    expect(registrableDomain('WWW.Example.COM.'), 'example.com');
    expect(registrableDomain('a.test'), 'a.test');
    expect(registrableDomain('co.uk'), 'co.uk');
  });

  test('hosts that are not domains are returned unchanged', () {
    for (final h in ['localhost', '192.168.1.1', '[::1]', '']) {
      expect(registrableDomain(h), h);
    }
  });

  test('same site', () {
    expect(sameSite('www.x.nl', 'static.x.nl'), isTrue);
    expect(sameSite('cdn.example.com', 'www.example.com'), isTrue);
    expect(sameSite('a.github.io', 'b.github.io'), isFalse);
    expect(sameSite('x.nl', 'x.com'), isFalse);
    expect(sameSite('', ''), isFalse);
    expect(sameSite('localhost', 'localhost'), isTrue);
    expect(sameSite('1.2.3.4', '1.2.3.5'), isFalse);
  });

  test('the committed generated file is not stale', () {
    final dat = File('tool/data/public_suffix_list.dat').readAsStringSync();
    final version = File('tool/data/PSL_VERSION').readAsStringSync();
    expect(File('lib/utils/public_suffix.g.dart').readAsStringSync(),
        generatePublicSuffix(dat, version));
  });
}
