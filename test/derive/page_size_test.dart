import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/page_size.dart';

void main() {
  group('sizeReasonWord', () {
    test('a dropped (buffer-full) resource says so', () {
      expect(
        sizeReasonWord(const Unavailable<int>(
            UnavailableReason.notReportedByPlatform,
            'not collected: the collector buffer was full')),
        'not collected (the collector buffer was full)',
      );
    });

    test('a shown memory-cache image says so', () {
      expect(
        sizeReasonWord(const Unavailable<int>(
            UnavailableReason.notReportedByPlatform,
            'shown on the page, but the browser reported no timing for it '
            '(likely served from its memory cache)')),
        'shown, but served from the memory cache',
      );
    });

    test('cross-origin zeros are called cross-origin', () {
      expect(
        sizeReasonWord(const Unavailable<int>(
            UnavailableReason.blockedByPlatform,
            'cross-origin resource without Timing-Allow-Origin')),
        'cross-origin',
      );
    });

    test('a present value has no reason', () {
      expect(sizeReasonWord(Present(5, source: DataSource.browser)),
          'not reported');
    });
  });
}
