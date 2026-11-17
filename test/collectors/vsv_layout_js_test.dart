import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/collectors/vsv_layout_js.dart';

import '../support/collector_node.dart';

const _prelude = r'''
var __scrollX = 0, __scrollY = 0, __docW = 412, __docH = 5210;
function mk(tag, o) {
  o = o || {};
  var kids = [];
  for (var i = 0; i < (o.kids || 0); i++) kids.push({});
  return {
    tagName: tag.toUpperCase(), id: o.id || '', className: o.cls || '',
    src: o.src || '', currentSrc: o.currentSrc || '', textContent: o.text || '',
    pos: o.pos || 'static', vis: o.vis || 'visible',
    getAttribute: function(n) { return n === 'role' ? (o.role || null) : null; },
    getBoundingClientRect: function() {
      var r = o.rect || [0, 0, 100, 100];
      return { left: r[0], top: r[1], width: r[2], height: r[3],
               right: r[0] + r[2], bottom: r[1] + r[3] };
    },
    getElementsByTagName: function() { return kids; },
    parentNode: null
  };
}
var body = mk('body');
var __els = [];
function add(e) { e.parentNode = body; __els.push(e); return e; }
var window = { scrollX: 0, scrollY: 0, pageXOffset: 0, pageYOffset: 0,
  innerWidth: 412, innerHeight: 823 };
var document = {
  body: body,
  scrollingElement: { scrollWidth: 412, scrollHeight: 5210 },
  documentElement: { scrollWidth: 412, scrollHeight: 5210 }
};
body.getElementsByTagName = function() { return __els; };
function getComputedStyle(e) { return { position: e.pos, visibility: e.vis }; }
''';

Future<Map<String, dynamic>?> layout(String dom) async {
  final out = await runJs([
    _prelude,
    dom,
    vsvLayoutJs,
    'console.log(window.__vsv_layout());',
  ].join('\n'));
  return out == null ? null : jsonDecode(out) as Map<String, dynamic>;
}

void main() {
  test('landmarks, frames, headings and big blocks are measured', () async {
    final r = await layout(r'''
add(mk('header', {id: 'top', cls: 'site-header dark extra', role: 'banner', rect: [0, 0, 412, 64], kids: 31}));
add(mk('h1', {text: '  Welcome   to the\n shop ', rect: [0, 70, 412, 40]}));
add(mk('iframe', {src: 'https://ads.test/slot', rect: [0, 120, 300, 250]}));
add(mk('div', {rect: [0, 400, 50, 50], kids: 3}));
add(mk('div', {rect: [0, 500, 412, 900], kids: 30}));
add(mk('nav', {vis: 'hidden', rect: [0, 2000, 412, 50]}));
''');
    if (r == null) return markTestSkipped('node not installed');
    expect((r['blocks'] as List).map((b) => '${b['t']}:${b['k']}'),
        ['header:landmark', 'h1:heading', 'iframe:frame', 'div:block']);
    expect(r['blocks'][0]['r'], 'banner');
    expect(r['blocks'][0]['i'], 'top');
    expect(r['blocks'][0]['c'], 'site-header dark');
    expect(r['blocks'][0]['n'], 31);
    expect(r['blocks'][0]['d'], 1);
    expect(r['blocks'][1]['tx'], 'Welcome to the shop');
    expect(r['blocks'][2]['s'], 'https://ads.test/slot');
    expect(r['total'], 4);
    expect([r['vw'], r['vh'], r['w'], r['h']], [412, 823, 412, 5210]);
  });

  test('coordinates are page coordinates', () async {
    final r = await layout(r'''
window.scrollY = 500; window.pageYOffset = 500;
add(mk('section', {rect: [10, -100, 200, 300]}));
''');
    if (r == null) return markTestSkipped('node not installed');
    expect(r['blocks'][0]['x'], 10);
    expect(r['blocks'][0]['y'], 400);
    expect(r['blocks'][0]['h'], 300);
  });

  test('fixed elements are flagged and data: sources dropped', () async {
    final r = await layout(r'''
add(mk('div', {pos: 'fixed', role: 'dialog', rect: [0, 0, 412, 200]}));
add(mk('img', {src: 'data:image/png;base64,AAAA', rect: [0, 300, 200, 200]}));
add(mk('img', {currentSrc: 'https://cdn.test/a.jpg', rect: [0, 600, 200, 200]}));
add(mk('img', {src: 'https://cdn.test/small.png', rect: [0, 900, 20, 20]}));
''');
    if (r == null) return markTestSkipped('node not installed');
    final b = r['blocks'] as List;
    expect(b[0]['f'], 1);
    expect(b[1]['f'], 0);
    expect(b[1]['s'], '');
    expect(b[2]['s'], 'https://cdn.test/a.jpg');
    expect(b.length, 3);
  });

  test('more than 400 qualifying elements are capped', () async {
    final r = await layout(r'''
for (var i = 0; i < 450; i++) add(mk('section', {rect: [0, i * 10, 100, 10]}));
''');
    if (r == null) return markTestSkipped('node not installed');
    expect((r['blocks'] as List).length, 400);
    expect(r['total'], 450);
  });

  test('a document without layout is empty', () async {
    final r = await layout(r'''
document.scrollingElement.scrollHeight = 0;
add(mk('section'));
''');
    if (r == null) return markTestSkipped('node not installed');
    expect(r, {'v': 1, 'empty': true});
  });
}
