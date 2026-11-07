import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/file_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/models/inspection/server_snapshot.dart';
import 'package:view_source_vibe/services/inspection_store.dart';
import 'package:view_source_vibe/utils/text_decoding.dart';

DecodedText _text(String s) => DecodedText(
    text: s,
    charset: 'utf-8',
    charsetSource: CharsetSource.fallback,
    byteLength: s.length);

ServerSnapshot _server(String url, {String body = '<p>s</p>'}) =>
    ServerSnapshot(
      requestedUrl: Uri.parse(url),
      userAgent: 'ua',
      hops: const [],
      finalUrl: Present(Uri.parse(url), source: DataSource.server),
      body: Present(
          ServerBody(
              decoded: _text(body),
              transferLength: body.length,
              truncated: false,
              contentLength:
                  const Unavailable(UnavailableReason.notReportedByServer)),
          source: DataSource.server),
      timingMs: const Present(5, source: DataSource.server),
      certificate: const Unavailable(UnavailableReason.notApplicable),
    );

ResourceEntry _res(String url, {int? transfer}) => ResourceEntry(
      url: url,
      type: 'img',
      source: ResourceSource.observer,
      startTime: const Present(1.0, source: DataSource.browser),
      duration: const Present(2.0, source: DataSource.browser),
      transfer: transfer == null
          ? const Unavailable(UnavailableReason.notReportedByPlatform)
          : Present(transfer, source: DataSource.browser),
      decoded: const Unavailable(UnavailableReason.notReportedByPlatform),
    );

BrowserSnapshot _browser(String url,
        {String? dom, List<ResourceEntry>? resources}) =>
    BrowserSnapshot(
      url: Uri.parse(url),
      platform: BrowserPlatform.macos,
      contentType: const Unavailable(UnavailableReason.notExposedToPage),
      renderedDom: dom == null
          ? const Unavailable(UnavailableReason.notExposedToPage)
          : Present(RenderedDom(text: dom), source: DataSource.browser),
      resources: resources == null
          ? const Unavailable(UnavailableReason.notExposedToPage)
          : Present(resources, source: DataSource.browser),
      cookies: const Unavailable(UnavailableReason.notExposedToPage),
      storage: const Unavailable(UnavailableReason.notExposedToPage),
      navigation: const Unavailable(UnavailableReason.notExposedToPage),
      snapshotTimeMs: const Present(10.0, source: DataSource.browser),
    );

FileSnapshot _file() => FileSnapshot(
      name: 'a.html',
      path: '/tmp/a.html',
      origin: FileOrigin.picker,
      bytes: const [60, 112, 62],
      text: _text('<p>'),
      lastModified: const Unavailable(UnavailableReason.notApplicable),
    );

