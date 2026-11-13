// Loads real sites in the real app and writes each inspection package, for
// the validation harness in validation/ (see validation/README.md).
//
//   flutter test integration_test/site_validation_test.dart -d macos \
//     --dart-define=VSV_SITES=example=https://example.com,github=https://github.com \
//     --dart-define=VSV_OUT=/abs/path/validation/runs/<stamp>
//
// Writes <VSV_OUT>/<slug>/app.zip and <VSV_OUT>/<slug>/app-meta.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:view_source_vibe/main.dart' as app;
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/inspection_export_service.dart';

const _sites = String.fromEnvironment('VSV_SITES');
const _out = String.fromEnvironment('VSV_OUT');
const _timeout = Duration(seconds: 90);

/// Extra seconds to keep the page open after it settled (to test whether
/// late scripts change what the app reports).
const _linger = int.fromEnvironment('VSV_LINGER');

/// Session-restore keys of AppStateService; removed so the app does not
/// reopen the last page on start. Settings stay untouched.
const _restoreKeys = [
  'pending_url',
  'last_url',
  'last_file',
  'last_file_name',
  'last_file_path',
  'last_file_is_url',
  'input_text',
];

/// What is still unfinished, by name; empty when the page is ready.
List<String> _pending(HtmlService s) => [
      if (s.isLoading) 'loading',
      if (!s.store.current.browserSettled) 'browserSettled',
      if (!s.detectionsView.complete) 'detections',
      if (s.generalView is Pending) 'general',
      if (s.securityView is Pending) 'security',
      if (s.cookiesView is Pending) 'cookies',
      if (s.sovereigntyState is Pending) 'sovereignty',
    ];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('site validation run', (tester) async {
    if (_sites.isEmpty || _out.isEmpty) {
      fail('Pass --dart-define=VSV_SITES=slug=url,... and VSV_OUT=/abs/dir');
    }
    final sites = [
      for (final entry in _sites.split(','))
        if (entry.contains('='))
          (
            slug: entry.substring(0, entry.indexOf('=')),
            url: entry.substring(entry.indexOf('=') + 1),
          ),
    ];

    final prefs = await SharedPreferences.getInstance();
    for (final key in _restoreKeys) {
      await prefs.remove(key);
    }

    app.main();
    for (var i = 0; i < 100 && find.byType(app.MyApp).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 2));
    final html = tester.element(find.byType(app.MyApp)).read<HtmlService>();
    // Sovereignty only runs while a view watches it; act as that view.
    html.watchSovereignty(true);

    for (final site in sites) {
      final dir = Directory('$_out/${site.slug}')..createSync(recursive: true);
      final started = DateTime.now().toUtc();
      final clock = Stopwatch()..start();
      String? error;
      var pending = <String>[];

      try {
        // Cold, pre-consent measurement: no cookies or cache from earlier
        // sites or earlier runs.
        await CookieManager.instance().deleteAllCookies();
        await InAppWebViewController.clearAllCache();

        await html.loadUrl(site.url);
        // Give the load a moment to start before polling for "done".
        await tester.pump(const Duration(seconds: 2));
        while (clock.elapsed < _timeout) {
          pending = _pending(html);
          if (pending.isEmpty) break;
          await tester.pump(const Duration(milliseconds: 500));
        }
        pending = _pending(html);
        if (_linger > 0) {
          await tester.pump(Duration(seconds: _linger));
          // Collect once more (as when the page reports new resources) so
          // the late state is in the snapshot.
          html.onBrowserResourcesChanged();
          await tester.pump(const Duration(seconds: 8));
        }

        final bytes = InspectionExportService().buildPackageBytes(html);
        File('${dir.path}/app.zip').writeAsBytesSync(bytes);
      } catch (e) {
        error = '$e';
      }

      final meta = {
        'slug': site.slug,
        'url': site.url,
        'startedAt': started.toIso8601String(),
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'waitedMs': clock.elapsedMilliseconds,
        'timedOut': pending.isNotEmpty,
        'pendingAtExport': pending,
        if (error != null) 'error': error,
      };
      File('${dir.path}/app-meta.json')
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(meta));
      debugPrint('VSV ${site.slug}: ${clock.elapsedMilliseconds} ms'
          '${pending.isEmpty ? '' : ', still pending: $pending'}'
          '${error == null ? '' : ', error: $error'}');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
