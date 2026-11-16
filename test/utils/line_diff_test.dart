import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/utils/line_diff.dart';

void main() {
  test('one inserted line is one added line', () {
    final d = unifiedDiff('a\nb\nc\nd\ne\n', 'a\nb\nX\nc\nd\ne\n',
        fromName: 'source/server.html', toName: 'source/browser-dom.html')!;
    expect(
        d,
        '--- source/server.html\n+++ source/browser-dom.html\n'
        '@@ -1,5 +1,6 @@\n a\n b\n+X\n c\n d\n e\n');
  });

  test(
      'equal texts give null', () => expect(unifiedDiff('a\n', 'a\n'), isNull));

  test('too many changes give null', () {
    final a = List.generate(3000, (i) => 'a$i').join('\n');
    final b = List.generate(3000, (i) => 'b$i').join('\n');
    expect(unifiedDiff(a, b), isNull);
  });

  test('changes far apart become separate hunks', () {
    final a = List.generate(30, (i) => 'l$i');
    final b = [...a]..[2] = 'X';
    b[27] = 'Y';
    final d = unifiedDiff('${a.join('\n')}\n', '${b.join('\n')}\n')!;
    expect('@@'.allMatches(d).length, 4); // two hunk headers
  });

  test('a missing final newline is marked', () {
    final d = unifiedDiff('a\nb', 'a\nc')!;
    expect(
        d,
        '--- a\n+++ b\n@@ -1,2 +1,2 @@\n a\n-b\n'
        '\\ No newline at end of file\n+c\n'
        '\\ No newline at end of file\n');
  });

  group('patch', () {
    final hasPatch = () {
      try {
        return Process.runSync('patch', ['--version']).exitCode == 0;
      } catch (_) {
        return false;
      }
    }();

    String applyPatch(String before, String after) {
      final dir = Directory.systemTemp.createTempSync('line_diff_test');
      try {
        final file = File('${dir.path}/before.txt')..writeAsStringSync(before);
        File('${dir.path}/diff.patch')
            .writeAsStringSync(unifiedDiff(before, after)!);
        final r = Process.runSync('patch', ['before.txt', 'diff.patch'],
            workingDirectory: dir.path);
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
        return file.readAsStringSync();
      } finally {
        dir.deleteSync(recursive: true);
      }
    }

    test('patch accepts the output', () {
      if (!hasPatch) return markTestSkipped('patch is not installed');
      final a = '${List.generate(40, (i) => 'line $i').join('\n')}\n';
      final lines = List.generate(40, (i) => 'line $i')
        ..removeAt(5)
        ..insert(20, 'new')
        ..[35] = 'changed';
      final b = '${lines.join('\n')}\n';
      expect(applyPatch(a, b), b);
    });

    test('patch reproduces a text without a final newline', () {
      if (!hasPatch) return markTestSkipped('patch is not installed');
      expect(applyPatch('a\nb\nc', 'a\nb\nd'), 'a\nb\nd');
      expect(applyPatch('a\nb\n', 'a\nb\nc'), 'a\nb\nc');
      expect(applyPatch('a\nb', 'a\nb\nc\n'), 'a\nb\nc\n');
    });

    test('patch handles an empty side', () {
      if (!hasPatch) return markTestSkipped('patch is not installed');
      expect(applyPatch('', 'a\nb\n'), 'a\nb\n');
    });
  });
}
