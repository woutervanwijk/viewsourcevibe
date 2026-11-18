import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/settings.dart';
import 'package:view_source_vibe/services/batch_runner.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import '../support/fake_batch_target.dart';
import 'html_service_lifecycle_test.dart'
    show FakeServerFetcher, FakeBrowserLoader, okSnapshot;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  const fast =
      BatchOptions(timeout: Duration(milliseconds: 50), linger: Duration.zero);

  setUp(() => tmp = Directory.systemTemp.createTempSync('batch_runner_test'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

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

  test('the row summary is the one of the exported package', () async {
    final t = FakeBatchTarget()..note = 'at export';
    // The page changes right after the export (e.g. a late request).
    t.onPackage = () => Future(() => t.note = 'later');
    final r = runner(t);
    await r.run([Uri.parse('https://a.test/')], options: fast);
    expect(r.rows.single.summary!.facts['finalUrl'], 'at export');
  });

  test('state and pending are those at the moment of export', () async {
    final t = FakeBatchTarget()..pendingFor['late.test'] = -1;
    // Settles after the timeout, during the late collect.
    t.onCollectLate = () => t.pendingFor['late.test'] = 0;
    final r = runner(t);
    await r.run([Uri.parse('https://late.test/')], options: fast);
    expect(r.rows.single.state, 'done');
    expect(r.rows.single.pending, isEmpty);
  });

  test('a site that did not load is failed, not clean', () async {
    final t = FakeBatchTarget()..notLoaded.add('dead.test');
    final r = runner(t);
    await r.run([Uri.parse('https://dead.test/')], options: fast);
    expect(r.rows.single.state, 'failed');
    expect(r.rows.single.error, 'the site did not load');
    expect(r.rows.single.summary, isNotNull);
  });

  test('a site that did not load names the server failure', () async {
    final t = FakeBatchTarget()
      ..notLoaded.add('dead.test')
      ..loadFailures['dead.test'] = 'Failed host lookup';
    final r = runner(t);
    await r.run([Uri.parse('https://dead.test/')], options: fast);
    expect(r.rows.single.state, 'failed');
    expect(r.rows.single.error, 'Failed host lookup');
  });

  test('navigating away during a site fails that row', () async {
    final t = FakeBatchTarget()..navigatedAway.add('a.test');
    final r = runner(t);
    await r.run([Uri.parse('https://a.test/'), Uri.parse('https://b.test/')],
        options: fast);
    expect(r.rows.map((x) => x.state), ['failed', 'done']);
    expect(r.rows.first.error, 'navigated away during the batch');
    expect(r.rows.first.summary, isNull);
    expect(t.calls, isNot(contains('package https://a.test/')));
  });

  test('a new run and dismiss remove the previous work directory', () async {
    final dirs = <Directory>[];
    final t = FakeBatchTarget();
    final r = BatchRunner(t,
        poll: const Duration(milliseconds: 1),
        settle: Duration.zero,
        lateWait: Duration.zero,
        workDir: () async =>
            (dirs..add(Directory('${tmp.path}/run${dirs.length}'))).last);
    await r.run([Uri.parse('https://a.test/')], options: fast);
    final zip1 = await r.writeZip();
    final zip2 = await r.writeZip();
    expect(zip2!.path, zip1!.path);
    expect(zip1.path, matches(RegExp(r'viewsourcevibe-batch-\d{14}\.zip$')));
    expect(dirs[0].listSync().whereType<File>(), hasLength(1));
    await r.run([Uri.parse('https://b.test/')], options: fast);
    expect(dirs[0].existsSync(), isFalse);
    expect(dirs[1].existsSync(), isTrue);
    r.dismiss();
    expect(dirs[1].existsSync(), isFalse);
  });

  test('a finished scan that failed or checked nothing is not pending',
      () async {
    final print = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {}; // the scan failure
    addTearDown(() => debugPrint = print);
    final fetcher = FakeServerFetcher();
    final service = HtmlService(
      store: InspectionStore(),
      detectionScanner: (texts) async => throw StateError('scan failed'),
      serverFetcher: fetcher,
      browserLoader: FakeBrowserLoader(),
      metadataExtractor: (html, baseUrl, {headers}) async => {},
    )..setAppSettings(AppSettings()..useBrowserByDefault = false);
    addTearDown(service.dispose);
    final load = service.loadUrl('https://dead.test/');
    await pumpEventQueue();
    fetcher.pending.single.completeError(const SocketException('no host'));
    await load.then((_) {}, onError: (_) {});
    service.detections;
    await pumpEventQueue();
    expect(service.detectionsView.scanning, isFalse);
    expect(service.detectionsView.complete, isFalse);
    expect(pendingAnalyses(service), isNot(contains('detections')));
  });

  group('HtmlServiceBatchTarget', () {
    late FakeServerFetcher fetcher;
    late HtmlService service;
    late HtmlServiceBatchTarget target;
    setUp(() {
      fetcher = FakeServerFetcher();
      service = HtmlService(
        store: InspectionStore(),
        detectionScanner: (texts) async => [],
        serverFetcher: fetcher,
        browserLoader: FakeBrowserLoader(),
        metadataExtractor: (html, baseUrl, {headers}) async => {},
      )..setAppSettings(AppSettings()..useBrowserByDefault = false);
      target = HtmlServiceBatchTarget(service);
    });
    tearDown(() => service.dispose());

    test('a dead URL is not loaded and names the failure', () async {
      final url = Uri.parse('https://dead.test/');
      final open = target.open(url);
      await pumpEventQueue();
      fetcher.pending.single
          .completeError(const SocketException('Failed host lookup'));
      await open.then((_) {}, onError: (_) {});
      expect(target.loaded(), isFalse);
      expect(target.loadFailure(), contains('Failed host lookup'));
    });

    test('a page loaded by the app is loaded and still on its URL', () async {
      final url = Uri.parse('https://a.test/');
      final open = target.open(url);
      await pumpEventQueue();
      fetcher.pending.single.complete(okSnapshot('https://a.test/', '<p>'));
      await open;
      expect(target.loaded(), isTrue);
      expect(target.stillOn(url), isTrue);
      final other = service.loadUrl('https://b.test/');
      await pumpEventQueue();
      fetcher.pending.last.complete(okSnapshot('https://b.test/', '<p>'));
      await other;
      expect(target.stillOn(url), isFalse);
    });
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
