import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:view_source_vibe/models/html_file.dart';
import 'package:view_source_vibe/services/app_state_service.dart';
import 'package:view_source_vibe/services/html_service.dart';

/// B34: saved state is the URL and UI state only. No cookie values, no
/// bodies, no probe maps; after a restore the page is fetched again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved state holds no cookie value, body or probe map', () async {
    SharedPreferences.setMockInitialValues({});
    final service = HtmlService();
    addTearDown(service.dispose);
    final file = HtmlFile(
      name: 'a.test',
      path: 'https://a.test/',
      content: '<html>BODY-SECRET</html>',
      lastModified: DateTime(2024),
      size: 24,
      isUrl: true,
      probeResult: {
        'cookies': [
          {'name': 'sid', 'value': 'COOKIE-SECRET'}
        ],
        'analyzedCookies': [
          {'name': 'sid', 'value': 'COOKIE-SECRET'}
        ],
        'headers': {'set-cookie': 'sid=COOKIE-SECRET'},
      },
    );
    await service.loadFile(file);

    final state = await AppStateService.create();
    await service.saveCurrentState(state);

    final prefs = await SharedPreferences.getInstance();
    final dump = <String, Object?>{
      for (final k in prefs.getKeys()) k: prefs.get(k)
    };
    final text = jsonEncode(dump);

    expect(dump['last_url'], 'https://a.test/');
    expect(text, isNot(contains('COOKIE-SECRET')));
    expect(text, isNot(contains('BODY-SECRET')));
    expect(text, isNot(contains('analyzedCookies')));
    expect(text, isNot(contains('"value"')));
    const allowed = {
      'last_url',
      'last_file_name',
      'last_file_path',
      'last_file_is_url',
      'last_content_type',
      'last_scroll_position',
      'last_horizontal_scroll_position',
      'pending_url',
      'input_text',
      'navigation_stack',
    };
    expect(dump.keys.toSet().difference(allowed), isEmpty);
  });
}
