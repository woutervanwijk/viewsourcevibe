import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/collectors/collector_world.dart';

void main() {
  test('apple platforms get an isolated world and the flag', () {
    final s = collectorUserScript(TargetPlatform.iOS);
    expect(s.contentWorld.name, 'vsv');
    expect(s.source, startsWith('window.__vsv_isolated = true;'));
    expect(collectorWorld(TargetPlatform.macOS)?.name, 'vsv');
  });

  test('android keeps the page world and the patch', () {
    final s = collectorUserScript(TargetPlatform.android);
    expect(collectorWorld(TargetPlatform.android), isNull);
    expect(s.contentWorld.name, ContentWorld.PAGE.name);
    expect(s.source, isNot(contains('__vsv_isolated = true')));
  });
}
