// Browser-side JavaScript for the one-shot collector.
//
// Injection and wiring happen elsewhere. Keep this ES5-ish (no optional
// chaining, no arrow functions) for older WebViews.

/// Must run at document start (UserScriptInjectionTime.AT_DOCUMENT_START).
/// Buffers resource-timing entries (survives clearResourceTimings) in
/// `window.__vsv_obs` and fetch/XHR content-lengths in `window.__vsv_patch`.
///
/// Injected into every frame. An iframe (ads, embeds) only observes its own
/// resources and posts them to the top frame (`{__vsv_frame: 1, ...}`), which
/// records them with `fr: 1` and the frame's origin in `fo`. Start times are
/// moved to the top frame's time origin.
const String vsvResourceBootstrapJs = r'''
(function() {
  if (window.__vsv_boot) return;
  window.__vsv_boot = true;
  var isTop = true;
  try { isTop = window === window.top; } catch (e) { isTop = false; }
  var MAX = 2000;
  window.__vsv_obs = {};
  window.__vsv_obsCount = 0;
  window.__vsv_obsDropped = 0;
  window.__vsv_obsOk = false;
  window.__vsv_patch = [];
  window.__vsv_patchDropped = 0;
  try {
    if (performance.setResourceTimingBufferSize) {
      performance.setResourceTimingBufferSize(10000);
    }
  } catch (e) {}
  function skip(name) {
    return !name || name.indexOf('data:') === 0 || name.indexOf('blob:') === 0;
  }
  // A field the browser does not report stays null (never 0).
  function num(v) { return typeof v === 'number' ? v : null; }
  function sum(o) { return (o.tx || 0) + (o.enc || 0) + (o.dec || 0); }
  function record(e) {
    if (skip(e.name)) return;
    var cur = {
      it: e.initiatorType || '',
      st: num(e.startTime),
      du: num(e.duration),
      tx: num(e.transferSize),
      enc: num(e.encodedBodySize),
      dec: num(e.decodedBodySize)
    };
    // Keep the first start/duration; take the sizes when they are larger.
    store(e.name, cur);
  }
  function store(name, cur) {
    var prev = window.__vsv_obs[name];
    if (prev) {
      if (sum(cur) > sum(prev)) {
        prev.tx = cur.tx; prev.enc = cur.enc; prev.dec = cur.dec;
        if (!isTop) markDirty(name); else notifyApp();
      }
      return;
    }
    if (window.__vsv_obsCount >= MAX) { window.__vsv_obsDropped++; return; }
    window.__vsv_obs[name] = cur;
    window.__vsv_obsCount++;
    if (!isTop) markDirty(name); else notifyApp();
  }
  // Top frame: tell the app that resources arrived (lazy images, ads after
  // scrolling), at most once a second. The app collects again when it
  // wants; nothing is sent here but the count.
  var notifyTimer = null;
  function notifyApp() {
    if (notifyTimer !== null) return;
    notifyTimer = setTimeout(function() {
      notifyTimer = null;
      try {
        var b = window.flutter_inappwebview;
        if (b && typeof b.callHandler === 'function') {
          var r = b.callHandler('vsvResources', window.__vsv_obsCount);
          if (r && typeof r.catch === 'function') r.catch(function() {});
        }
      } catch (e) {}
    }, 1000);
  }
  // Iframe: post new/grown entries to the top frame, batched.
  var dirty = {}, flushTimer = null;
  function markDirty(name) {
    dirty[name] = true;
    if (flushTimer === null) flushTimer = setTimeout(flush, 500);
  }
  function flush() {
    flushTimer = null;
    var out = [];
    for (var n in dirty) {
      if (!Object.prototype.hasOwnProperty.call(dirty, n)) continue;
      var o = window.__vsv_obs[n];
      if (o) out.push({n: n, it: o.it, st: o.st, du: o.du, tx: o.tx, enc: o.enc, dec: o.dec});
    }
    dirty = {};
    if (!out.length) return;
    try {
      var origin = '';
      try { origin = location.origin; } catch (e) {}
      window.top.postMessage({__vsv_frame: 1, fo: origin,
          to: performance.timeOrigin || null, e: out}, '*');
    } catch (e) {}
  }
  // Top frame: an image served from the memory cache creates no timing
  // entry, but it still fires 'load'; that is a reason to collect again too.
  if (isTop) {
    try {
      document.addEventListener('load', function(ev) {
        var t = ev.target;
        if (t && t.tagName === 'IMG') notifyApp();
      }, true);
    } catch (e) {}
  }
  // Top frame: take what the iframes post. Only messages of this shape from
  // another window; the entries are page-provided data, like the timings.
  if (isTop) {
    try {
      window.addEventListener('message', function(ev) {
        try {
          var d = ev.data;
          if (!d || d.__vsv_frame !== 1 || ev.source === window) return;
          if (!d.e || typeof d.e.length !== 'number') return;
          var shift = (typeof d.to === 'number' && performance.timeOrigin)
              ? d.to - performance.timeOrigin : null;
          var fo = typeof d.fo === 'string' ? d.fo.slice(0, 200) : '';
          for (var i = 0; i < d.e.length && i < MAX; i++) {
            var x = d.e[i];
            if (!x || typeof x.n !== 'string' || skip(x.n)) continue;
            var st = num(x.st);
            store(x.n, {it: typeof x.it === 'string' ? x.it : '',
                st: st === null ? null : (shift === null ? null : st + shift),
                du: num(x.du), tx: num(x.tx), enc: num(x.enc), dec: num(x.dec),
                fr: 1, fo: fo});
          }
        } catch (e) {}
      });
    } catch (e) {}
  }
  try {
    var obs = new PerformanceObserver(function(list) {
      var es = list.getEntries();
      for (var i = 0; i < es.length; i++) record(es[i]);
    });
    obs.observe({type: 'resource', buffered: true});
    // Only set when observe() did not throw; otherwise the collector falls
    // back to performance.getEntriesByType.
    window.__vsv_obsOk = true;
  } catch (e) {}
  // st is performance.now() taken when the request started, not at response.
  function patchRecord(url, cl, kind, st) {
    if (skip(url) || !(cl > 0)) return;
    if (window.__vsv_patch.length >= MAX) { window.__vsv_patchDropped++; return; }
    window.__vsv_patch.push({n: url, it: kind, cl: cl, st: st});
  }
  try {
    var origFetch = window.fetch;
    if (isTop && typeof origFetch === 'function') {
      window.fetch = function(input, init) {
        var url = typeof input === 'string' ? input :
            (input && input.url) ? input.url : String(input);
        var t0 = performance.now();
        return origFetch.apply(this, arguments).then(function(resp) {
          try {
            var cl = resp.headers.get('content-length');
            if (cl) patchRecord(url, parseInt(cl, 10), 'fetch', t0);
          } catch (e) {}
          return resp;
        });
      };
    }
  } catch (e) {}
  if (isTop) try {
    var xhrOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(m, u) {
      this.__vsvUrl = u;
      return xhrOpen.apply(this, arguments);
    };
    var xhrSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function() {
      var xhr = this;
      var t0 = performance.now();
      xhr.addEventListener('load', function() {
        try {
          var cl = xhr.getResponseHeader('content-length');
          if (cl && xhr.__vsvUrl) patchRecord(String(xhr.__vsvUrl), parseInt(cl, 10), 'xhr', t0);
        } catch (e) {}
      });
      return xhrSend.apply(this, arguments);
    };
  } catch (e) {}
})();
''';

