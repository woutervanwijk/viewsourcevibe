// A score's colour (widgets) and its verdict text (models) come from one
// scale, so they cannot disagree at a boundary.
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_source_vibe/services/derive/score_band.dart';
import 'package:view_source_vibe/widgets/score_band_color.dart';

void main() {
  group('boundaries', () {
    final cases = {
      'security': (securityScale, 80, 50),
      'csp': (cspScale, 80, 50),
      'sovereignty': (sovereigntyScale, 80, 50),
      'cookies': (cookieScale, 75, 45),
    };
    for (final MapEntry(key: name, value: (scale, good, fair))
        in cases.entries) {
      test(name, () {
        expect(scale.band(100), ScoreBand.good);
        expect(scale.band(good), ScoreBand.good);
        expect(scale.band(good - 1), ScoreBand.fair);
        expect(scale.band(fair), ScoreBand.fair);
        expect(scale.band(fair - 1), ScoreBand.poor);
        expect(scale.band(0), ScoreBand.poor);
        expect(scale.band(null), isNull);
      });
    }
  });

  test('each band has its own colour; no score is grey', () {
    expect(bandColor(ScoreBand.good), Colors.green);
    expect(bandColor(ScoreBand.fair), Colors.orange);
    expect(bandColor(ScoreBand.poor), Colors.red);
    expect(bandColor(null), Colors.grey);
  });

  test('score cards take their colour from the shared scales', () {
    // A hard-coded "score >= 80" in a widget would drift from the model's
    // verdict the next time a threshold changes.
    final hardCoded = RegExp(r'\b(score|percentage)\s*>=\s*\d{2}\b');
    for (final path in [
      'lib/widgets/probe_views.dart',
      'lib/widgets/sovereignty_view.dart',
      'lib/services/sovereignty_service.dart',
      'lib/services/derive/cookies_view.dart',
      'lib/services/derive/security_audit.dart',
    ]) {
      final hits = hardCoded
          .allMatches(File(path).readAsStringSync())
          .map((m) => m.group(0))
          .toList();
      expect(hits, isEmpty, reason: '$path has its own thresholds: $hits');
    }
  });
}
