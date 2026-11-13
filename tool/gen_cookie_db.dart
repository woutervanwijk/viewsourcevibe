// Generates lib/utils/cookie_db.g.dart from the vendored Open Cookie Database
// CSV (tool/data/open-cookie-database.csv, pinned in tool/data/OCD_VERSION).
//
//   dart run tool/gen_cookie_db.dart
//
// Plain Dart (no Flutter imports) so it also runs as a script; the unit test
// calls [generateCookieDb] to check that the committed file is not stale.
import 'dart:io';

/// OCD category -> app category name (a `CookieCategory` member).
const _categoryMap = {
  'Marketing': 'advertising',
  'Analytics': 'analytics',
  'Functional': 'functional',
  'Personalization': 'functional',
  'Security': 'essential',
  'Necessary': 'essential',
};

/// Platforms that have social-network cookies (case-insensitive OCD
/// "Platform"). OCD has no "social" category and no X/Twitter platform; X
/// cookies are hand-curated in lib/utils/cookie_overrides.dart.
const socialPlatforms = {
  'facebook',
  'instagram',
  'linkedin',
  'pinterest',
  'tiktok',
  'snapchat',
  'reddit',
  'youtube',
  'twitter',
  'x',
};

/// Social rule, applied to OCD "Marketing" cookies of [socialPlatforms]:
/// a description about sharing, embeds, plugins, widgets, login or following
/// (the cookie supports a social feature) and NOT about advertising, pixels,
/// targeting, retargeting, conversion or measurement (then it is ad
/// tracking, e.g. _fbp, fr) becomes `social`. Everything else keeps its
/// mapped category.
final _socialFeature = RegExp(
  r'\b(share|sharing|embed\w*|plugins?|widgets?|login|sign[- ]?in|social|follow)\b',
  caseSensitive: false,
);
final _adTracking = RegExp(
  r'advertis|\bads?\b|pixel|target|retarget|conversion|measur',
  caseSensitive: false,
);

bool _isSocialByRule(String platform, String ocdCategory, String description) =>
    ocdCategory == 'Marketing' &&
    socialPlatforms.contains(platform.toLowerCase()) &&
    _socialFeature.hasMatch(description) &&
    !_adTracking.hasMatch(description);

