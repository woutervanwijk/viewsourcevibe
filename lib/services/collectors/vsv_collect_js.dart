// Browser-side JavaScript for the one-shot collector.
//
// Injection and wiring happen elsewhere. Keep this ES5-ish (no optional
// chaining, no arrow functions) for older WebViews.

/// Must run at document start (UserScriptInjectionTime.AT_DOCUMENT_START).
/// Buffers resource-timing entries (survives clearResourceTimings) in
/// `window.__vsv_obs` and fetch/XHR content-lengths in `window.__vsv_patch`.
const String vsvResourceBootstrapJs = r'''
(function() {
  if (window.__vsv_boot) return;
  window.__vsv_boot = true;
  var MAX = 2000;
  window.__vsv_obs = {};
  window.__vsv_obsCount = 0;
  window.__vsv_obsDropped = 0;
  window.__vsv_patch = [];
  try {
    if (performance.setResourceTimingBufferSize) {
      performance.setResourceTimingBufferSize(10000);
    }
  } catch (e) {}
  function skip(name) {
    return !name || name.indexOf('data:') === 0 || name.indexOf('blob:') === 0;
  }
  function record(e) {
    if (skip(e.name)) return;
    var cur = {
      it: e.initiatorType || '',
      st: e.startTime || 0,
      du: e.duration || 0,
      tx: e.transferSize || 0,
      enc: e.encodedBodySize || 0,
      dec: e.decodedBodySize || 0
    };
    var prev = window.__vsv_obs[e.name];
    if (prev) {
      // Keep the first start/duration; take the sizes when they are larger.
      if (cur.tx + cur.enc + cur.dec > prev.tx + prev.enc + prev.dec) {
        prev.tx = cur.tx; prev.enc = cur.enc; prev.dec = cur.dec;
      }
      return;
    }
    if (window.__vsv_obsCount >= MAX) { window.__vsv_obsDropped++; return; }
    window.__vsv_obs[e.name] = cur;
    window.__vsv_obsCount++;
  }
  try {
    var obs = new PerformanceObserver(function(list) {
      var es = list.getEntries();
      for (var i = 0; i < es.length; i++) record(es[i]);
    });
    obs.observe({type: 'resource', buffered: true});
  } catch (e) {}
  function patchRecord(url, cl, kind) {
    if (skip(url) || !(cl > 0) || window.__vsv_patch.length >= MAX) return;
    window.__vsv_patch.push({n: url, it: kind, cl: cl, st: performance.now()});
  }
  try {
    var origFetch = window.fetch;
    if (typeof origFetch === 'function') {
      window.fetch = function(input, init) {
        var url = typeof input === 'string' ? input :
            (input && input.url) ? input.url : String(input);
        return origFetch.apply(this, arguments).then(function(resp) {
          try {
            var cl = resp.headers.get('content-length');
            if (cl) patchRecord(url, parseInt(cl, 10), 'fetch');
          } catch (e) {}
          return resp;
        });
      };
    }
  } catch (e) {}
  try {
    var xhrOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(m, u) {
      this.__vsvUrl = u;
      return xhrOpen.apply(this, arguments);
    };
    var xhrSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function() {
      var xhr = this;
      xhr.addEventListener('load', function() {
        try {
          var cl = xhr.getResponseHeader('content-length');
          if (cl && xhr.__vsvUrl) patchRecord(String(xhr.__vsvUrl), parseInt(cl, 10), 'xhr');
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

  out.resources = section(function() {
    var observer = [];
    var bootstrap = typeof window.__vsv_obs === 'object' && window.__vsv_obs !== null;
    if (bootstrap) {
      for (var name in window.__vsv_obs) {
        if (!Object.prototype.hasOwnProperty.call(window.__vsv_obs, name)) continue;
        var o = window.__vsv_obs[name];
        observer.push({n: name, it: o.it, st: o.st, du: o.du, tx: o.tx, enc: o.enc, dec: o.dec});
      }
    } else {
      var es = performance.getEntriesByType('resource');
      for (var i = 0; i < es.length; i++) {
        var e = es[i];
        if (!e.name || e.name.indexOf('data:') === 0 || e.name.indexOf('blob:') === 0) continue;
        observer.push({n: e.name, it: e.initiatorType || '', st: e.startTime || 0, du: e.duration || 0,
          tx: e.transferSize || 0, enc: e.encodedBodySize || 0, dec: e.decodedBodySize || 0});
      }
    }
    return {
      bootstrap: bootstrap,
      observer: observer,
      patch: (window.__vsv_patch || []).slice(0),
      dropped: window.__vsv_obsDropped || 0
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
