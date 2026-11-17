import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import 'observed.dart';

/// [PageInspection.freshTechniques] before a fresh load was asked for. Not
/// measured is not clean: it is never shown as "none found".
const kTechniquesNotMeasured = Unavailable<TechniqueSignals>(
    UnavailableReason.notApplicable, 'Run a fresh load to check');

/// A canvas the page read back (toDataURL / toBlob), with what was drawn on
/// its 2d context. Counts only: no pixels, no text.
class CanvasRead {
  final int width, height, chars, colors, reads;
  final String script;
  const CanvasRead({
    required this.width,
    required this.height,
    required this.chars,
    required this.colors,
    required this.reads,
    required this.script,
  });
}

/// A permission or similar prompt asked for by the page.
class PromptCall {
  final String api;

  /// Time since the page started loading.
  final Duration at;

  /// Whether the user had clicked or typed recently; null when unknown.
  final bool? userActive;
  final String script;
  const PromptCall({
    required this.api,
    required this.at,
    required this.userActive,
    required this.script,
  });
}

/// What the instrumentation script saw the page call during a fresh load.
class TechniqueSignals {
  final List<CanvasRead> canvas;
  final int fontMeasureCalls, distinctFonts;
  final bool webglDebugInfo;
  final int audioOffline, audioOscillators, audioRendered;
  final int rtcConnections, rtcDataChannels, rtcOffers, rtcGetUserMedia;
  final int enumerateDevices, battery, clipboardRead;
  final List<PromptCall> prompts;

  /// Signal group (`fonts`, `webgl`, `audio`, `rtc`) to the script URL that
  /// made the first call; '' when unknown.
  final Map<String, String> scripts;

  const TechniqueSignals({
    this.canvas = const [],
    this.fontMeasureCalls = 0,
    this.distinctFonts = 0,
    this.webglDebugInfo = false,
    this.audioOffline = 0,
    this.audioOscillators = 0,
    this.audioRendered = 0,
    this.rtcConnections = 0,
    this.rtcDataChannels = 0,
    this.rtcOffers = 0,
    this.rtcGetUserMedia = 0,
    this.enumerateDevices = 0,
    this.battery = 0,
    this.clipboardRead = 0,
    this.prompts = const [],
    this.scripts = const {},
  });
}

const _kReportUnreadable = 'The technique report could not be read';

int _int(Object? v) => v is num ? v.toInt() : 0;
String _str(Object? v) => v is String ? v : '';
Map<String, Object?> _map(Object? v) =>
    v is Map ? v.cast<String, Object?>() : const {};

/// Reads the JSON string returned by `window.__vsv_tech_report()`. No report
/// is Unavailable (the script did not run); a malformed one is Failed. Never
/// an empty, clean-looking value.
Observed<TechniqueSignals> parseTechniqueReport(Object? raw) {
  if (raw == null) {
    return const Unavailable(UnavailableReason.notExposedToPage,
        'The page gave no technique report');
  }
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) {
      debugPrint('Technique report had an unexpected shape');
      return const Failed(_kReportUnreadable);
    }
    final r = decoded.cast<String, Object?>();
    final fonts = _map(r['fonts']);
    final webgl = _map(r['webgl']);
    final audio = _map(r['audio']);
    final rtc = _map(r['rtc']);
    final canvas = <CanvasRead>[
      for (final c in (r['canvas'] is List ? r['canvas'] as List : const []))
        if (c is Map)
          CanvasRead(
            width: _int(c['w']),
            height: _int(c['h']),
            chars: _int(c['chars']),
            colors: _int(c['colors']),
            reads: _int(c['reads']),
            script: _str(c['script']),
          ),
    ];
    final prompts = <PromptCall>[
      for (final p in (r['prompts'] is List ? r['prompts'] as List : const []))
        if (p is Map)
          PromptCall(
            api: _str(p['api']),
            at: Duration(milliseconds: _int(p['atMs'])),
            userActive:
                p['userActive'] is bool ? p['userActive'] as bool : null,
            script: _str(p['script']),
          ),
    ];
    return Present(
        TechniqueSignals(
          canvas: canvas,
          fontMeasureCalls: _int(fonts['measureCalls']),
          distinctFonts: _int(fonts['distinctFonts']),
          webglDebugInfo: webgl['debugInfo'] == true,
          audioOffline: _int(audio['offline']),
          audioOscillators: _int(audio['oscillators']),
          audioRendered: _int(audio['rendered']),
          rtcConnections: _int(rtc['connections']),
          rtcDataChannels: _int(rtc['dataChannels']),
          rtcOffers: _int(rtc['offers']),
          rtcGetUserMedia: _int(rtc['getUserMedia']),
          enumerateDevices: _int(r['enumerateDevices']),
          battery: _int(r['battery']),
          clipboardRead: _int(r['clipboardRead']),
          prompts: prompts,
          scripts: {
            'fonts': _str(fonts['script']),
            'webgl': _str(webgl['script']),
            'audio': _str(audio['script']),
            'rtc': _str(rtc['script']),
          },
        ),
        source: DataSource.browser);
  } catch (e) {
    debugPrint('Technique report could not be read: $e');
    return const Failed(_kReportUnreadable);
  }
}
