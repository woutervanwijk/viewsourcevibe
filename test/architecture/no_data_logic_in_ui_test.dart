import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Widgets and screens only show what the central store derived. They do not
/// fetch, parse or sniff data themselves (Task 11, B32/B34).
///
/// Imports are matched on the library name with either quote style and any
/// `as`/`show`/`hide` clause. Comments (`//` and `/* */`) are skipped.
RegExp _import(String library) =>
    RegExp('^\\s*(import|export)\\s+[\'"]$library');

final _forbidden = <String, RegExp>{
  'dart:io import': _import(r'dart:io[\x27"]'),
  'package:http import': _import('package:http/'),
  'package:html/parser.dart import':
      _import(r'package:html/parser\.dart[\x27"]'),
  'package:html/dom.dart import': _import(r'package:html/dom\.dart[\x27"]'),
  'package:xml import': _import('package:xml/'),
  'HttpClient(': RegExp(r'HttpClient\('),
  'jsonDecode(': RegExp(r'jsonDecode\('),
  'RegExp(': RegExp(r'RegExp\('),
  'probeResult[': RegExp(r'probeResult\['),
};

/// {file: {pattern: (allowed occurrences, reason)}}. Every entry needs a
/// reason and a count; one more occurrence than pinned fails the test.
const _allowlist = <String, Map<String, (int, String)>>{
  'lib/widgets/browser_view.dart': {
    'dart:io import': (
      1,
      'Platform.isMacOS/isAndroid: per-platform WebView setup'
    ),
    'RegExp(': (2, 'parses Platform.operatingSystemVersion (Android API)'),
  },
  'lib/widgets/dom_tree_view.dart': {
    'dart:io import': (1, 'Platform.isIOS: font size only'),
  },
  'lib/widgets/contextmenu.dart': {
    'RegExp(': (1, 'finds a URL inside the text the user selected'),
  },
};

/// Code lines with comments blanked out, keeping the line numbers.
List<String> _codeLines(String text) {
  final out = <String>[];
  var inBlock = false;
  for (final line in text.split('\n')) {
    final result = StringBuffer();
    var i = 0;
    while (i < line.length) {
      if (inBlock) {
        final end = line.indexOf('*/', i);
        if (end < 0) {
          i = line.length;
        } else {
          inBlock = false;
          i = end + 2;
        }
      } else if (line.startsWith('/*', i)) {
        inBlock = true;
        i += 2;
      } else if (line.startsWith('//', i)) {
        break;
      } else {
        result.write(line[i]);
        i++;
      }
    }
    out.add(result.toString());
  }
  return out;
}

void main() {
  final files = [
    for (final dir in ['lib/widgets', 'lib/screens'])
      ...Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
  ];

  test('every allowlist entry has a reason and a count', () {
    for (final e in _allowlist.entries) {
      for (final r in e.value.entries) {
        expect(r.value.$2.trim(), isNotEmpty, reason: '${e.key} ${r.key}');
        expect(r.value.$1, greaterThan(0), reason: '${e.key} ${r.key}');
        expect(_forbidden.containsKey(r.key), isTrue, reason: r.key);
      }
    }
  });

  test('the matchers see double quotes and as/show clauses, skip comments', () {
    expect(_forbidden['dart:io import']!.hasMatch('import "dart:io";'), isTrue);
    expect(
        _forbidden['dart:io import']!
            .hasMatch("import 'dart:io' show File, Platform;"),
        isTrue);
    expect(
        _forbidden['package:http import']!
            .hasMatch("import 'package:http/http.dart' as http;"),
        isTrue);
    expect(
        _forbidden['package:html/parser.dart import']!
            .hasMatch('import "package:html/parser.dart" show parse;'),
        isTrue);
    expect(
        _forbidden['dart:io import']!.hasMatch("import 'dart:ui';"), isFalse);
    expect(_codeLines('/* RegExp(a)\n RegExp(b) */\nfoo(); // RegExp(c)'),
        ['', '', 'foo(); ']);
  });

  test('allowlisted entries match their pinned count exactly', () {
    for (final e in _allowlist.entries) {
      final lines = _codeLines(File(e.key).readAsStringSync());
      for (final r in e.value.entries) {
        final n = lines.where(_forbidden[r.key]!.hasMatch).length;
        expect(n, r.value.$1,
            reason: '${e.key} has $n x ${r.key}, pinned ${r.value.$1}: '
                'a new one needs its own reason, a removed one a lower count');
      }
    }
  });

  test('no data logic in lib/widgets or lib/screens', () {
    final violations = <String>[];
    for (final f in files) {
      final allowed = _allowlist[f.path] ?? const {};
      final lines = _codeLines(f.readAsStringSync());
      for (var i = 0; i < lines.length; i++) {
        for (final p in _forbidden.entries) {
          if (!allowed.containsKey(p.key) && p.value.hasMatch(lines[i])) {
            violations.add('${f.path}:${i + 1}: ${p.key}');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
