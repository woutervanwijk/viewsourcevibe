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
}
