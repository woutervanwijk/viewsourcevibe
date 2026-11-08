import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:view_source_vibe/services/app_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('create() removes the old stored probe result (cookie values)',
      () async {
    SharedPreferences.setMockInitialValues({
      'probe_result': '{"cookies":["sid=secret"]}',
      'is_probe_visible': true,
      'last_url': 'https://a.test/',
    });
    final service = await AppStateService.create();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.containsKey('probe_result'), isFalse);
    expect(prefs.containsKey('is_probe_visible'), isFalse);
    expect(service.loadAppState()!.filePath, isNull);
    expect(prefs.getString('last_url'), 'https://a.test/');
  });
}
