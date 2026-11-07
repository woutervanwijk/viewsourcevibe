import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Widgets and screens only show what the central store derived. They do not
/// fetch, parse or sniff data themselves (Task 11, B32/B34).
const _forbidden = <String>[
  "import 'dart:io'",
  "import 'package:http/",
  "import 'package:html/parser.dart'",
  "import 'package:html/dom.dart'",
  "import 'package:xml/",
  'HttpClient(',
  'jsonDecode(',
  'RegExp(',
  'probeResult[',
];

/// {file: {pattern: reason}}. Every entry needs a reason; a new occurrence
/// anywhere else fails the test.
const _allowlist = <String, Map<String, String>>{
  'lib/widgets/browser_view.dart': {
    "import 'dart:io'":
        'Platform.isMacOS/isAndroid: per-platform WebView setup',
    'RegExp(': 'parses Platform.operatingSystemVersion (Android API level)',
  },
  'lib/widgets/dom_tree_view.dart': {
    "import 'dart:io'": 'Platform.isIOS: font size only',
  },
  'lib/widgets/contextmenu.dart': {
    'RegExp(': 'finds a URL inside the text the user selected in the editor',
  },
};

void main() {
  final files = [
    for (final dir in ['lib/widgets', 'lib/screens'])
      ...Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
  ];

  test('every allowlist entry has a reason', () {
    for (final e in _allowlist.entries) {
      for (final r in e.value.entries) {
        expect(r.value.trim(), isNotEmpty, reason: '${e.key} ${r.key}');
      }
    }
  });

  test('allowlisted patterns still occur (no stale entries)', () {
    for (final e in _allowlist.entries) {
      final text = File(e.key).readAsStringSync();
      for (final pattern in e.value.keys) {
        expect(text.contains(pattern), isTrue,
            reason: '${e.key} no longer uses $pattern: remove the entry');
      }
    }
  });

  test('no data logic in lib/widgets or lib/screens', () {
    final violations = <String>[];
    for (final f in files) {
      final path = f.path;
      final allowed = _allowlist[path] ?? const {};
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final p in _forbidden) {
          if (line.contains(p) && !allowed.containsKey(p)) {
            violations.add('$path:${i + 1}: $p');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