void main() {
  late InspectionStore store;
  late int notifies;
  setUp(() {
    store = InspectionStore();
    notifies = 0;
    store.addListener(() => notifies++);
  });

  test('initial state is empty and unavailable', () {
    final c = store.current;
    expect(c.generation, 0);
    expect(c.target, isA<NoTarget>());
    expect(c.server, isA<Unavailable<ServerSnapshot>>());
    expect(c.browser, isA<Unavailable<BrowserSnapshot>>());
    expect(c.file, isA<Unavailable<FileSnapshot>>());
    expect(c.primaryDocument, isNull);
  });

  test('beginUrl: new generation, server/browser pending, file n/a', () {
    final g1 = store.beginUrl(Uri.parse('https://a.test/'));
    final g2 = store.beginUrl(Uri.parse('https://b.test/'));
    expect(g2, greaterThan(g1));
    expect(store.current.generation, g2);
    expect(store.current.server, isA<Pending<ServerSnapshot>>());
    expect(store.current.browser, isA<Pending<BrowserSnapshot>>());
    expect(store.current.file, isA<Unavailable<FileSnapshot>>());
    expect(notifies, 2);
  });

  test('stale server result after a new begin is ignored, B stays pending',
      () async {
    final a = Completer<Observed<ServerSnapshot>>();
    final genA = store.beginUrl(Uri.parse('https://a.test/'));
    final fut = a.future.then((r) => store.applyServer(genA, r));
    store.beginUrl(Uri.parse('https://b.test/'));
    notifies = 0;
    a.complete(Present(_server('https://a.test/'), source: DataSource.server));
    await fut;
    expect(store.current.server, isA<Pending<ServerSnapshot>>());
    expect(notifies, 0);
  });

  test('stale browser payload after a new begin is ignored', () {
    final genA = store.beginUrl(Uri.parse('https://a.test/'));
    store.beginUrl(Uri.parse('https://b.test/'));
    notifies = 0;
    store.applyBrowser(genA, _browser('https://a.test/', dom: '<p>a</p>'));
    expect(store.current.browser, isA<Pending<BrowserSnapshot>>());
    expect(notifies, 0);
  });

  test('stale robots and failure are ignored', () {
    final genA = store.beginUrl(Uri.parse('https://a.test/'));
    store.beginUrl(Uri.parse('https://b.test/'));
    notifies = 0;
    store.applyRobots(genA, const Pending());
    store.applyBrowserFailure(genA, const Failed('x'));
    expect(notifies, 0);
    expect(store.current.browser, isA<Pending<BrowserSnapshot>>());
  });

  test('URL fully loaded then beginFile clears server/browser', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    store.applyBrowser(
        g,
        _browser('https://a.test/',
            dom: '<p/>', resources: [_res('https://a.test/x.png')]));
    store.beginFile(_file());
    final c = store.current;
    expect(c.target, isA<FileTarget>());
    expect(c.server, isA<Unavailable<ServerSnapshot>>());
    expect((c.server as Unavailable).reason, UnavailableReason.notApplicable);
    expect(c.browser, isA<Unavailable<BrowserSnapshot>>());
    expect((c.browser as Unavailable).reason, UnavailableReason.notApplicable);
    expect(c.file, isA<Present<FileSnapshot>>());
    expect(c.primaryDocument, DataSource.file);
  });

  test('local file: no fake probe; applyBrowser/applyServer ignored', () {
    final g = store.beginFile(_file());
    notifies = 0;
    store.applyBrowser(g, _browser('file:///tmp/a.html', dom: '<p/>'));
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    expect(store.current.server, isA<Unavailable<ServerSnapshot>>());
    expect(store.current.browser, isA<Unavailable<BrowserSnapshot>>());
    expect(notifies, 0);
  });

  test('one applyBrowser = exactly one notify', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    notifies = 0;
    store.applyBrowser(g, _browser('https://a.test/', dom: '<p/>'));
    expect(notifies, 1);
    expect(store.current.browser, isA<Present<BrowserSnapshot>>());
  });

  test('server Failed stays visible', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyServer(g, const Failed('timeout'));
    final s = store.current.server;
    expect(s, isA<Failed<ServerSnapshot>>());
    expect((s as Failed).error, 'timeout');
  });

  test('second applyBrowser merges resources, takes fresher DOM', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyBrowser(
        g,
        _browser('https://a.test/',
            dom: '<p>1</p>',
            resources: [_res('https://a.test/1.png', transfer: 10)]));
    store.applyBrowser(
        g,
        _browser('https://a.test/',
            dom: '<p>2</p>', resources: [_res('https://a.test/2.png')]));
    final b = (store.current.browser as Present<BrowserSnapshot>).value;
    expect(((b.renderedDom as Present<RenderedDom>).value).text, '<p>2</p>');
    final urls =
        (b.resources as Present<List<ResourceEntry>>).value.map((e) => e.url);
    expect(urls, containsAll(['https://a.test/1.png', 'https://a.test/2.png']));
  });

  test('later non-Present sections never overwrite Present ones', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyBrowser(
        g,
        _browser('https://a.test/',
            dom: '<p>1</p>', resources: [_res('https://a.test/1.png')]));
    store.applyBrowser(g, _browser('https://a.test/'));
    store.applyBrowserFailure(g, const Failed('late'));
    final b = store.current.browser;
    expect(b, isA<Present<BrowserSnapshot>>());
    final v = (b as Present<BrowserSnapshot>).value;
    expect(v.renderedDom, isA<Present<RenderedDom>>());
    expect(v.resources, isA<Present<List<ResourceEntry>>>());
  });

  test('applyBrowserFailure stores Failed when nothing Present', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    store.applyBrowserFailure(g, const Failed('boom'));
    expect(store.current.browser, isA<Failed<BrowserSnapshot>>());
  });

  test('applyRobots attaches to server snapshot; ignored without server', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    notifies = 0;
    store.applyRobots(g, const Failed('x'));
    expect(notifies, 0);
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    store.applyRobots(g, const Failed('no robots'));
    final s = (store.current.server as Present<ServerSnapshot>).value;
    expect(s.robots, isA<Failed<RobotsInfo>>());
  });

  test('primaryDocument rule and preference', () {
    final g = store.beginUrl(Uri.parse('https://a.test/'));
    expect(store.current.primaryDocument, isNull);
    store.applyServer(
        g, Present(_server('https://a.test/'), source: DataSource.server));
    expect(store.current.primaryDocument, DataSource.server);
    store.applyBrowser(g, _browser('https://a.test/', dom: '<p/>'));
    expect(store.current.primaryDocument, DataSource.browser);
    store.setPrimaryDocument(DataSource.server);
    expect(store.current.primaryDocument, DataSource.server);
    store.setPrimaryDocument(DataSource.file); // not present: falls back
    expect(store.current.primaryDocument, DataSource.browser);
    notifies = 0;
    store.setPrimaryDocument(DataSource.file); // no-op
    expect(notifies, 0);
    store.setPrimaryDocument(null);
    expect(notifies, 1);
  });
}
