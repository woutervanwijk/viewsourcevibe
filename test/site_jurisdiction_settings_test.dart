import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:view_source_vibe/models/settings.dart';

void main() {
  test('keeps the 255 most recently set site jurisdictions', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.initialize();

    for (var i = 0; i < 300; i++) {
      settings.setSiteJurisdiction('site$i.com', 'US');
    }
    settings.setSiteJurisdiction('site100.com', 'GB'); // refresh an old one

    expect(settings.siteJurisdiction('site0.com'), isNull);
    expect(settings.siteJurisdiction('site44.com'), isNull);
    expect(settings.siteJurisdiction('site45.com'), 'US'); // 300 - 255
    expect(settings.siteJurisdiction('site299.com'), 'US');
    expect(settings.siteJurisdiction('site100.com'), 'GB');

    settings.setSiteJurisdiction('site299.com', null);
    expect(settings.siteJurisdiction('site299.com'), isNull);

    // Survives a restart.
    final reloaded = AppSettings();
    await reloaded.initialize();
    expect(reloaded.siteJurisdiction('site100.com'), 'GB');
  });
}