/// Defines `window.__vsv_collect()`, which returns ONE JSON string. Every
/// section carries its own `ok` / `error` so one failure drops nothing else.
const String vsvCollectJs = r'''
window.__vsv_collect = function() {
  var STORAGE_MAX_ITEMS = 500;
  function describe(e) {
    try { return (e && e.name ? e.name + ': ' + e.message : String(e)); }
    catch (x) { return 'unknown error'; }
  }
  function section(fn) {
    try { var v = fn(); v.ok = true; return v; }
    catch (e) { return {ok: false, error: describe(e)}; }
  }
  var out = {v: 1};
  try { out.url = location.href; } catch (e) { out.url = null; }
  try { out.contentType = document.contentType || null; } catch (e) { out.contentType = null; }

  out.timing = section(function() {
    return {now: performance.now(), timeOrigin: performance.timeOrigin || null};
  });

  out.dom = section(function() {
    var ct = document.contentType || '';
    var isXml = /xml|svg/i.test(ct);
    var value = '';
    if (isXml) {
      value = new XMLSerializer().serializeToString(document);
    } else {
      try {
        var child = document.firstChild;
        while (child) {
          if (child.nodeType === 10) {
            value += new XMLSerializer().serializeToString(child) + '\n';
          } else if (child.nodeType === 1) {
            value += child.outerHTML;
          } else if (child.nodeType === 8) {
            value += '<!--' + child.nodeValue + '-->';
          } else if (child.nodeType === 3) {
            value += child.nodeValue;
          }
          child = child.nextSibling;
        }
      } catch (e) {
        value = document.documentElement ? document.documentElement.outerHTML : '';
      }
      if (!value && document.documentElement) value = document.documentElement.outerHTML;
    }
    var res = {value: value};
    // Browsers wrap text/plain, JSON, JS and CSS documents in a <pre>; give the
    // parser the raw text. Only for non-HTML content types.
    if (!isXml && ct && ct.indexOf('html') < 0 && document.body) {
      var pre = document.body.firstElementChild;
      if (pre && pre.tagName === 'PRE') res.raw = pre.textContent;
    }
    var iframes = 0, shadows = 0;
    try {
      iframes = document.getElementsByTagName('iframe').length;
      var all = document.getElementsByTagName('*');
      var n = Math.min(all.length, 20000);
      for (var i = 0; i < n; i++) if (all[i].shadowRoot) shadows++;
    } catch (e) {}
    res.iframes = iframes;
    res.shadowRoots = shadows;
    return res;
  });

  function num(v) { return typeof v === 'number' ? v : null; }

  out.resources = section(function() {
    var observer = [];
    var bootstrap = window.__vsv_obsOk === true &&
        typeof window.__vsv_obs === 'object' && window.__vsv_obs !== null;
    if (bootstrap) {
      for (var name in window.__vsv_obs) {
        if (!Object.prototype.hasOwnProperty.call(window.__vsv_obs, name)) continue;
        var o = window.__vsv_obs[name];
        var item = {n: name, it: o.it, st: o.st, du: o.du, tx: o.tx, enc: o.enc, dec: o.dec};
        if (o.fr === 1) { item.fr = 1; item.fo = o.fo; }
        observer.push(item);
      }
    } else {
      var es = performance.getEntriesByType('resource');
      for (var i = 0; i < es.length; i++) {
        var e = es[i];
        if (!e.name || e.name.indexOf('data:') === 0 || e.name.indexOf('blob:') === 0) continue;
        observer.push({n: e.name, it: e.initiatorType || '', st: num(e.startTime), du: num(e.duration),
          tx: num(e.transferSize), enc: num(e.encodedBodySize), dec: num(e.decodedBodySize)});
      }
    }
    // Images actually shown (loaded, with pixels), as the page uses them.
    // A lazy placeholder that has not loaded yet is not one.
    var shown = [];
    try {
      var imgs = document.images, seen = {};
      for (var j = 0; j < imgs.length && shown.length < 2000; j++) {
        var im = imgs[j];
        if (!im.complete || !(im.naturalWidth > 0)) continue;
        var src = im.currentSrc || im.src;
        if (!src || src.indexOf('http') !== 0 || seen[src]) continue;
        seen[src] = true;
        shown.push(src);
      }
    } catch (e) {}
    return {
      bootstrap: bootstrap,
      observer: observer,
      shown: shown,
      patch: (window.__vsv_patch || []).slice(0),
      dropped: window.__vsv_obsDropped || 0,
      patchDropped: window.__vsv_patchDropped || 0
    };
  });

  out.navigation = section(function() {
    var nav = performance.getEntriesByType('navigation')[0];
    if (!nav) throw new Error('no navigation timing entry');
    return {
      responseStart: nav.responseStart, domInteractive: nav.domInteractive,
      domContentLoaded: nav.domContentLoadedEventEnd, loadEnd: nav.loadEventEnd,
      protocol: nav.nextHopProtocol || null
    };
  });

  function area(which) {
    try {
      var s = window[which];
      var count = s.length;
      var items = [];
      var n = Math.min(count, STORAGE_MAX_ITEMS);
      for (var i = 0; i < n; i++) {
        var k = s.key(i);
        items.push({k: k, v: s.getItem(k) || ''});
      }
      return {ok: true, count: count, items: items, truncated: count > n};
    } catch (e) {
      return {ok: false, error: describe(e)};
    }
  }
  out.storage = {local: area('localStorage'), session: area('sessionStorage')};

  out.cookies = section(function() { return {raw: document.cookie || ''}; });

  try { return JSON.stringify(out); }
  catch (e) { return JSON.stringify({v: 1, fatal: describe(e)}); }
};
''';