/// RFC 4180 CSV parser: quoted fields, `""` escapes, newlines inside quotes,
/// CRLF or LF row endings.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var fieldStarted = false;

  void endField() {
    row.add(field.toString());
    field.clear();
    fieldStarted = false;
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"' && !fieldStarted) {
      inQuotes = true;
      fieldStarted = true;
    } else if (c == ',') {
      endField();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      field.write(c);
      fieldStarted = true;
    }
  }
  if (fieldStarted || field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// Parsed `key: value` lines of tool/data/OCD_VERSION.
Map<String, String> parseOcdVersion(String text) {
  final out = <String, String>{};
  for (final line in text.split('\n')) {
    final i = line.indexOf(':');
    if (i <= 0 || line.startsWith(' ')) continue;
    out.putIfAbsent(
        line.substring(0, i).trim(), () => line.substring(i + 1).trim());
  }
  return out;
}

String _dartString(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n').replaceAll('\r', r'\r').replaceAll('\t', r'\t')}'";

class CookieDbResult {
  CookieDbResult({
    required this.source,
    required this.rows,
    required this.entries,
    required this.wildcardEntries,
    required this.duplicateNames,
    required this.socialByPlatform,
  });

  final String source;
  final int rows;
  final int entries;
  final int wildcardEntries;
  final List<String> duplicateNames;
  final Map<String, int> socialByPlatform;
}

/// Builds the Dart source for [csv]. Deterministic: entries sorted by name;
/// for a name that occurs in several OCD rows the first CSV row wins.
CookieDbResult generateCookieDb(String csv, String versionFile) {
  final version = parseOcdVersion(versionFile);
  final table = parseCsv(csv);
  final header = table.first;
  int col(String name) {
    final i = header.indexOf(name);
    if (i < 0) throw FormatException('OCD CSV has no column "$name"');
    return i;
  }

  final cName = col('Cookie / Data Key name');
  final cPlatform = col('Platform');
  final cCategory = col('Category');
  final cDescription = col('Description');
  final cWildcard = col('Wildcard match');

  final entries =
      <String, ({String category, String? provider, bool wildcard})>{};
  final duplicates = <String>{};
  final socialByPlatform = <String, int>{};
  var rows = 0;

  for (final r in table.skip(1)) {
    if (r.length == 1 && r[0].trim().isEmpty) continue; // blank line
    rows++;
    final name = r[cName].trim();
    if (name.isEmpty) continue;
    final ocdCategory = r[cCategory].trim();
    var category = _categoryMap[ocdCategory];
    if (category == null) {
      throw FormatException('Unmapped OCD category "$ocdCategory" for $name');
    }
    final platform = r[cPlatform].trim();
    if (_isSocialByRule(platform, ocdCategory, r[cDescription])) {
      category = 'social';
      if (!entries.containsKey(name)) {
        socialByPlatform.update(platform, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    if (entries.containsKey(name)) {
      duplicates.add(name);
      continue;
    }
    entries[name] = (
      category: category,
      provider: platform.isEmpty ? null : platform,
      wildcard: r[cWildcard].trim() == '1',
    );
  }

  final names = entries.keys.toList()..sort();
  final wildcardCount = entries.values.where((e) => e.wildcard).length;

  final b = StringBuffer()
    ..writeln('// GENERATED by tool/gen_cookie_db.dart - do not edit.')
    ..writeln('// Regenerate with: dart run tool/gen_cookie_db.dart')
    ..writeln('//')
    ..writeln('// Data: Open Cookie Database (OCD), '
        'https://github.com/jkwakman/Open-Cookie-Database')
    ..writeln('// Commit ${version['commit']} (${version['date']}), '
        'license ${version['license']}.')
    ..writeln('// Source: ${version['url']}')
    ..writeln('// Modified: converted to Dart, categories mapped '
        '(Marketing->advertising, Analytics->analytics,')
    ..writeln('// Functional/Personalization->functional, '
        'Security/Necessary->essential), and some')
    ..writeln('// Marketing cookies of social platforms re-categorised as '
        'social (see the rule in the generator).')
    ..writeln("// See the OCD license (Apache-2.0) in the repository's "
        'THIRD_PARTY_NOTICES.md.')
    ..writeln()
    ..writeln("import 'package:view_source_vibe/utils/cookie_utils.dart';")
    ..writeln()
    ..writeln('/// OCD commit this table was generated from.')
    ..writeln('const String ocdCommit = ${_dartString(version['commit']!)};')
    ..writeln('const String ocdCommitDate = ${_dartString(version['date']!)};')
    ..writeln()
    ..writeln('/// Cookie name -> (category, provider, wildcard). '
        'A wildcard entry matches every')
    ..writeln('/// cookie name that starts with the key '
        '(OCD "Wildcard match" = 1).')
    ..writeln('const Map<String, CookieDbEntry> generatedCookieDb = {');
  for (final n in names) {
    final e = entries[n]!;
    final prov = e.provider == null ? 'null' : _dartString(e.provider!);
    // Laid out the way `dart format` does (80 columns, short style) so the
    // generated file is format-clean without a second pass.
    final key = _dartString(n);
    final oneLine =
        '  $key: (CookieCategory.${e.category}, $prov, ${e.wildcard}),';
    if (oneLine.length <= 80) {
      b.writeln(oneLine);
    } else {
      b
        ..writeln('  $key: (')
        ..writeln('    CookieCategory.${e.category},')
        ..writeln('    $prov,')
        ..writeln('    ${e.wildcard}')
        ..writeln('  ),');
    }
  }
  b.writeln('};');

  return CookieDbResult(
    source: b.toString(),
    rows: rows,
    entries: entries.length,
    wildcardEntries: wildcardCount,
    duplicateNames: duplicates.toList()..sort(),
    socialByPlatform: Map.fromEntries(socialByPlatform.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key))),
  );
}

void main() {
  final csv = File('tool/data/open-cookie-database.csv').readAsStringSync();
  final version = File('tool/data/OCD_VERSION').readAsStringSync();
  final result = generateCookieDb(csv, version);
  File('lib/utils/cookie_db.g.dart').writeAsStringSync(result.source);
  stdout
    ..writeln('OCD rows: ${result.rows}')
    ..writeln('Generated entries: ${result.entries} '
        '(wildcard: ${result.wildcardEntries})')
    ..writeln('Duplicate names (first row wins): '
        '${result.duplicateNames.length} ${result.duplicateNames}')
    ..writeln('Made social by rule: '
        '${result.socialByPlatform.values.fold(0, (a, b) => a + b)} '
        '${result.socialByPlatform}');
}
