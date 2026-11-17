import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/technique_signals.dart';
import 'package:view_source_vibe/services/cname_cloaking_service.dart';
import 'package:view_source_vibe/services/derive/techniques.dart';
import 'package:view_source_vibe/services/metadata_parser.dart';

import 'fixtures.dart';

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

  test('the same prompt asked for twice is one finding, the earliest', () {
    PromptCall p(String api, int ms, String script) => PromptCall(
        api: api,
        at: Duration(milliseconds: ms),
        userActive: false,
        script: script);
    final f = judgeSignals(signals(prompts: [
      p('geolocation', 3000, 'https://b.test/b.js'),
      p('geolocation', 1000, 'https://a.test/a.js'),
      p('notifications', 2000, ''),
    ]));
    expect(f.length, 2);
    final geo = f.firstWhere((e) => e.title.contains('geolocation'));
    expect(geo.title, contains('1 s after loading'));
    expect(geo.scripts, ['https://a.test/a.js']);
  });

  test('canvas text does not claim charts never draw text', () {
    final f = judgeSignals(signals(canvas: [
      const CanvasRead(
          width: 300, height: 150, chars: 34, colors: 2, reads: 1, script: '')
    ]));
    expect(
        f.single.detail,
        contains('Charts and image editors rarely read back a canvas they '
            'drew text on.'));
  });

  test('toJson carries no more than the finding', () {
    final j = judgeSignals(signals(clipboardRead: 1)).single.toJson();
    expect(j['id'], 'clipboard-read');
    expect(j['severity'], 'high');
  });

  test('report parsing', () {
    expect(parseTechniqueReport(null), isA<Unavailable<TechniqueSignals>>());
    expect(parseTechniqueReport('not json'), isA<Failed<TechniqueSignals>>());
    expect((parseTechniqueReport('not json') as Failed).error,
        'The technique report could not be read');
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

  group('shared identifiers', () {
    const id = 'a1b2c3d4e5f6a7b8c9';

    test('an identifier sent to two other parties is reported, without its value',
        () {
      final f = findSharedIdentifiers(browserSnap(
          url: 'https://shop.test/',
          cookies: [cookie('_uid', value: id)],
          resources: [
            res('https://sync.ads-a.test/p?u=$id'),
            res('https://px.ads-b.test/m/$id'),
            res('https://shop.test/api?u=$id'),
          ]));
      expect(f.single.id, 'id-sharing');
      expect(f.single.severity, TechniqueSeverity.medium);
      expect(f.single.title,
          'The identifier in cookie _uid is sent to 2 other parties');
      expect(f.single.scripts, ['ads-a.test', 'ads-b.test']);
      expect('${f.single.toJson()}'.contains(id), isFalse,
          reason: 'a finding repeated a cookie value');
    });

    test('a url-encoded value is found too', () {
      const raw = 'abc def+ghi/jklmno=pq';
      final enc = Uri.encodeComponent(raw);
      final f = findSharedIdentifiers(browserSnap(
          url: 'https://shop.test/',
          cookies: [cookie('sid', value: raw)],
          resources: [
            res('https://a.one.test/p?u=$enc'),
            res('https://b.two.test/p?u=$enc'),
          ]));
      expect(f.single.scripts, ['one.test', 'two.test']);
    });

    test('short and common values are never identifiers', () {
      for (final v in ['1', 'true', 'en', '1731628800', 'aaaaaaaaaaaaaaaaaaaa']) {
        final f = findSharedIdentifiers(browserSnap(
            url: 'https://shop.test/',
            cookies: [cookie('c', value: v)],
            resources: [
              res('https://a.one.test/p?u=$v'),
              res('https://b.two.test/p?u=$v'),
            ]));
        expect(f, isEmpty, reason: 'a short or common value was reported');
      }
    });

    test('consent strings are not identifiers', () {
      for (final n in [
        'euconsent-v2',
        'addtl_consent',
        'OptanonConsent',
        'OptanonAlertBoxClosed',
        'CookieConsent',
        'didomi_token',
        'usprivacy',
        '__cmpconsent15',
      ]) {
        final f = findSharedIdentifiers(browserSnap(
            url: 'https://shop.test/',
            cookies: [cookie(n, value: id)],
            resources: [
              res('https://a.one.test/p?u=$id'),
              res('https://b.two.test/p?u=$id'),
            ]));
        expect(f.isEmpty, isTrue, reason: '$n was reported');
      }
    });

    test('the same value in two cookies is one finding', () {
      final f = findSharedIdentifiers(browserSnap(
          url: 'https://shop.test/',
          cookies: [cookie('_a', value: id), cookie('_b', value: id)],
          resources: [
            res('https://a.one.test/p?u=$id'),
            res('https://b.two.test/p?u=$id'),
          ]));
      expect(f.length, 1);
    });

    test('two cookies with one name and different values are two findings',
        () {
      const other = 'z9y8x7w6v5u4t3s2r1';
      final f = findSharedIdentifiers(browserSnap(
          url: 'https://shop.test/',
          cookies: [cookie('_a', value: id), cookie('_a', value: other)],
          resources: [
            res('https://a.one.test/p?u=$id&v=$other'),
            res('https://b.two.test/p?u=$id&v=$other'),
          ]));
      expect(f.length, 2);
    });

    test('a long cookie name is cut in the title', () {
      final name = 'n' * 60;
      final f = findSharedIdentifiers(browserSnap(
          url: 'https://shop.test/',
          cookies: [cookie(name, value: id)],
          resources: [
            res('https://a.one.test/p?u=$id'),
            res('https://b.two.test/p?u=$id'),
          ]));
      expect(f.single.title.contains('${'n' * 40}…'), isTrue);
      expect(f.single.title.contains('n' * 41), isFalse);
    });

    test('one other party is not sharing', () {
      final f = findSharedIdentifiers(browserSnap(
          url: 'https://shop.test/',
          cookies: [cookie('_uid', value: id)],
          resources: [res('https://sync.ads-a.test/p?u=$id')]));
      expect(f, isEmpty);
    });

    test('no cookies or resources observed gives no findings', () {
      expect(findSharedIdentifiers(browserSnap(cookies: null)), isEmpty);
      expect(findSharedIdentifiers(browserSnap(resources: null)), isEmpty);
    });
  });

  group('missing integrity', () {
    TechniqueFinding? judge(String html) => findMissingIntegrity(
        extractMetadataSync(html, 'https://shop.test/page'));

    test('is counted on third-party files only', () {
      const html = '''
<html><head>
<script src="/own.js"></script>
<script src="https://cdn.one.test/a.js" integrity="sha384-abc" crossorigin></script>
<script src="https://cdn.one.test/b.js"></script>
<link rel="stylesheet" href="https://cdn.two.test/c.css">
</head></html>''';
      final m = extractMetadataSync(html, 'https://shop.test/page');
      expect(m['subresourceIntegrity'], {
        'thirdParty': 3,
        'without': [
          'https://cdn.one.test/b.js',
          'https://cdn.two.test/c.css',
        ],
      });
      final f = findMissingIntegrity(m)!;
      expect(f.id, 'no-sri');
      expect(f.severity, TechniqueSeverity.low);
      expect(f.title,
          '2 of 3 third-party scripts and stylesheets have no integrity check');
      expect(f.detail, contains('cdn.one.test'));
    });

    test('a sibling subdomain is the same site', () {
      expect(
          judge('<script src="https://static.shop.test/a.js"></script>'), isNull);
    });

    test('nothing without integrity gives no finding', () {
      expect(
          judge('<script src="https://c.test/a.js" integrity="sha256-x"></script>'),
          isNull);
      expect(findMissingIntegrity(const {}), isNull);
    });
  });

  group('deriveTechniques', () {
    const id = 'a1b2c3d4e5f6a7b8c9';
    final pageWithSharedId = inspection(
        browser: browserSnap(
            url: 'https://shop.test/',
            cookies: [cookie('_uid', value: id)],
            resources: [
              res('https://sync.ads-a.test/p?u=$id'),
              res('https://px.ads-b.test/m/$id'),
            ]));

    test('without a fresh load the call checks say so, data checks still run',
        () {
      final m = deriveTechniques(pageWithSharedId,
          cloaking: const Pending(), metadata: null);
      expect(m.callChecksNote, 'Run a fresh load to check');
      expect(m.callChecksCanRun, isTrue);
      expect(m.findings.map((f) => f.id), ['id-sharing']);
    });

    test('unsupported platform: note without a button, data checks still run',
        () {
      final m = deriveTechniques(
          pageWithSharedId.copyWith(
              freshTechniques: const Unavailable(
                  UnavailableReason.unsupportedPlatform,
                  'Not supported on this platform')),
          cloaking: const Pending(),
          metadata: null);
      expect(m.callChecksNote, 'Not supported on this platform');
      expect(m.callChecksCanRun, isFalse);
      expect(m.findings.map((f) => f.id), ['id-sharing']);
    });

    test('a running fresh load has a note and no button', () {
      final m = deriveTechniques(
          pageWithSharedId.copyWith(freshTechniques: const Pending()),
          cloaking: const Pending(),
          metadata: null);
      expect(m.callChecksNote, isNotNull);
      expect(m.callChecksCanRun, isFalse);
    });

    test('a failed fresh load can be run again', () {
      final m = deriveTechniques(
          pageWithSharedId.copyWith(freshTechniques: const Failed('boom')),
          cloaking: const Pending(),
          metadata: null);
      expect(m.callChecksNote, contains('boom'));
      expect(m.callChecksCanRun, isTrue);
    });

    test('a local file cannot run a fresh load', () {
      final m = deriveTechniques(inspection(file: fileSnap('<html></html>')),
          cloaking: const Unavailable(UnavailableReason.notApplicable),
          metadata: const {});
      expect(m.callChecksCanRun, isFalse);
    });

    test('findings are ordered by severity, then rule order', () {
      final m = deriveTechniques(
          pageWithSharedId.copyWith(
              freshTechniques: Present(
                  signals(battery: 1, clipboardRead: 1, distinctFonts: 60),
                  source: DataSource.browser)),
          cloaking: const Pending(),
          metadata: {
            'subresourceIntegrity': {
              'thirdParty': 1,
              'without': ['https://cdn.one.test/a.js']
            }
          });
      expect(m.callChecksNote, isNull);
      expect(m.findings.map((f) => f.id),
          ['clipboard-read', 'font-probing', 'id-sharing', 'battery', 'no-sri']);
    });

    test('cloaked hostnames are findings; failed lookups are not checked', () {
      final m = deriveTechniques(pageWithSharedId,
          cloaking: Present(const CloakingResult(
              aliases: [
                CnameAlias(
                    'metrics.shop.test', 'shop.sc.omtrdc.net', 'Adobe')
              ],
              checked: ['metrics.shop.test'],
              notChecked: ['x.shop.test']),
              source: DataSource.server),
          metadata: null);
      expect(m.findings.map((f) => f.id), contains('cname-cloaking'));
      final f = m.findings.firstWhere((f) => f.id == 'cname-cloaking');
      expect(f.title, contains('metrics.shop.test'));
      expect(f.detail, contains('shop.sc.omtrdc.net'));
      expect(m.notChecked, ['x.shop.test']);
    });

    test('a failed cloaking check is listed, not silently clean', () {
      final m = deriveTechniques(pageWithSharedId,
          cloaking: const Failed('dns down'), metadata: null);
      expect(m.cloakingNote, contains('dns down'));
    });

    test('without cookies the shared identifiers are not checked, not clean',
        () {
      final p = inspection(
              browser: browserSnap(url: 'https://shop.test/', cookies: null))
          .copyWith(
              freshTechniques: Present(signals(), source: DataSource.browser));
      final m = deriveTechniques(p,
          cloaking: const Present(CloakingResult(), source: DataSource.server),
          metadata: const {});
      expect(m.sharedIdsNote,
          'Cookies not available: shared identifiers not checked.');
      expect(m.complete, isFalse);
    });

    test('not supported here: the note says so, no button', () {
      final m = deriveTechniques(pageWithSharedId,
          cloaking: const Pending(),
          metadata: null,
          freshLoadSupported: false);
      expect(m.callChecksNote, 'Not supported on this platform');
      expect(m.callChecksCanRun, isFalse);
      expect(m.findings.map((f) => f.id), ['id-sharing']);
    });

    test('a measured load is shown even where a fresh load is unsupported',
        () {
      final m = deriveTechniques(
          pageWithSharedId.copyWith(
              freshTechniques:
                  Present(signals(battery: 1), source: DataSource.browser)),
          cloaking: const Pending(),
          metadata: null,
          freshLoadSupported: false);
      expect(m.callChecksNote, isNull);
      expect(m.findings.map((f) => f.id), contains('battery'));
    });

    test('complete only when every check ran', () {
      final ran = pageWithSharedId.copyWith(
          freshTechniques:
              Present(signals(), source: DataSource.browser));
      expect(
          deriveTechniques(ran,
                  cloaking: const Present(CloakingResult(), source: DataSource.server), metadata: const {})
              .complete,
          isTrue);
      expect(
          deriveTechniques(ran,
                  cloaking: const Pending(), metadata: const {})
              .complete,
          isFalse);
      expect(
          deriveTechniques(pageWithSharedId,
                  cloaking: const Present(CloakingResult(), source: DataSource.server), metadata: const {})
              .complete,
          isFalse);
    });
  });
}
