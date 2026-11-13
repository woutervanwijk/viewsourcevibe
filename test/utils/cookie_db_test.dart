import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/utils/cookie_db.g.dart';
import 'package:view_source_vibe/utils/cookie_overrides.dart';
import 'package:view_source_vibe/utils/cookie_utils.dart';

import '../../tool/gen_cookie_db.dart';

void main() {
  CookieCategory? cat(String name) => CookieUtils.lookupEntry(name)?.$1;
  String? prov(String name) => CookieUtils.lookupEntry(name)?.$2;

  test('cookies that append an id to a non-wildcard OCD name still match', () {
    // OCD lists these without the wildcard flag, but real cookies are named
    // Hm_lvt_<siteid>, yith_wcwl_session_<hash>, tc_sample_<id>, ...
    for (final (cookie, provider) in [
      ('Hm_lvt_0123456789abcdef', 'Baidu'),
      ('Hm_lpvt_0123456789abcdef', 'Baidu'),
      ('yith_wcwl_session_8a1b2c', 'Yithemes.com'),
      ('tc_sample_12345', 'Command Act'),
      ('lihc_auth_en', 'LinkedIn'),
    ]) {
      expect(CookieUtils.lookupEntry(cookie)?.$2, provider, reason: cookie);
    }
  });

  group('generated cookie db', () {
    test('is in sync with the vendored OCD CSV and OCD_VERSION', () {
      final result = generateCookieDb(
        File('tool/data/open-cookie-database.csv').readAsStringSync(),
        File('tool/data/OCD_VERSION').readAsStringSync(),
      );
      final committed = File('lib/utils/cookie_db.g.dart').readAsStringSync();
      expect(committed, result.source,
          reason: 'stale: run `dart run tool/gen_cookie_db.dart`');
      expect(generatedCookieDb.length, result.entries);
      expect(ocdCommit, hasLength(40));
    });

    test('CSV parser handles quotes, escaped quotes, newlines and CRLF', () {
      expect(parseCsv('a,"b,c","d ""q"" e"\r\n"x\ny",,z\n'), [
        ['a', 'b,c', 'd "q" e'],
        ['x\ny', '', 'z'],
      ]);
    });

    test('wildcard flag comes from OCD, not from a trailing separator', () {
      // OCD wildcard row without a trailing "_" ...
      expect(generatedCookieDb['_gat']!.$3, isTrue);
      expect(CookieUtils.analyze('_gat_UA-123=1', 'Server').category,
          CookieCategory.analytics);
      expect(CookieUtils.analyze('_gat_UA-123=1', 'Server').provider,
          'Google Analytics');
      // ... and a non-wildcard OCD name ending in "_" is exact only, unless
      // it is in forcedWildcard (Hm_lvt_<siteid> really appends an id).
      expect(generatedCookieDb['ref-']!.$3, isFalse);
      expect(CookieUtils.lookupEntry('ref-123'), isNull);
      expect(generatedCookieDb['Hm_lvt_']!.$3, isFalse);
      expect(forcedWildcard, contains('Hm_lvt_'));
      expect(cat('Hm_lvt_'), CookieCategory.analytics);
    });

    test('longest wildcard prefix wins', () {
      // _gac_ (Google Analytics) and _gac_gb_ (Google Ads) are both wildcards.
      expect(prov('_gac_xyz'), 'Google Analytics');
      expect(prov('_gac_gb_xyz'), 'Google Ads');
      expect(CookieUtils.analyze('_gac_gb_xyz=1', 'Server').provider,
          'Google Ads');
      // _gat_gtag_ beats _gat.
      expect(CookieUtils.lookupEntry('_gat_gtag_UA_1')!.$1,
          CookieCategory.analytics);
      expect(prov('_gat_gtag_UA_1'), 'Google Analytics');
      // RD Station's _sp_root_domain_test_ is exact-only in OCD, so the
      // hand-curated Snowplow wildcard _sp_ applies to longer names.
      expect(prov('_sp_root_domain_test_'), 'RD Station');
      expect(prov('_sp_root_domain_test_x'), 'Snowplow');
      final keys = CookieUtils.prefixKeysForTest;
      expect(keys.indexOf('_gac_gb_'), lessThan(keys.indexOf('_gac_')));
    });

    test('wildcard keys shorter than 3 characters match only exactly', () {
      final short = {
        for (final e in {...generatedCookieDb, ...cookieOverrides}.entries)
          if (e.value.$3 && e.key.length < CookieUtils.minWildcardLength) e.key,
      };
      // OCD also flags tp and _s as wildcards, but those names have an earlier
      // exact-only OCD row, which wins (first row per name).
      expect(short, unorderedEquals(['SR', 'CT', 'P_']));
      expect(CookieUtils.prefixKeysForTest.where((k) => k.length < 3), isEmpty);
      expect(cat('SR'), CookieCategory.advertising);
      expect(CookieUtils.lookupEntry('SRfoo'), isNull);
      expect(CookieUtils.lookupEntry('P_foo'), isNull);
      expect(CookieUtils.lookupEntry('_session_id'), isNull);
    });

    test('social category: rule-based, not ad tracking', () {
      final all = {...generatedCookieDb, ...cookieOverrides};
      final social = all.entries
          .where((e) => e.value.$1 == CookieCategory.social)
          .map((e) => e.key)
          .toSet();
      expect(social.length, greaterThanOrEqualTo(15));
      expect(social, containsAll(['lidc', 'bcookie', 'ig_cb', 'ttwid']));
      expect(cat('li_sugr'), CookieCategory.advertising);
      expect(cat('_fbp'), CookieCategory.advertising);
      expect(cat('fr'), CookieCategory.advertising);
      expect(cat('_ttp'), CookieCategory.advertising);
    });

    test('OCD wins: overrides hold only names that are not in OCD', () {
      final dup =
          cookieOverrides.keys.where(generatedCookieDb.containsKey).toList();
      expect(dup, isEmpty, reason: 'move to forcedCategory or delete');
      for (final k in forcedCategory.keys) {
        expect(generatedCookieDb.containsKey(k), isTrue,
            reason: 'forcedCategory $k is not an OCD name');
      }
      // OCD categories replaced the old hand-curated ones.
      expect(cat('c_user'), CookieCategory.advertising);
      expect(cat('SID'), CookieCategory.advertising);
    });

    test('hand-curated names still resolve through the overrides', () {
      expect(cat('gtm_pageview_count'), CookieCategory.analytics);
      expect(prov('gtm_pageview_count'), 'Google Tag Manager');
      expect(cat('gtm_foo'), CookieCategory.analytics);
      expect(cat('li_at'), CookieCategory.essential);
      expect(prov('li_at'), 'LinkedIn');
      expect(CookieUtils.analyze('li_at=1', 'Server').provider, 'LinkedIn');
    });

    test('no table entry is categorised unknown', () {
      final all = {...generatedCookieDb, ...cookieOverrides};
      expect(all.values.where((e) => e.$1 == CookieCategory.unknown), isEmpty);
      expect(all.keys.where((k) => k.isEmpty || k != k.trim()), isEmpty);
    });
  });
}
