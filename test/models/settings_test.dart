import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/settings.dart';

void main() {
  group('AppSettings browser behavior options', () {
    test('cache disabled and cookie cleaning are off by default', () {
      final s = AppSettings();
      expect(s.disableBrowserCache, isFalse);
      expect(s.cleanCookies, isFalse);
      expect(s.scrollToLoadLazy, isTrue);
    });

    test('setters toggle and notify', () {
      final s = AppSettings();
      var notified = 0;
      s.addListener(() => notified++);
      s.disableBrowserCache = true;
      s.cleanCookies = true;
      expect(s.disableBrowserCache, isTrue);
      expect(s.cleanCookies, isTrue);
      expect(notified, 2);
      // same value: no notify
      s.disableBrowserCache = true;
      expect(notified, 2);
      s.resetToDefaults();
      expect(s.disableBrowserCache, isFalse);
      expect(s.cleanCookies, isFalse);
    });
  });
}
