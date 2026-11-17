import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/batch_runner.dart';
import 'package:view_source_vibe/services/derive/inspection_summary.dart';

class FakeBatchTarget implements BatchTarget {
  final calls = <String>[];

  /// Host -> polls it stays pending; -1 = forever.
  final pendingFor = <String, int>{};
  final failOpen = <String>{};
  void Function(Uri url)? onOpen;
  Uri? _current;
  final _polls = <String, int>{};

  @override
  Future<void> open(Uri url) async {
    calls.add('open $url');
    if (failOpen.contains(url.host)) {
      throw StateError('cannot open ${url.host}');
    }
    _current = url;
    onOpen?.call(url);
  }

  @override
  List<String> pending() {
    final host = _current!.host;
    final limit = pendingFor[host] ?? 0;
    final n = _polls[host] = (_polls[host] ?? 0) + 1;
    return limit == -1 || n <= limit ? ['sovereignty'] : [];
  }

  @override
  void collectLate() => calls.add('collectLate');

  @override
  Future<void> clearSiteData(Uri url) async => calls.add('clear $url');

  @override
  Future<void> measureFreshLoad() async => calls.add('fresh');

  @override
  void watchSovereignty(bool watching) =>
      calls.add('watchSovereignty $watching');

  @override
  InspectionSummary summary() => InspectionSummary(
        [],
        {for (final k in summaryFactKeys) k: null}..['url'] =
            _current.toString(),
      );

  @override
  List<int> package() {
    calls.add('package $_current');
    return ZipEncoder()
        .encode(Archive()..addFile(ArchiveFile.string('a', 'b')));
  }
}

void main() {
  late Directory tmp;
  const fast =
      BatchOptions(timeout: Duration(milliseconds: 50), linger: Duration.zero);

  setUp(() => tmp = Directory.systemTemp.createTempSync('batch_runner_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  BatchRunner runner(FakeBatchTarget t) => BatchRunner(t,
      poll: const Duration(milliseconds: 1),
      settle: Duration.zero,
      lateWait: Duration.zero,
      workDir: () async => tmp);

  test('sites are visited one by one, in order', () async {
    final t = FakeBatchTarget();
    final r = runner(t);
    await r.run([Uri.parse('https://a.test/'), Uri.parse('https://b.test/')],
        options: fast);
    expect(t.calls.where((c) => c.startsWith('open')),
        ['open https://a.test/', 'open https://b.test/']);
    expect(t.calls.indexOf('package https://a.test/'),
        lessThan(t.calls.indexOf('open https://b.test/')));
    expect(r.rows.map((x) => x.state), ['done', 'done']);
    expect(t.calls.first, 'watchSovereignty true');
    expect(t.calls.last, 'watchSovereignty false');
    expect(t.calls.indexOf('clear https://a.test/'),
        lessThan(t.calls.indexOf('open https://a.test/')));
  });

  test('a site that never settles is exported as timed out', () async {
    final t = FakeBatchTarget()..pendingFor['slow.test'] = -1;
    final r = runner(t);
    await r.run([Uri.parse('https://slow.test/')], options: fast);
    final row = r.rows.single;
    expect(row.state, 'timed out');
    expect(row.pending, ['sovereignty']);
    expect(row.summary, isNotNull);
    expect(File('${tmp.path}/sites/${row.slug}.zip').existsSync(), isTrue);
  });

  test('a failing site does not stop the batch', () async {
    final t = FakeBatchTarget()..failOpen.add('bad.test');
    final r = runner(t);
    await r.run([Uri.parse('https://bad.test/'), Uri.parse('https://ok.test/')],
        options: fast);
    expect(r.rows.map((x) => x.state), ['failed', 'done']);
    expect(r.rows.first.error, contains('cannot open bad.test'));
    expect(r.rows.first.summary, isNull);
  });

  test('cancel keeps finished sites', () async {
    final t = FakeBatchTarget()..pendingFor['b.test'] = -1;
    t.onOpen = (u) {
      if (u.host == 'b.test') {
        Future.delayed(const Duration(milliseconds: 10), () => cancelNow());
      }
    };
    final r = runner(t);
    cancelNow = r.cancel;
    await r.run([Uri.parse('https://a.test/'), Uri.parse('https://b.test/')],
        options: const BatchOptions(
            timeout: Duration(seconds: 30), linger: Duration.zero));
    expect(r.rows.length, 1);
    expect(r.running, isFalse);
    expect(t.calls.last, 'watchSovereignty false');
    expect(await r.writeZip(), isNotNull);
  });

  test('slugs are unique', () async {
    final t = FakeBatchTarget();
    final r = runner(t);
    await r.run([
      Uri.parse('https://example.com/a'),
      Uri.parse('https://example.com/a?x=1'),
    ], options: fast);
    final slugs = r.rows.map((x) => x.slug).toList();
    expect(slugs[0], isNot(slugs[1]));
    expect(slugs[1], endsWith('-2'));
  });

  test('the zip holds the summary and one package per site', () async {
    final t = FakeBatchTarget();
    final r = runner(t);
    await r.run([Uri.parse('https://a.test/'), Uri.parse('https://b.test/')],
        options: fast);
    final zip =
        ZipDecoder().decodeBytes((await r.writeZip())!.readAsBytesSync());
    expect(
        zip.files.map((f) => f.name),
        containsAll([
          'summary.html',
          'summary.csv',
          'summary.json',
          'sites/a-test.zip',
          'sites/b-test.zip'
        ]));
  });

  test('writeZip is null when no site finished', () async {
    expect(await runner(FakeBatchTarget()).writeZip(), isNull);
  });

  test('a failing work dir ends the run with an error', () async {
    final t = FakeBatchTarget();
    final r = BatchRunner(t, workDir: () async => throw StateError('no disk'));
    await r.run([Uri.parse('https://a.test/')], options: fast);
    expect(r.running, isFalse);
    expect(r.error, contains('no disk'));
    expect(t.calls.last, 'watchSovereignty false');
  });

  test('parseBatchInput', () {
    final p = parseBatchInput('kvk.nl\n\n# comment\nhttps://kvk.nl/\n'
        'javascript:alert(1)\nfile:///etc/passwd\n  http://a.test/x  \nnot a url');
    expect(
        p.urls.map((u) => u.toString()), ['https://kvk.nl', 'http://a.test/x']);
    expect(
        p.rejected, ['javascript:alert(1)', 'file:///etc/passwd', 'not a url']);
  });

  test('parseBatchInput caps the list and keeps ports', () {
    final p = parseBatchInput('a.test:8080\nb.test\nc.test', max: 2);
    expect(p.urls.map((u) => u.toString()),
        ['https://a.test:8080', 'https://b.test']);
  });
}

void Function() cancelNow = () {};
