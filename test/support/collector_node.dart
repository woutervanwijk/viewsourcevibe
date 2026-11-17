import 'dart:convert';
import 'dart:io';

import 'package:view_source_vibe/services/collectors/vsv_collect_js.dart';

const _stubs = r'''
var window = { addEventListener: function() {}, flutter_inappwebview: null,
  localStorage: { length: 0 }, sessionStorage: { length: 0 } };
window.top = window;
var __nativeFetch = function() { return { then: function() {} }; };
window.fetch = __nativeFetch;
var performance = { now: function() { return 1; }, timeOrigin: 1,
  getEntriesByType: function() { return []; }, setResourceTimingBufferSize: function() {} };
var document = { addEventListener: function() {}, contentType: 'text/html', firstChild: null,
  documentElement: { outerHTML: '<html></html>' }, body: null,
  getElementsByTagName: function() { return []; }, images: [], cookie: '' };
var location = { href: 'https://example.com/', origin: 'https://example.com' };
function PerformanceObserver() {} PerformanceObserver.prototype.observe = function() {};
function XMLHttpRequest() {} XMLHttpRequest.prototype.open = function() {};
XMLHttpRequest.prototype.send = function() {};
var setTimeout = function() { return 0; };
''';

/// Runs [source] under Node and returns its stdout. Returns null when Node is
/// not installed.
Future<String?> runJs(String source) async {
  try {
    await Process.run('node', ['--version']);
  } on ProcessException {
    return null;
  }
  final dir = Directory.systemTemp.createTempSync('vsv_collector');
  try {
    final file = File('${dir.path}/run.js')..writeAsStringSync(source);
    final r = await Process.run('node', [file.path]);
    if (r.exitCode != 0) {
      throw StateError('collector run failed: ${r.stderr}');
    }
    return r.stdout as String;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Runs the collector JS under Node with browser stubs and returns the decoded
/// result of `window.__vsv_collect(opts)`, plus the value of [probe] under
/// `__probe`. Returns null when Node is not installed.
Future<Map<String, dynamic>?> runCollector({
  String before = '',
  String after = '',
  String opts = '{dom: false}',
  String probe = 'null',
}) async {
  final out = await runJs([
    _stubs,
    before,
    vsvResourceBootstrapJs,
    vsvCollectJs,
    after,
    'var o = JSON.parse(window.__vsv_collect($opts)); '
        'o.__probe = ($probe); console.log(JSON.stringify(o));',
  ].join('\n'));
  return out == null ? null : jsonDecode(out) as Map<String, dynamic>;
}
