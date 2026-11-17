// Browser-side instrumentation for the "suspicious techniques" check.
//
// Fresh load only: this script is injected into the headless measurement
// WebView, never into the live browser (`browser_view.dart`). It observes and
// never blocks or alters: every wrapper records inside try/catch and then calls
// the original with the original `this` and arguments. Keep this ES5-ish (no
// optional chaining, no arrow functions, no let/const).

/// Must run at document start. Defines `window.__vsv_tech_report()`, which
/// returns a JSON string (see the plan for the shape).
const String vsvTechniquesJs = r'''
(function() {
  try {
  if (window.__vsv_tech_report) return;
  var MAX_CANVAS = 20, MAX_PROMPTS = 20, MAX_SEEN = 100, MAX_FONTS = 500;
  var started = Date.now();
  var canvases = [];      // {el, w, h, chars, colors, reads, script}
  var entries = [];       // fallback without WeakMap: {ctx, el, fill, chars, colors}
  var byCtx = typeof WeakMap === 'function' ? new WeakMap() : null;
  var byEl = byCtx ? new WeakMap() : null;
  var fonts = { measureCalls: 0, seen: {}, seenCount: 0, script: '' };
  var webgl = { debugInfo: false, script: '' };
  var audio = { offline: 0, oscillators: 0, rendered: 0, script: '' };
  var rtc = { connections: 0, dataChannels: 0, offers: 0, getUserMedia: 0, script: '' };
  var counts = { enumerateDevices: 0, battery: 0, clipboardRead: 0 };
  var prompts = [];
  var offlineSeen = [], rtcSeen = [];

  // The first frame with an http(s) URL is the code that made the call. When
  // that is the page itself (inline script) there is no separate file to name.
  function script() {
    try {
      var lines = String(new Error().stack || '').split('\n');
      for (var i = 0; i < lines.length; i++) {
        var m = /(https?:\/\/[^\s)]+?)(?::\d+){0,2}\)?\s*$/.exec(lines[i]);
        if (m) {
          if (m[1].split('#')[0] === String(location.href).split('#')[0]) return '';
          return m[1].slice(0, 300);
        }
      }
    } catch (e) {}
    return '';
  }
  function seenNew(list, obj) {
    if (list.indexOf(obj) >= 0) return false;
    if (list.length < MAX_SEEN) list.push(obj);
    return true;
  }
  function ownerOf(obj, name) {
    while (obj && !Object.prototype.hasOwnProperty.call(obj, name)) {
      obj = Object.getPrototypeOf(obj);
    }
    return obj;
  }
  // Replaces obj[name] with a wrapper that records, then calls the original
  // unchanged. Skipped when the API is missing or cannot be redefined.
  function wrap(obj, name, before, after) {
    try {
      var owner = ownerOf(obj, name);
      if (!owner) return;
      var d = Object.getOwnPropertyDescriptor(owner, name);
      if (!d || typeof d.value !== 'function' || !d.configurable) return;
      var orig = d.value;
      Object.defineProperty(owner, name, {
        value: function() {
          if (before) { try { before(this, arguments); } catch (e) {} }
          var result = orig.apply(this, arguments);
          if (after) { try { after(this, arguments, result); } catch (e) {} }
          return result;
        },
        writable: d.writable, enumerable: d.enumerable, configurable: true });
    } catch (e) {}
  }
  function wrapSetter(obj, name, record) {
    try {
      var owner = ownerOf(obj, name);
      if (!owner) return;
      var d = Object.getOwnPropertyDescriptor(owner, name);
      if (!d || !d.set || !d.configurable) return;
      var set = d.set;
      Object.defineProperty(owner, name, {
        get: d.get, enumerable: d.enumerable, configurable: true,
        set: function(v) {
          try { record(this, v); } catch (e) {}
          return set.call(this, v);
        } });
    } catch (e) {}
  }
  function addPrompt(api) {
    if (prompts.length >= MAX_PROMPTS) return;
    var active = null;
    try {
      if (navigator.userActivation) active = !!navigator.userActivation.isActive;
    } catch (e) {}
    prompts.push({ api: api, atMs: Date.now() - started, userActive: active, script: script() });
  }
  function proto(name) {
    try {
      var c = (typeof window !== 'undefined' && window[name]) || null;
      return c && c.prototype ? c.prototype : null;
    } catch (e) { return null; }
  }

  // --- canvas ---
  // Text and colours are kept per context; a canvas record exists only once
  // the canvas was read back, so unread chart canvases cannot use up the slots.
  function ctxEntry(ctx) {
    if (byCtx) return byCtx.get(ctx) || null;
    for (var i = 0; i < entries.length; i++) if (entries[i].ctx === ctx) return entries[i];
    return null;
  }
  function elEntry(el) {
    if (byEl) return byEl.get(el) || null;
    for (var i = 0; i < entries.length; i++) if (entries[i].el === el) return entries[i];
    return null;
  }
  function addEntry(ctx, el) {
    var e = { ctx: ctx, el: el, fill: null, chars: {}, colors: {} };
    if (byCtx) {
      byCtx.set(ctx, e);
      byEl.set(el, e);
    } else if (entries.length < MAX_SEEN) {
      entries.push(e);
    }
  }
  function read(el) {
    if (el.width < 16 || el.height < 16) return;
    var r = null;
    for (var i = 0; i < canvases.length; i++) if (canvases[i].el === el) r = canvases[i];
    if (!r) {
      if (canvases.length >= MAX_CANVAS) return;
      r = { el: el, w: 0, h: 0, reads: 0, script: '' };
      canvases.push(r);
    }
    r.reads++;
    r.w = el.width; r.h = el.height;
    if (!r.script) r.script = script();
  }
  function drewText(ctx, args) {
    var e = ctxEntry(ctx);
    if (!e) return;
    var text = String(args[0]);
    // Emoji support checks (WordPress and others) draw surrogate pairs, joiners
    // and variation selectors and read them back; those are not counted.
    for (var i = 0; i < text.length; i++) {
      var code = text.charCodeAt(i);
      if ((code >= 0xD800 && code <= 0xDFFF) || (code >= 0x2000 && code <= 0x206F) ||
          (code >= 0xFE00 && code <= 0xFE0F)) continue;
      e.chars[text.charAt(i)] = 1;
    }
    if (e.fill !== null) e.colors[e.fill] = 1;
  }
  // The font family list of a CSS font string: style, variant, weight, size and
  // line height dropped, so "12px Arial" and "13px Arial" are one font.
  function fontFamily(f) {
    var m = /(?:^|\s)(?:[0-9.]+(?:px|pt|em|rem|%|ex|ch|vw|vh|vmin|vmax|cm|mm|in|pc|q)|xx-small|x-small|small|medium|large|x-large|xx-large|xxx-large|smaller|larger)(?:\/\S+)?\s+(.+)$/i.exec(f);
    return String(m ? m[1] : f).toLowerCase().replace(/\s+/g, ' ');
  }
  var canvasProto = proto('HTMLCanvasElement'), ctxProto = proto('CanvasRenderingContext2D');
  if (canvasProto) {
    wrap(canvasProto, 'getContext', null, function(el, args, ctx) {
      if (args[0] === '2d' && ctx && !ctxEntry(ctx)) addEntry(ctx, el);
    });
    wrap(canvasProto, 'toDataURL', function(el) { read(el); });
    wrap(canvasProto, 'toBlob', function(el) { read(el); });
  }
  if (ctxProto) {
    wrapSetter(ctxProto, 'fillStyle', function(ctx, v) {
      var e = ctxEntry(ctx);
      if (e) e.fill = typeof v === 'string' ? v : null;
    });
    wrap(ctxProto, 'fillText', function(ctx, args) { drewText(ctx, args); });
    wrap(ctxProto, 'strokeText', function(ctx, args) { drewText(ctx, args); });
    wrap(ctxProto, 'getImageData', function(ctx, args) {
      if (!(args[2] >= 16 && args[3] >= 16)) return;
      var e = ctxEntry(ctx);
      if (e) read(e.el);
    });
    wrap(ctxProto, 'measureText', function(ctx) {
      fonts.measureCalls++;
      var fam = fontFamily(String(ctx.font));
      if (!Object.prototype.hasOwnProperty.call(fonts.seen, fam) && fonts.seenCount < MAX_FONTS) {
        fonts.seen[fam] = 1;
        fonts.seenCount++;
      }
      if (!fonts.script) fonts.script = script();
    });
  }

  // --- webgl ---
  var glNames = ['WebGLRenderingContext', 'WebGL2RenderingContext'];
  for (var g = 0; g < glNames.length; g++) {
    var gp = proto(glNames[g]);
    if (!gp) continue;
    wrap(gp, 'getExtension', function(gl, args) {
      if (args[0] === 'WEBGL_debug_renderer_info') {
        webgl.debugInfo = true;
        if (!webgl.script) webgl.script = script();
      }
    });
    wrap(gp, 'getParameter', function(gl, args) {
      if (args[0] === 37445 || args[0] === 37446) {
        webgl.debugInfo = true;
        if (!webgl.script) webgl.script = script();
      }
    });
  }

  // --- audio ---
  var offlineProto = proto('OfflineAudioContext');
  function offlineCall(ctx) {
    try {
      if (typeof OfflineAudioContext !== 'undefined' && !(ctx instanceof OfflineAudioContext)) {
        return false;
      }
    } catch (e) {}
    if (seenNew(offlineSeen, ctx)) audio.offline++;
    if (!audio.script) audio.script = script();
    return true;
  }
  if (offlineProto) {
    wrap(offlineProto, 'createOscillator', function(ctx) {
      if (offlineCall(ctx)) audio.oscillators++;
    });
    wrap(offlineProto, 'startRendering', function(ctx) {
      if (offlineCall(ctx)) audio.rendered++;
    });
  }

  // --- webrtc and media ---
  var rtcProto = proto('RTCPeerConnection');
  function rtcCall(pc) {
    if (seenNew(rtcSeen, pc)) rtc.connections++;
    if (!rtc.script) rtc.script = script();
  }
  if (rtcProto) {
    wrap(rtcProto, 'createDataChannel', function(pc) { rtcCall(pc); rtc.dataChannels++; });
    wrap(rtcProto, 'createOffer', function(pc) { rtcCall(pc); rtc.offers++; });
  }
  try {
    if (typeof navigator !== 'undefined' && navigator.mediaDevices) {
      var md = navigator.mediaDevices;
      wrap(md, 'getUserMedia', function() {
        rtc.getUserMedia++;
        if (!rtc.script) rtc.script = script();
        addPrompt('camera-microphone');
      });
      wrap(md, 'enumerateDevices', function() { counts.enumerateDevices++; });
    }
  } catch (e) {}

  // --- other APIs ---
  try {
    if (typeof navigator !== 'undefined') {
      wrap(navigator, 'getBattery', function() { counts.battery++; });
      wrap(navigator, 'requestMIDIAccess', function() { addPrompt('midi'); });
      if (navigator.geolocation) {
        wrap(navigator.geolocation, 'getCurrentPosition', function() { addPrompt('geolocation'); });
        wrap(navigator.geolocation, 'watchPosition', function() { addPrompt('geolocation'); });
      }
      if (navigator.clipboard) {
        wrap(navigator.clipboard, 'read', function() { counts.clipboardRead++; addPrompt('clipboard'); });
        wrap(navigator.clipboard, 'readText', function() { counts.clipboardRead++; addPrompt('clipboard'); });
      }
    }
    if (typeof Notification !== 'undefined') {
      wrap(Notification, 'requestPermission', function() { addPrompt('notifications'); });
    }
    if (typeof document !== 'undefined') {
      wrap(document, 'requestStorageAccess', function() { addPrompt('storage-access'); });
    }
  } catch (e) {}

  window.__vsv_tech_report = function() {
    var out = [];
    for (var i = 0; i < canvases.length; i++) {
      var c = canvases[i];
      if (c.reads > 0) {
        var e = elEntry(c.el);
        out.push({ w: c.w, h: c.h, chars: e ? Object.keys(e.chars).length : 0,
          colors: e ? Object.keys(e.colors).length : 0, reads: c.reads, script: c.script });
      }
    }
    return JSON.stringify({ v: 1, canvas: out,
      fonts: { measureCalls: fonts.measureCalls, distinctFonts: fonts.seenCount,
        script: fonts.script },
      webgl: webgl, audio: audio, rtc: rtc,
      enumerateDevices: counts.enumerateDevices, battery: counts.battery,
      clipboardRead: counts.clipboardRead, prompts: prompts });
  };
  } catch (e) {}
})();
''';
