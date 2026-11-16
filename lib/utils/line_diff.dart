import 'dart:convert';

/// A unified diff (as `diff -u` writes it, accepted by `patch`) between two
/// texts, compared line by line with Myers' O(ND) algorithm.
///
/// Null when the texts hold the same lines, or when more than [maxChanges]
/// lines are added plus removed (the diff is then not worth reading).
/// Lines are split like [LineSplitter]; the output uses `\n`.
String? unifiedDiff(
  String before,
  String after, {
  String fromName = 'a',
  String toName = 'b',
  int context = 3,
  int maxChanges = 2000,
}) {
  final a = const LineSplitter().convert(before);
  final b = const LineSplitter().convert(after);
  final aNoEol = a.isNotEmpty && !_endsWithEol(before);
  final bNoEol = b.isNotEmpty && !_endsWithEol(after);
  // A last line without a newline is not the same line as one with it.
  final ka = [...a];
  final kb = [...b];
  if (aNoEol) ka[ka.length - 1] = '${ka.last}\u0000';
  if (bNoEol) kb[kb.length - 1] = '${kb.last}\u0000';

  var head = 0;
  while (head < ka.length && head < kb.length && ka[head] == kb[head]) {
    head++;
  }
  var tail = 0;
  while (tail < ka.length - head &&
      tail < kb.length - head &&
      ka[ka.length - 1 - tail] == kb[kb.length - 1 - tail]) {
    tail++;
  }
  final middle = _myers(ka.sublist(head, ka.length - tail),
      kb.sublist(head, kb.length - tail), maxChanges);
  if (middle == null || middle.isEmpty) return null;

  // Ops: ' ' keep, '-' remove, '+' add; the line is taken from a or b.
  final ops = <String>[
    ...List.filled(head, ' '),
    ...middle,
    ...List.filled(tail, ' '),
  ];
  // oldAt[i] / newAt[i]: lines of each side before op i.
  final oldAt = List<int>.filled(ops.length + 1, 0);
  final newAt = List<int>.filled(ops.length + 1, 0);
  for (var i = 0; i < ops.length; i++) {
    oldAt[i + 1] = oldAt[i] + (ops[i] == '+' ? 0 : 1);
    newAt[i + 1] = newAt[i] + (ops[i] == '-' ? 0 : 1);
  }

  final out = StringBuffer()
    ..writeln('--- $fromName')
    ..writeln('+++ $toName');
  final changes = [
    for (var i = 0; i < ops.length; i++)
      if (ops[i] != ' ') i
  ];
  var g = 0;
  while (g < changes.length) {
    var last = g;
    while (last + 1 < changes.length &&
        changes[last + 1] - changes[last] - 1 <= 2 * context) {
      last++;
    }
    final start = (changes[g] - context).clamp(0, ops.length);
    final end = (changes[last] + 1 + context).clamp(0, ops.length);
    final oldCount = oldAt[end] - oldAt[start];
    final newCount = newAt[end] - newAt[start];
    // An empty range is addressed by the line before it.
    final oldStart = oldAt[start] + (oldCount == 0 ? 0 : 1);
    final newStart = newAt[start] + (newCount == 0 ? 0 : 1);
    out.writeln('@@ -${_range(oldStart, oldCount)} '
        '+${_range(newStart, newCount)} @@');
    for (var i = start; i < end; i++) {
      final op = ops[i];
      final oldIndex = oldAt[i];
      final newIndex = newAt[i];
      out.writeln(
          '${op == ' ' ? ' ' : op}${op == '+' ? b[newIndex] : a[oldIndex]}');
      final lastOld = op != '+' && oldIndex == a.length - 1 && aNoEol;
      final lastNew = op == '+' && newIndex == b.length - 1 && bNoEol;
      final lastBoth = op == ' ' && newIndex == b.length - 1 && bNoEol;
      if (lastOld || lastNew || lastBoth) {
        out.writeln('\\ No newline at end of file');
      }
    }
    g = last + 1;
  }
  return out.toString();
}

bool _endsWithEol(String text) => text.endsWith('\n') || text.endsWith('\r');

String _range(int start, int count) => count == 1 ? '$start' : '$start,$count';

/// Edit script from [a] to [b] as ' ', '-', '+' ops, or null when it needs
/// more than [maxChanges] additions plus removals.
List<String>? _myers(List<String> a, List<String> b, int maxChanges) {
  final n = a.length;
  final m = b.length;
  final limit = n + m < maxChanges ? n + m : maxChanges;
  final offset = limit + 1;
  final v = List<int>.filled(2 * limit + 3, 0);
  // trace[d] holds V as it was before round d, for k in -d..d.
  final trace = <List<int>>[];
  var found = -1;
  for (var d = 0; d <= limit && found < 0; d++) {
    trace.add(v.sublist(offset - d, offset + d + 1));
    for (var k = -d; k <= d; k += 2) {
      var x = (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]))
          ? v[offset + k + 1]
          : v[offset + k - 1] + 1;
      var y = x - k;
      while (x < n && y < m && a[x] == b[y]) {
        x++;
        y++;
      }
      v[offset + k] = x;
      if (x >= n && y >= m) {
        found = d;
        break;
      }
    }
  }
  if (found < 0) return null;

  final ops = <String>[];
  var x = n;
  var y = m;
  for (var d = found; d > 0; d--) {
    final prev = trace[d];
    final k = x - y;
    final prevK = (k == -d || (k != d && prev[k - 1 + d] < prev[k + 1 + d]))
        ? k + 1
        : k - 1;
    final prevX = prev[prevK + d];
    final prevY = prevX - prevK;
    while (x > prevX && y > prevY) {
      ops.add(' ');
      x--;
      y--;
    }
    ops.add(x == prevX ? '+' : '-');
    if (x == prevX) {
      y--;
    } else {
      x--;
    }
  }
  while (x > 0 && y > 0) {
    ops.add(' ');
    x--;
    y--;
  }
  return ops.reversed.toList();
}
