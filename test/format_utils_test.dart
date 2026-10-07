import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/utils/format_utils.dart';

void main() {
  // The separator follows the device language ('.' for nl/de/..., ',' for en).
  final sep = FormatUtils.thousandsSeparator;

  group('FormatUtils Tests', () {
    test('Should format large numbers with thousands separators', () {
      expect(FormatUtils.formatNumberWithDots('1000'), '1${sep}000');
      expect(
          FormatUtils.formatNumberWithDots('1000000'), '1${sep}000${sep}000');
      expect(FormatUtils.formatNumberWithDots('123'), '123');
      expect(FormatUtils.formatNumberWithDots('12345'), '12${sep}345');
    });

    test('Should convert seconds to human duration', () {
      expect(FormatUtils.getHumanDuration(30), '30 s');
      expect(FormatUtils.getHumanDuration(60), '1 min');
      expect(FormatUtils.getHumanDuration(90), '1.5 min');
      expect(FormatUtils.getHumanDuration(3600), '1 hour');
      expect(FormatUtils.getHumanDuration(7200), '2 hours');
      expect(FormatUtils.getHumanDuration(5400), '1.5 hours');
      expect(FormatUtils.getHumanDuration(86400), '1 day');
      expect(FormatUtils.getHumanDuration(172800), '2 days');
      expect(FormatUtils.getHumanDuration(2592000), '1 month');
      expect(FormatUtils.getHumanDuration(31536000), '1 year');
    });

    test('Should format complex strings correctly', () {
      // Test max-age
      expect(FormatUtils.formatHumanData('max-age=3600'),
          'max-age=3${sep}600 (1 hour)');

      // Test ma=
      expect(FormatUtils.formatHumanData('ma=86400'), 'ma=86${sep}400 (1 day)');

      // Test standalone numbers
      expect(FormatUtils.formatHumanData('The size is 1234567 bytes'),
          'The size is 1${sep}234${sep}567 bytes');

      // Test IP addresses (should NOT be formatted)
      expect(FormatUtils.formatHumanData('192.168.1.1'), '192.168.1.1');

      // Test mixed content
      expect(
          FormatUtils.formatHumanData(
              'Cache-Control: public, max-age=31536000, immutable'),
          'Cache-Control: public, max-age=31${sep}536${sep}000 (1 year), immutable');
    });

    test('Should handle case sensitivity for max-age and ma', () {
      expect(FormatUtils.formatHumanData('MAX-AGE=60'), 'MAX-AGE=60 (1 min)');
      expect(FormatUtils.formatHumanData('MA=3600'), 'MA=3${sep}600 (1 hour)');
    });
  });
}
