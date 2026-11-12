import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/detection/catalog.dart';
import 'package:view_source_vibe/services/jurisdiction.dart';

void main() {
  group('relationTo mutual adequacy', () {
    test('EU home: adequate countries incl. BR', () {
      expect(relationTo('GB', 'EU'), Relation.adequate);
      expect(relationTo('BR', 'EU'), Relation.adequate);
      expect(relationTo('US', 'EU'), Relation.foreign);
    });
    test('homes that recognise the EU see it as adequate', () {
      for (final h in ['GB', 'CH', 'JP', 'AR', 'UY', 'IL', 'AD']) {
        expect(relationTo('DE', h), Relation.adequate, reason: h);
      }
    });
    test('CA, NZ, KR, BR homes see the EU as foreign', () {
      for (final h in ['CA', 'NZ', 'KR', 'BR', 'AU', 'US']) {
        expect(relationTo('DE', h), Relation.foreign, reason: h);
      }
    });
    test('GB and CH recognise each other', () {
      expect(relationTo('CH', 'GB'), Relation.adequate);
      expect(relationTo('GB', 'CH'), Relation.adequate);
    });
    test('unrelated adequate countries stay foreign', () {
      expect(relationTo('GB', 'JP'), Relation.foreign);
    });
  });

  test('.is is Iceland (EEA), not a generic TLD', () {
    final s = detectSiteJurisdiction(host: 'example.is');
    expect(s?.jurisdiction, eu);
  });

  test('catalog origins follow the parent company HQ', () {
    const expected = {
      'Heap': 'FR',
      'Smartlook': 'US',
      'Adjust': 'US',
      'Hotjar': 'FR',
      'Cookiebot': 'DE',
      'CookieFirst': 'NL',
      'Ezoic': 'US',
      'Trustpilot': 'GB',
    };
    expected.forEach((name, origin) {
      expect(entityNamed(name)?.origin, origin, reason: name);
    });
  });
}
