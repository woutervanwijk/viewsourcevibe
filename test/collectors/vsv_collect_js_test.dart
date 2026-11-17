import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/collectors/browser_payload.dart';

import '../support/collector_node.dart';

void main() {
  test('isolated: fetch and XHR are left alone', () async {
    final out = await runCollector(
        before: 'window.__vsv_isolated = true;',
        probe: 'window.fetch === __nativeFetch');
    if (out == null) return markTestSkipped('node not installed');
    expect(out['__probe'], isTrue);
  });

  test('page world: fetch is patched (unchanged behaviour)', () async {
    final out = await runCollector(probe: 'window.fetch === __nativeFetch');
    if (out == null) return markTestSkipped('node not installed');
    expect(out['__probe'], isFalse);
  });

  test('__vsv_frameIn records frame entries with their origin', () async {
    final out = await runCollector(
        after: "window.__vsv_frameIn({__vsv_frame: 1,"
            "fo: 'https://ads.test', to: 1, e: [{n: 'https://ads.test/a.js',"
            "it: 'script', st: 1, du: 1, tx: 10, enc: 9, dec: 20}], d: []});");
    if (out == null) return markTestSkipped('node not installed');
    expect(out['resources']['observer'].single,
        containsPair('fo', 'https://ads.test'));
  });

  test('a dropped resource does not break the resources section', () async {
    final out = await runCollector(
        after: "window.__vsv_dropped.push("
            "{n: 'https://ads.example/x.gif', it: 'img', fo: ''});"
            "window.__vsv_obsDropped = 1;");
    if (out == null) return markTestSkipped('node not installed');
    expect(out['resources']['ok'], isTrue);
    expect(out['resources']['droppedNames'], [
      {'n': 'https://ads.example/x.gif', 'it': 'img', 'fo': ''}
    ]);
    final snap = parseBrowserPayload(jsonEncode(out), BrowserPlatform.macos,
        pageUrl: Uri.parse('https://example.com/'));
    expect(snap.resourcesTruncated, isTrue);
    expect(
        (snap.resources as Present<List<ResourceEntry>>).value.single.source,
        ResourceSource.dropped);
  });

  test('storage values never leave the page', () async {
    final out = await runCollector(
        before: "window.localStorage = {length: 2,"
            "key: function(i) { return ['a', 'tok'][i]; },"
            "getItem: function(k) { return k === 'a' ? '\u00e9' : 'secret-token'; }};");
    if (out == null) return markTestSkipped('node not installed');
    final local = out['storage']['local'];
    expect(jsonEncode(local), isNot(contains('secret-token')));
    expect(local['count'], 2);
    expect(local['bytes'], 3 + 15); // 'a'+'é' = 1+2, 'tok'+'secret-token' = 3+12
    expect(local['items'][0], {'k': 'tok', 'b': 15});
  });

  test('iframe attributes are collected, capped at 200', () async {
    final out = await runCollector(
        before: "var fr = []; for (var i = 0; i < 250; i++)"
            " fr.push({src: 'https://f.test/' + i, getAttribute: function(n) {"
            " return n === 'src' ? this.src"
            " : n === 'allow' ? 'camera' : null; }});"
            "document.getElementsByTagName = function(t) {"
            " return t === 'iframe' ? fr : []; };");
    if (out == null) return markTestSkipped('node not installed');
    expect(out['frames']['total'], 250);
    expect(out['frames']['items'], hasLength(200));
    expect(out['frames']['items'][0],
        {'src': 'https://f.test/0', 'allow': 'camera', 'sandbox': null});
  });

  test('an empty sandbox attribute stays empty, a missing one is null',
      () async {
    final out = await runCollector(
        before: "var fr = [{getAttribute: function(n) {"
            " return n === 'sandbox' ? '' : null; }}];"
            "document.getElementsByTagName = function(t) {"
            " return t === 'iframe' ? fr : []; };");
    if (out == null) return markTestSkipped('node not installed');
    expect(out['frames']['items'].single,
        {'src': '', 'allow': '', 'sandbox': ''});
  });

  test('site storage is pending until the promises settle', () async {
    // A promise that never settles; the other three APIs are absent.
    final out = await runCollector(
        before: "var navigator = {storage: {estimate:"
            " function() { return {then: function() {"
            " return {catch: function() {}}; }}; }}};");
    if (out == null) return markTestSkipped('node not installed');
    expect(out['siteStorage'], {'ok': true, 'pending': true});
  });

  test('capabilities say what the page can ask for', () async {
    final out = await runCollector(
        before: "var navigator = {mediaDevices: {getUserMedia: function() {}},"
            " geolocation: {}};");
    if (out == null) return markTestSkipped('node not installed');
    expect(out['capabilities'],
        {'ok': true, 'mediaDevices': true, 'geolocation': true});
  });

  test('capabilities are false when the APIs are absent', () async {
    final out = await runCollector(
        before: "var navigator = {mediaDevices: undefined};");
    if (out == null) return markTestSkipped('node not installed');
    expect(out['capabilities'],
        {'ok': true, 'mediaDevices': false, 'geolocation': false});
  });

  test('a missing API is an error for that field only', () async {
    final out = await runCollector(
        before: "window.__vsv_site = {done: true, usage: 10, quota: 100,"
            " idb: {ok: false, error: 'indexedDB.databases is not supported'},"
            " caches: {ok: true, names: ['v1']}, sw: {ok: true, items: []}};");
    if (out == null) return markTestSkipped('node not installed');
    final s = out['siteStorage'];
    expect(s['idb']['ok'], isFalse);
    expect(s['caches']['names'], ['v1']);
    expect(s['usage'], 10);
  });

  test('site storage lookups that are absent are recorded per field',
      () async {
    // Node has none of navigator.storage / indexedDB / caches here.
    final out = await runCollector(
        before: "var navigator = {};",
        probe: "window.__vsv_site");
    if (out == null) return markTestSkipped('node not installed');
    final s = out['siteStorage'];
    expect(s['idb'],
        {'ok': false, 'error': 'indexedDB.databases is not supported'});
    expect(s['sw']['ok'], isFalse);
    expect(s['usage'], isNull);
  });

  test('a storage API that never answers is reported after 4 s', () async {
    // caches.keys() hangs; the clock jumps 5 s once it has been called.
    final out = await runCollector(
        before: "var __real = Date.now, __skew = 0;"
            " Date.now = function() { return __real() + __skew; };"
            " var navigator = {};"
            " var caches = {keys: function() { return {then: function() {"
            " __skew = 5000; return {catch: function() {}}; }}; }};");
    if (out == null) return markTestSkipped('node not installed');
    final s = out['siteStorage'];
    expect(s['pending'], isNull);
    expect(s['caches'], {'ok': false, 'error': 'no answer within 4 s'});
    expect(s['idb']['ok'], isFalse);
    expect(s['usage'], isNull);
  });

  test('a synchronous throw from then() settles that field only', () async {
    final out = await runCollector(
        before: "var navigator = {};"
            " var caches = {keys: function() { return {then: function() {"
            " throw new Error('boom'); }}; }};",
        probe: "window.__vsv_site.caches");
    if (out == null) return markTestSkipped('node not installed');
    expect(out['__probe']['ok'], isFalse);
    expect(out['__probe']['error'], contains('boom'));
  });
}
