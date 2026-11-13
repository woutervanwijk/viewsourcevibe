import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:view_source_vibe/models/settings.dart';

void main() {
  test('low resource mode is off by default, persists, and resets', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.initialize();
    expect(settings.lowResourceMode, isFalse);

    settings.lowResourceMode = true;
    expect(settings.lowResourceMode, isTrue);

    // Survives a restart.
    final reloaded = AppSettings();
    await reloaded.initialize();
    expect(reloaded.lowResourceMode, isTrue);

    reloaded.resetToDefaults();
    expect(reloaded.lowResourceMode, isFalse);
  });
}
