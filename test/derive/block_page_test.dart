import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/block_page.dart';

import '../fixtures/inspection/browser_blocked.dart';
import '../fixtures/inspection/full_page.dart';

const _unknown = Unavailable<int>(UnavailableReason.notReportedByPlatform);
Present<int> _status(int s) => Present(s, source: DataSource.browser);

BlockPage? _dom(String dom) => classifyBlockPage(status: _unknown, dom: dom);

void main() {
  test('the real bol.com block page (403) is a block page', () {
    final b = classifyBlockPage(status: _status(403), dom: bolBlockPageDom)!;
    expect(b.status, 403);
    expect(b.byMarker, isTrue);
    expect(b.label, 'block page (HTTP 403)');
    expect(b.detail, startsWith('the browser got a block page (HTTP 403)'));
  });

  test('the bol.com DOM is recognised without a status (WebKit)', () {
    expect(_dom(bolBlockPageDom)?.label, 'block page');
  });

  test('an error status alone is an error page', () {
    final b = classifyBlockPage(status: _status(404), dom: '<html></html>')!;
    expect(b.label, 'error page (HTTP 404)');
    expect(b.aLabel, 'an error page (HTTP 404)');
  });

  test('a normal page with a 2xx or unknown status is not one', () {
    expect(
        classifyBlockPage(status: _status(200), dom: fullPageDomHtml), isNull);
    expect(_dom(fullPageDomHtml), isNull);
    expect(classifyBlockPage(status: _unknown), isNull);
  });

  test('vendor markers', () {
    expect(_dom('<title>Just a moment...</title>')?.label,
        'challenge page (Cloudflare)');
    expect(_dom('<script>window._cf_chl_opt={cvId:"3"}</script>')?.vendor,
        'Cloudflare');
    expect(_dom('<h1>Sorry, you have been blocked</h1>')?.label,
        'block page (Cloudflare)');
    expect(
        _dom('<title>Access Denied</title><p>You don\'t have permission to '
                'access "http://x/" on this server.<p>Reference #18.1 '
                'https://errors.edgesuite.net/18.1')
            ?.vendor,
        'Akamai');
    expect(
        _dom('<script>var dd={"host":"geo.captcha-delivery.com"}</script>')
            ?.vendor,
        'DataDome');
    expect(_dom('<div id="px-captcha"></div>')?.label,
        'challenge page (HUMAN (PerimeterX))');
    expect(_dom('Request unsuccessful. Incapsula incident ID: 1-2')?.vendor,
        'Imperva');
  });

  test('scripts that also run on normal pages are not markers', () {
    expect(_dom('<script src="/.well-known/sbsd/abc"></script>'), isNull);
    expect(
        _dom('<script src="/cdn-cgi/challenge-platform/scripts/jsd/main.js">'
            '</script>'),
        isNull);
    expect(
        _dom('<script src="https://js.datadome.co/tags.js"></script>'), isNull);
  });

  test('markers are only trusted on a small document', () {
    final article = '<p>${'x' * blockPageMaxDomChars}</p>'
        '<p>Your access has been blocked, the article says.</p>';
    expect(_dom(article), isNull);
    expect(classifyBlockPage(status: _status(403), dom: article)?.label,
        'error page (HTTP 403)');
  });

  test('browserBlockPage reads the browser snapshot', () {
    expect(browserBlockPage(browserBlocked())?.label, 'block page (HTTP 403)');
    expect(browserBlockPage(browserBlocked(browserStatus: null))?.label,
        'block page');
    expect(browserBlockPage(fullPage()), isNull);
  });
}
