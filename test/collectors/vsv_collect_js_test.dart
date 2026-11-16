import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/collectors/browser_payload.dart';

import '../support/collector_node.dart';

void main() {
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
}
