import 'dart:ui' show PlatformDispatcher;

/// The EU and EEA share one legal framework (GDPR) and count as one
/// jurisdiction. Every other country is its own jurisdiction.
const eu = 'EU';

const euCountries = {
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR',
  'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK',
  'SI', 'ES', 'SE', 'IS', 'LI', 'NO', // EU + EEA
};

/// Countries with an EU adequacy decision (equivalent data protection).
/// The US decision (Data Privacy Framework) only covers certified companies,
/// which can't be verified automatically, so the US is not listed.
const euAdequateCountries = {
  'AD',
  'AR',
  'CA',
  'FO',
  'GG',
  'IL',
  'IM',
  'JP',
  'JE',
  'NZ',
  'KR',
  'CH',
  'GB',
  'UY',
};

/// Laws that give a government access to data held by its companies abroad.
const extraterritorialLaws = {
  'US': 'CLOUD Act',
  'CN': 'National Intelligence Law',
  'RU': 'SORM / Yarovaya law',
};

enum Relation { own, adequate, foreign, unknown }

/// Jurisdiction a country belongs to: [eu] for EU/EEA members, else itself.
String? jurisdictionOf(String? country) {
  if (country == null || country.isEmpty || country == '?') return null;
  final code = country.toUpperCase();
  return euCountries.contains(code) ? eu : code;
}

/// How [country] relates to the viewer's [home] jurisdiction.
Relation relationTo(String? country, String home) {
  final j = jurisdictionOf(country);
  if (j == null) return Relation.unknown;
  if (j == home) return Relation.own;
  // Adequacy is mutual in practice: the UK, Switzerland etc. also
  // recognise the EU as adequate.
  if (home == eu && euAdequateCountries.contains(j)) return Relation.adequate;
  if (j == eu && euAdequateCountries.contains(home)) return Relation.adequate;
  return Relation.foreign;
}

/// Home jurisdiction from the device locale, defaulting to the EU.
String defaultHomeJurisdiction() =>
    jurisdictionOf(PlatformDispatcher.instance.locale.countryCode) ?? eu;

String jurisdictionLabel(String jurisdiction) =>
    jurisdiction == eu ? 'EU/EEA' : jurisdiction;

/// Choices offered in settings and per site.
const homeJurisdictionChoices = [
  eu,
  'GB',
  'CH',
  'US',
  'CA',
  'AU',
  'NZ',
  'JP',
  'KR',
  'IN',
  'BR',
  'ZA',
  'SG',
  'CN',
];

const _regions = {
  'Europe (other)': {
    'GB',
    'CH',
    'UA',
    'RS',
    'BA',
    'ME',
    'MK',
    'AL',
    'MD',
    'BY',
    'RU',
    'TR',
    'FO',
    'GG',
    'JE',
    'IM',
    'AD',
    'MC',
    'SM',
    'VA',
    'GI'
  },
  'North America': {'US', 'CA', 'MX'},
  'Latin America': {
    'BR',
    'AR',
    'CL',
    'CO',
    'PE',
    'UY',
    'PY',
    'BO',
    'EC',
    'VE',
    'CR',
    'PA',
    'GT',
    'DO',
    'CU'
  },
  'Asia': {
    'CN',
    'JP',
    'KR',
    'IN',
    'SG',
    'HK',
    'TW',
    'VN',
    'ID',
    'MY',
    'TH',
    'PH',
    'PK',
    'BD',
    'KZ',
    'LK'
  },
  'Middle East': {
    'IL',
    'AE',
    'SA',
    'QA',
    'IR',
    'IQ',
    'JO',
    'KW',
    'BH',
    'OM',
    'LB'
  },
  'Oceania': {'AU', 'NZ'},
  'Africa': {'ZA', 'NG', 'EG', 'KE', 'MA', 'TN', 'GH', 'ET', 'DZ', 'MU'},
};

/// Display order of regions.
const regionOrder = [
  'EU/EEA',
  'Europe (other)',
  'North America',
  'Latin America',
  'Asia',
  'Middle East',
  'Oceania',
  'Africa',
  'Other',
  'Unknown',
];

String regionOf(String? country) {
  final j = jurisdictionOf(country);
  if (j == null) return 'Unknown';
  if (j == eu) return 'EU/EEA';
  for (final e in _regions.entries) {
    if (e.value.contains(j)) return e.key;
  }
  return 'Other';
}

/// Country-code TLDs that are mostly used generically (.io, .ai, ...), so they
/// say nothing about where the site owner is.
const _genericCcTlds = {
  'io',
  'co',
  'ai',
  'me',
  'tv',
  'fm',
  'ly',
  'to',
  'gg',
  'cc',
  'ws',
  'sh',
  'so',
  'vc',
  'la',
  'nu',
  'ac',
  'gl',
  'is',
  'am',
  'im',
  'xyz',
  'app',
  'dev',
};

/// A site's legal home, and how it was determined.
typedef SiteJurisdiction = ({String jurisdiction, String source});

/// Detects where the organisation behind a site is legally based:
/// 1. TLS certificate subject (OV/EV certificates name the legal entity),
/// 2. schema.org `addressCountry` in structured data,
/// 3. the country-code top-level domain.
SiteJurisdiction? detectSiteJurisdiction({
  required String host,
  Map? certificateSubject,
  List? structuredData,
}) {
  final subject = certificateSubject ?? const {};
  final certCountry = subject['JURISDICTIONC'] ??
      subject['1.3.6.1.4.1.311.60.2.1.3'] ??
      subject['Country'];
  final certJurisdiction = jurisdictionOf(certCountry?.toString());
  if (certJurisdiction != null) {
    final org = subject['Organization'];
    return (
      jurisdiction: certJurisdiction,
      source: 'TLS certificate: ${org != null ? '$org, ' : ''}C=$certCountry',
    );
  }

  final schemaCountry = _findAddressCountry(structuredData);
  if (schemaCountry != null) {
    return (
      jurisdiction: jurisdictionOf(schemaCountry)!,
      source: 'schema.org addressCountry: $schemaCountry',
    );
  }

  final tld = host.split('.').last.toLowerCase();
  if (tld == 'eu') return (jurisdiction: eu, source: 'Domain .eu');
  if (tld.length == 2 && !_genericCcTlds.contains(tld)) {
    // .uk is the only ccTLD that differs from its ISO code (GB).
    final country = tld == 'uk' ? 'GB' : tld.toUpperCase();
    return (jurisdiction: jurisdictionOf(country)!, source: 'Domain .$tld');
  }
  return null;
}

String? _findAddressCountry(Object? node, [int depth = 0]) {
  if (node == null || depth > 6) return null;
  if (node is Map) {
    final value = node['addressCountry'];
    final code = value is Map ? value['name'] : value;
    if (code is String && RegExp(r'^[A-Za-z]{2}$').hasMatch(code)) {
      return code.toUpperCase();
    }
    for (final v in node.values) {
      final found = _findAddressCountry(v, depth + 1);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final v in node) {
      final found = _findAddressCountry(v, depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}
