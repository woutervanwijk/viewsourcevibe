import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/technique_signals.dart';
import 'package:view_source_vibe/services/derive/techniques.dart';

TechniqueSignals signals({
  List<CanvasRead> canvas = const [],
  int distinctFonts = 0,
  bool webglDebugInfo = false,
  int audioOffline = 0,
  int audioOscillators = 0,
  int audioRendered = 0,
  int rtcConnections = 0,
  int rtcDataChannels = 0,
  int rtcOffers = 0,
  int rtcGetUserMedia = 0,
  int enumerateDevices = 0,
  int battery = 0,
  int clipboardRead = 0,
  List<PromptCall> prompts = const [],
  Map<String, String> scripts = const {},
}) =>
    TechniqueSignals(
      canvas: canvas,
      fontMeasureCalls: distinctFonts,
      distinctFonts: distinctFonts,
      webglDebugInfo: webglDebugInfo,
      audioOffline: audioOffline,
      audioOscillators: audioOscillators,
      audioRendered: audioRendered,
      rtcConnections: rtcConnections,
      rtcDataChannels: rtcDataChannels,
      rtcOffers: rtcOffers,
      rtcGetUserMedia: rtcGetUserMedia,
      enumerateDevices: enumerateDevices,
      battery: battery,
      clipboardRead: clipboardRead,
      prompts: prompts,
      scripts: scripts,
    );

void main() {
  test('text in two colours read back is a canvas fingerprint', () {
    final f = judgeSignals(signals(canvas: [
      const CanvasRead(
          width: 300,
          height: 150,
          chars: 34,
          colors: 2,
          reads: 1,
          script: 'https://cdn.fp.test/fp.js')
    ]));
    expect(f.single.id, 'canvas-fingerprint');
    expect(f.single.severity, TechniqueSeverity.high);
    expect(f.single.scripts, ['https://cdn.fp.test/fp.js']);
  });

  test('ten distinct characters in one colour is enough; nine is not', () {
    CanvasRead c(int chars) => CanvasRead(
        width: 300, height: 150, chars: chars, colors: 1, reads: 1, script: '');
    expect(
        judgeSignals(signals(canvas: [c(10)])).single.id, 'canvas-fingerprint');
    expect(judgeSignals(signals(canvas: [c(9)])), isEmpty);
  });

  test('a chart is not a fingerprint', () {
    expect(
        judgeSignals(signals(canvas: [
          const CanvasRead(
              width: 800,
              height: 400,
              chars: 0,
              colors: 1,
              reads: 3,
              script: '')
        ])),
        isEmpty);
  });

  test('a tiny canvas is not a fingerprint', () {
    expect(
        judgeSignals(signals(canvas: [
          const CanvasRead(
              width: 8, height: 8, chars: 30, colors: 3, reads: 1, script: '')
        ])),
        isEmpty);
  });

  test('50 fonts measured is font probing; 49 is not', () {
    final f = judgeSignals(signals(distinctFonts: 96));
    expect(f.single.id, 'font-probing');
    expect(f.single.title, contains('96 different fonts'));
    expect(judgeSignals(signals(distinctFonts: 49)), isEmpty);
  });

  test('audio needs offline context, oscillator and rendering', () {
    expect(
        judgeSignals(
                signals(audioOffline: 1, audioOscillators: 1, audioRendered: 1))
            .single
            .id,
        'audio-fingerprint');
    expect(
        judgeSignals(signals(audioOffline: 1, audioOscillators: 1)), isEmpty);
  });

  test('a WebRTC connection without a call is a probe', () {
    expect(judgeSignals(signals(rtcConnections: 1, rtcOffers: 1)).single.id,
        'webrtc-probe');
  });

  test('a video call is not a WebRTC probe', () {
    expect(
        judgeSignals(
            signals(rtcConnections: 1, rtcOffers: 1, rtcGetUserMedia: 1)),
        isEmpty);
  });

  test('single-call signals', () {
    final f = judgeSignals(signals(
        webglDebugInfo: true,
        enumerateDevices: 1,
        battery: 2,
        clipboardRead: 1));
    expect(f.map((e) => e.id).toSet(), {
      'webgl-fingerprint',
      'device-enumeration',
      'battery',
      'clipboard-read'
    });
  });

  test('a prompt without a click is reported, with its delay', () {
    final f = judgeSignals(signals(prompts: [
      const PromptCall(
          api: 'notifications',
          at: Duration(milliseconds: 2400),
          userActive: false,
          script: 'https://x.test/p.js')
    ]));
    expect(f.single.id, 'prompt-on-load');
    expect(f.single.title,
        'Asks for notifications without a click, 2 s after loading');
    expect(f.single.scripts, ['https://x.test/p.js']);
  });

  test('a prompt after a click, or of unknown activity, is not reported', () {
    expect(
        judgeSignals(signals(prompts: [
          const PromptCall(
              api: 'geolocation',
              at: Duration(seconds: 3),
              userActive: true,
              script: ''),
          const PromptCall(
              api: 'geolocation',
              at: Duration(seconds: 3),
              userActive: null,
              script: ''),
        ])),
        isEmpty);
  });

  test('toJson carries no more than the finding', () {
    final j = judgeSignals(signals(clipboardRead: 1)).single.toJson();
    expect(j['id'], 'clipboard-read');
    expect(j['severity'], 'high');
  });

  test('report parsing', () {
    expect(parseTechniqueReport(null), isA<Unavailable<TechniqueSignals>>());
    expect(parseTechniqueReport('not json'), isA<Failed<TechniqueSignals>>());
    final r = parseTechniqueReport(jsonEncode({
      'v': 1,
      'canvas': [
        {
          'w': 300,
          'h': 150,
          'chars': 34,
          'colors': 2,
          'reads': 1,
          'script': 'https://a.test/x.js'
        }
      ],
      'fonts': {
        'measureCalls': 200,
        'distinctFonts': 96,
        'script': 'https://a.test/f.js'
      },
      'webgl': {'debugInfo': true, 'script': ''},
      'audio': {'offline': 1, 'oscillators': 1, 'rendered': 1, 'script': ''},
      'rtc': {
        'connections': 1,
        'dataChannels': 1,
        'offers': 1,
        'getUserMedia': 0,
        'script': ''
      },
      'enumerateDevices': 1,
      'battery': 0,
      'clipboardRead': 0,
      'prompts': [
        {
          'api': 'notifications',
          'atMs': 1500,
          'userActive': false,
          'script': 's'
        }
      ],
    })) as Present<TechniqueSignals>;
    final s = r.value;
    expect(r.source, DataSource.browser);
    expect(s.distinctFonts, 96);
    expect(s.canvas.single.chars, 34);
    expect(s.prompts.single.at, const Duration(milliseconds: 1500));
    expect(s.prompts.single.userActive, false);
    expect(s.scripts['fonts'], 'https://a.test/f.js');
    expect(s.webglDebugInfo, true);
  });

  test('a report with the wrong shape fails instead of reading as clean', () {
    expect(parseTechniqueReport('[1,2]'), isA<Failed<TechniqueSignals>>());
    expect(parseTechniqueReport(42), isA<Failed<TechniqueSignals>>());
  });
}
