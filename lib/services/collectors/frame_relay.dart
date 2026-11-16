import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'collector_world.dart';

const _maxFrameReport = 256 * 1024;

/// The script that hands an iframe's report to the top frame's collector, or
/// null when [args] (what the frame passed to the `vsvFrame` handler) is not
/// a well-formed, reasonably sized report. Page-controlled input: the JSON
/// encoding is what makes it safe to embed in a script.
String? frameRelayScript(List<dynamic> args) {
  if (args.length != 1) return null;
  final report = args.first;
  if (report is! Map || report['__vsv_frame'] != 1) return null;
  final String json;
  try {
    json = jsonEncode(report);
  } catch (_) {
    return null;
  }
  if (json.length > _maxFrameReport) return null;
  return 'window.__vsv_frameIn($json)';
}

/// Handler body for `vsvFrame`: runs the relay script in the collector's
/// world. Invalid reports and evaluation errors are ignored.
dynamic relayFrameReport(
    InAppWebViewController controller, List<dynamic> args) {
  final script = frameRelayScript(args);
  if (script != null) {
    controller
        .evaluateJavascript(
            source: script, contentWorld: collectorWorld(defaultTargetPlatform))
        .ignore();
  }
  return null;
}
