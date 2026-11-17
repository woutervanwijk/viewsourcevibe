// Browser-side JavaScript that measures the page's boxes. Read-only: it reads
// layout (getBoundingClientRect, getComputedStyle) and never scrolls, resizes
// or writes to the page. Keep this ES5-ish (no arrow functions, no let/const).

/// Defines `window.__vsv_layout()`, which returns a JSON string:
/// `{v, vw, vh, w, h, total, blocks: [{t, r, i, c, x, y, w, h, d, n, k, s,
/// f, tx}]}` with coordinates in page space, or `{v: 1, empty: true}` when the
/// document has no layout. `blocks` holds the first 400 qualifying elements
/// in document order; `total` counts all of them.
const String vsvLayoutJs = r'''
(function() {
  var MAX_BLOCKS = 400, MAX_SCAN = 20000, MAX_DEPTH = 12;
  var LANDMARK_TAGS = {header: 1, nav: 1, main: 1, article: 1, section: 1,
    aside: 1, footer: 1, form: 1, dialog: 1};
  var LANDMARK_ROLES = {banner: 1, navigation: 1, main: 1, complementary: 1,
    contentinfo: 1, search: 1, form: 1, region: 1, dialog: 1};

  function kindOf(tag, role, w, h, vArea) {
    if (tag === 'iframe') return 'frame';
    if (/^h[1-6]$/.test(tag)) return 'heading';
    if (LANDMARK_TAGS[tag] === 1 || (role && LANDMARK_ROLES[role] === 1)) return 'landmark';
    if (tag === 'video' || tag === 'canvas') return 'media';
    if (tag === 'img' && w * h >= 10000) return 'media';
    return w * h >= 0.15 * vArea ? 'maybe' : '';
  }

  function depthOf(el, body) {
    var d = 0, p = el;
    while (p && p !== body && d < 100) { p = p.parentNode; d++; }
    return d;
  }

  function sourceOf(el, tag) {
    var s = '';
    if (tag === 'iframe') s = el.src || '';
    else if (tag === 'img' || tag === 'video') s = el.currentSrc || el.src || '';
    return /^data:/i.test(s) ? '' : s.slice(0, 2000);
  }

  window.__vsv_layout = function() {
    var body = document.body;
    var se = document.scrollingElement || document.documentElement;
    var docW = se ? se.scrollWidth : 0, docH = se ? se.scrollHeight : 0;
    if (!body || !docW || !docH) return JSON.stringify({v: 1, empty: true});
    var sx = window.pageXOffset || window.scrollX || 0;
    var sy = window.pageYOffset || window.scrollY || 0;
    var vw = window.innerWidth || 0, vh = window.innerHeight || 0;
    var vArea = vw * vh;
    var all = body.getElementsByTagName('*');
    var limit = Math.min(all.length, MAX_SCAN);
    var blocks = [], total = 0;
    for (var i = 0; i < limit; i++) {
      var el = all[i];
      var tag = String(el.tagName || '').toLowerCase();
      var rect = el.getBoundingClientRect();
      if (rect.width < 1 || rect.height < 1) continue;
      var x = rect.left + sx, y = rect.top + sy;
      if (x + rect.width <= 0 || y + rect.height <= 0) continue;
      var role = el.getAttribute('role') || '';
      var kind = kindOf(tag, role, rect.width, rect.height, vArea);
      if (!kind) continue;
      var depth = depthOf(el, body);
      var n = el.getElementsByTagName('*').length;
      if (kind === 'maybe') {
        if (n < 20 || depth > MAX_DEPTH) continue;
        kind = 'block';
      }
      var cs = getComputedStyle(el);
      if (cs.visibility === 'hidden') continue;
      total++;
      if (blocks.length >= MAX_BLOCKS) continue;
      blocks.push({
        t: tag, r: role,
        i: String(el.id || '').slice(0, 60),
        c: String(el.className && el.className.baseVal !== undefined ? el.className.baseVal : (el.className || ''))
          .replace(/^\s+|\s+$/g, '').split(/\s+/).slice(0, 2).join(' ').slice(0, 60),
        x: Math.round(x), y: Math.round(y),
        w: Math.round(rect.width), h: Math.round(rect.height),
        d: depth, n: n, k: kind, s: sourceOf(el, tag),
        f: cs.position === 'fixed' || cs.position === 'sticky' ? 1 : 0,
        tx: kind === 'heading'
            ? String(el.textContent || '').replace(/\s+/g, ' ').replace(/^ | $/g, '').slice(0, 80)
            : ''
      });
    }
    return JSON.stringify({v: 1, vw: vw, vh: vh, w: docW, h: docH,
      total: total, blocks: blocks});
  };
})();
''';
