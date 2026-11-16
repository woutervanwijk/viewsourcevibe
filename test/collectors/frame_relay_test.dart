import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/collectors/frame_relay.dart';

void main() {
  test('a frame report becomes a call into the top frame', () {
    final js = frameRelayScript([
      {
        '__vsv_frame': 1,
        'fo': 'https://ads.test',
        'to': 5.0,
        'e': [
          {'n': 'https://ads.test/a.js', 'it': 'script', 'tx': 10}
        ],
        'd': []
      }
    ]);
    expect(js, startsWith('window.__vsv_frameIn({'));
    expect(js, contains('"https://ads.test/a.js"'));
  });

  test('oversized frame report is dropped', () {
    expect(
        frameRelayScript([
          {'__vsv_frame': 1, 'e': [], 'x': 'a' * (256 * 1024)}
        ]),
        isNull);
  });

  test('anything else is dropped', () {
    expect(frameRelayScript([]), isNull);
    expect(frameRelayScript(['</script>']), isNull);
    expect(
        frameRelayScript([
          {'e': []}
        ]),
        isNull);
  });
}
