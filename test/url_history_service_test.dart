import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:view_source_vibe/services/url_history_service.dart';

void main() {
  test('normalizes like a browser URL parser', () {
    expect(UrlHistoryService.normalize('https://www.mozilla.org'),
        'https://www.mozilla.org/');
    expect(UrlHistoryService.normalize('HTTPS://WWW.Mozilla.org/en-US/#top'),
        'https://www.mozilla.org/en-US/');
    expect(UrlHistoryService.normalize('https://example.com:443/a'),
        'https://example.com/a');
    expect(UrlHistoryService.normalize('index.html'), 'index.html');
  });

  test('scheme, www and trailing slash do not make a different entry', () {
    final key = UrlHistoryService.dedupeKey('https://www.mozilla.org/');
    for (final url in [
      'https://www.mozilla.org',
      'https://mozilla.org',
      'http://mozilla.org/',
    ]) {
      expect(UrlHistoryService.dedupeKey(url), key, reason: url);
    }
    expect(
        UrlHistoryService.dedupeKey('https://mozilla.org/en-US/'), isNot(key));
    expect(UrlHistoryService.dedupeKey('https://mozilla.org/?q=1'), isNot(key));
  });

  test('adding replaces the equivalent entry and moves it to the top',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = await UrlHistoryService.create();
    await service.addUrl('https://www.mozilla.org');
    await service.addUrl('https://example.com');
    await service.addUrl('https://mozilla.org/');
    expect(service.history, ['https://mozilla.org/', 'https://example.com/']);
  });

  test('cleans up duplicates saved by older versions', () async {
    SharedPreferences.setMockInitialValues({
      'url_history': [
        'https://www.mozilla.org/',
        'https://www.mozilla.org',
        'https://mozilla.org',
        'page.html',
        'https://nos.nl',
      ],
    });
    final service = await UrlHistoryService.create();
    expect(service.history,
        ['https://www.mozilla.org/', 'page.html', 'https://nos.nl/']);
  });

  test('a redirect keeps only its destination', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await UrlHistoryService.create();
    await service.addUrl('https://example.com');
    await service.addUrl('https://mozilla.org');
    await service.replaceUrl(
        'https://mozilla.org', 'https://www.mozilla.org/en-US/');
    expect(service.history,
        ['https://www.mozilla.org/en-US/', 'https://example.com/']);
  });
}
