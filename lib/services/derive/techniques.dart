import '../../models/inspection/observed.dart';
import '../../models/inspection/technique_signals.dart';

// Thresholds. Canvas and font numbers follow the detection heuristics of
// Englehardt and Narayanan, "Online Tracking: A 1-million-site Measurement
// and Analysis" (ACM CCS 2016), section 6.1 (canvas: at least 16x16 px, text
// with two colours or ten distinct characters, read back) and section 6.2
// (fonts: at least 50 distinct font values measured). The rest are this
// app's own choices.
const int kCanvasMinSide = 16;
const int kCanvasMinChars = 10;
const int kCanvasMinColors = 2;
const int kFontProbeMinFonts = 50;

enum TechniqueSeverity { high, medium, low }

/// An indication from what a page called, not proof of intent.
class TechniqueFinding {
  final String id;
  final TechniqueSeverity severity;
  final String title;
  final String detail;

  /// Script URLs involved (empty when the script could not be told).
  final List<String> scripts;
  final DataSource source;

  const TechniqueFinding({
    required this.id,
    required this.severity,
    required this.title,
    required this.detail,
    this.scripts = const [],
    this.source = DataSource.browser,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'severity': severity.name,
        'title': title,
        'detail': detail,
        'scripts': scripts,
        'source': source.name,
      };
}

List<String> _scripts(Iterable<String> urls) => {
      for (final u in urls)
        if (u.isNotEmpty) u
    }.toList();

/// Rules that turn recorded calls into findings. No findings means nothing of
/// this was seen in the fresh load; the caller decides when it was not measured.
List<TechniqueFinding> judgeSignals(TechniqueSignals s) {
  final out = <TechniqueFinding>[];

  final fp = [
    for (final c in s.canvas)
      if (c.width >= kCanvasMinSide &&
          c.height >= kCanvasMinSide &&
          c.reads >= 1 &&
          (c.chars >= kCanvasMinChars || c.colors >= kCanvasMinColors))
        c
  ];
  if (fp.isNotEmpty) {
    out.add(TechniqueFinding(
      id: 'canvas-fingerprint',
      severity: TechniqueSeverity.high,
      title: 'Reads back a canvas it drew text on (canvas fingerprinting)',
      detail: 'The page drew text on a canvas and read the pixels back. '
          'Rendering differs slightly between devices, so this can tell '
          'visitors apart. Charts and image editors do not draw text this way.',
      scripts: _scripts(fp.map((c) => c.script)),
    ));
  }
  if (s.distinctFonts >= kFontProbeMinFonts) {
    out.add(TechniqueFinding(
      id: 'font-probing',
      severity: TechniqueSeverity.medium,
      title: 'Measures text in ${s.distinctFonts} different fonts '
          '(font probing)',
      detail: 'Which fonts are installed differs per device, so measuring '
          'text in many fonts can tell visitors apart.',
      scripts: _scripts([s.scripts['fonts'] ?? '']),
    ));
  }
  if (s.webglDebugInfo) {
    out.add(TechniqueFinding(
      id: 'webgl-fingerprint',
      severity: TechniqueSeverity.medium,
      title: "Reads the graphics card's vendor and model",
      detail: 'The page asked WebGL for the unmasked renderer, which names '
          'the graphics hardware.',
      scripts: _scripts([s.scripts['webgl'] ?? '']),
    ));
  }
  if (s.audioOffline >= 1 && s.audioOscillators >= 1 && s.audioRendered >= 1) {
    out.add(TechniqueFinding(
      id: 'audio-fingerprint',
      severity: TechniqueSeverity.high,
      title: 'Renders a silent audio signal and reads it back '
          '(audio fingerprinting)',
      detail: 'An offline audio context rendered an oscillator without '
          'playing it. The result differs slightly between devices.',
      scripts: _scripts([s.scripts['audio'] ?? '']),
    ));
  }
  if (s.rtcConnections >= 1 &&
      (s.rtcDataChannels >= 1 || s.rtcOffers >= 1) &&
      s.rtcGetUserMedia == 0) {
    out.add(TechniqueFinding(
      id: 'webrtc-probe',
      severity: TechniqueSeverity.medium,
      title: 'Opens a WebRTC connection without a call '
          '(can reveal local addresses)',
      detail: 'A peer connection was created and an offer or data channel '
          'started, but no camera or microphone was requested.',
      scripts: _scripts([s.scripts['rtc'] ?? '']),
    ));
  }
  if (s.enumerateDevices >= 1) {
    out.add(const TechniqueFinding(
      id: 'device-enumeration',
      severity: TechniqueSeverity.low,
      title: 'Lists cameras and microphones',
      detail: 'The page asked which media devices are connected.',
    ));
  }
  if (s.battery >= 1) {
    out.add(const TechniqueFinding(
      id: 'battery',
      severity: TechniqueSeverity.low,
      title: 'Reads the battery status',
      detail: 'The page asked for the battery level or charging state.',
    ));
  }
  if (s.clipboardRead >= 1) {
    out.add(const TechniqueFinding(
      id: 'clipboard-read',
      severity: TechniqueSeverity.high,
      title: 'Reads the clipboard',
      detail: 'The page tried to read what you copied last.',
    ));
  }
  for (final p in s.prompts) {
    if (p.userActive != false) continue;
    out.add(TechniqueFinding(
      id: 'prompt-on-load',
      severity: TechniqueSeverity.medium,
      title: 'Asks for ${p.api} without a click, '
          '${p.at.inSeconds} s after loading',
      detail: 'The request came while you had not clicked or typed.',
      scripts: _scripts([p.script]),
    ));
  }
  return out;
}
