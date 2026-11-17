import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/collectors/vsv_techniques_js.dart';

import '../support/collector_node.dart';

const _fakeBrowser = r'''
var window = {}; window.top = window;
var location = { href: 'https://example.com/' };
var navigator = { userActivation: { isActive: false },
  mediaDevices: { getUserMedia: function() { return 'gum'; },
                  enumerateDevices: function() { return 'devs'; } },
  geolocation: { getCurrentPosition: function() { return 'pos'; } } };
function HTMLCanvasElement() { this.width = 300; this.height = 150; }
HTMLCanvasElement.prototype.getContext = function() {
  return this._x || (this._x = new CanvasRenderingContext2D());
};
HTMLCanvasElement.prototype.toDataURL = function() { return 'data:,x'; };
HTMLCanvasElement.prototype.toBlob = function() { return 'blob'; };
function CanvasRenderingContext2D() {}
CanvasRenderingContext2D.prototype = {
  fillText: function() {}, strokeText: function() {},
  measureText: function() { return { width: 1 }; },
  getImageData: function(x, y, w, h) { return { width: w, height: h }; }
};
(function() {
  var fill = '#000', font = '10px a';
  Object.defineProperty(CanvasRenderingContext2D.prototype, 'fillStyle', {
    configurable: true, get: function() { return fill; }, set: function(v) { fill = v; } });
  Object.defineProperty(CanvasRenderingContext2D.prototype, 'font', {
    configurable: true, get: function() { return font; }, set: function(v) { font = v; } });
})();
function WebGLRenderingContext() {}
WebGLRenderingContext.prototype.getExtension = function(n) { return { n: n }; };
WebGLRenderingContext.prototype.getParameter = function(p) { return p; };
function OfflineAudioContext() {}
OfflineAudioContext.prototype.createOscillator = function() { return {}; };
OfflineAudioContext.prototype.startRendering = function() { return 'r'; };
function RTCPeerConnection() {}
RTCPeerConnection.prototype.createDataChannel = function() { return {}; };
RTCPeerConnection.prototype.createOffer = function() { return 'o'; };
function Notification() {}
Notification.requestPermission = function() { return 'granted'; };
[HTMLCanvasElement, CanvasRenderingContext2D, WebGLRenderingContext,
 OfflineAudioContext, RTCPeerConnection, Notification].forEach(function(c) {
  window[c.name] = c; });
''';

Future<Map<String, dynamic>?> report(String page, {String before = ''}) async {
  final out = await runJs([
    _fakeBrowser,
    before,
    vsvTechniquesJs,
    page,
    'console.log(window.__vsv_tech_report());',
  ].join('\n'));
  return out == null ? null : jsonDecode(out) as Map<String, dynamic>;
}

void main() {
  test('text drawn in two colours and read back is recorded', () async {
    final r = await report('''
      var c = new HTMLCanvasElement(); c.width = 300; c.height = 150;
      var x = c.getContext('2d');
      x.fillStyle = '#f60'; x.fillText('Cwm fjordbank glyphs vext quiz', 2, 15);
      x.fillStyle = 'rgba(102,204,0,0.7)'; x.fillText('Cwm fjordbank glyphs vext quiz', 4, 17);
      c.toDataURL();''');
    if (r == null) return markTestSkipped('node not installed');
    expect(r['v'], 1);
    expect((r['canvas'] as List).single, containsPair('reads', 1));
    expect((r['canvas'] as List).single['colors'], 2);
    expect((r['canvas'] as List).single['chars'], greaterThanOrEqualTo(10));
  });

  test('the original result is returned unchanged', () async {
    final out = await runJs([
      _fakeBrowser,
      vsvTechniquesJs,
      'var c = new HTMLCanvasElement();'
          'console.log(c.toDataURL() + "|" + (c.getContext("2d") === c.getContext("2d")));',
    ].join('\n'));
    if (out == null) return markTestSkipped('node not installed');
    expect(out.trim(), 'data:,x|true');
  });

  test('webgl debug info and audio rendering are recorded', () async {
    final r = await report('''
      var g = new WebGLRenderingContext();
      g.getExtension('WEBGL_debug_renderer_info'); g.getParameter(37445);
      var a = new OfflineAudioContext(); a.createOscillator(); a.startRendering();''');
    if (r == null) return markTestSkipped('node not installed');
    expect(r['webgl'], containsPair('debugInfo', true));
    expect(r['audio'],
        allOf(containsPair('offline', 1), containsPair('oscillators', 1),
            containsPair('rendered', 1)));
  });

  test('a notification prompt without a click is recorded', () async {
    final r = await report('Notification.requestPermission();');
    if (r == null) return markTestSkipped('node not installed');
    final p = (r['prompts'] as List).single as Map;
    expect(p['api'], 'notifications');
    expect(p['userActive'], false);
  });

  test('a frozen prototype does not break the page', () async {
    final out = await runJs([
      _fakeBrowser,
      'Object.freeze(HTMLCanvasElement.prototype);',
      vsvTechniquesJs,
      'var c = new HTMLCanvasElement();'
          'var res = c.toDataURL();'
          'var g = new WebGLRenderingContext(); g.getParameter(37445);'
          'var r = JSON.parse(window.__vsv_tech_report());'
          'console.log(res + "|" + r.canvas.length + "|" + r.webgl.debugInfo);',
    ].join('\n'));
    if (out == null) return markTestSkipped('node not installed');
    expect(out.trim(), 'data:,x|0|true');
  });

  test('many text-drawing canvases that are never read do not hide a later one',
      () async {
    final r = await report('''
      for (var i = 0; i < 25; i++) {
        var d = new HTMLCanvasElement(); var y = d.getContext('2d');
        y.fillStyle = '#123'; y.fillText('chart label ' + i, 1, 1);
      }
      var c = new HTMLCanvasElement(); var x = c.getContext('2d');
      x.fillStyle = '#f60'; x.fillText('Cwm fjordbank glyphs', 2, 15);
      c.toDataURL();''');
    if (r == null) return markTestSkipped('node not installed');
    expect((r['canvas'] as List).single['chars'], greaterThanOrEqualTo(10));
  });

  test('nothing called gives an empty report', () async {
    final r = await report('');
    if (r == null) return markTestSkipped('node not installed');
    expect(r['canvas'], isEmpty);
    expect(r['fonts']['measureCalls'], 0);
    expect(r['prompts'], isEmpty);
  });
}
