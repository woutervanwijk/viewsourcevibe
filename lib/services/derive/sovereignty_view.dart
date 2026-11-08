import '../jurisdiction.dart';
import '../sovereignty_service.dart';

class PillarLine {
  final Pillar pillar;
  final String name;

  /// "13/25", or "not verifiable" when no check of the pillar could be
  /// verified.
  final String label;

  /// 0..1; null when the pillar could not be verified (no bar is drawn).
  final double? fraction;

  const PillarLine(this.pillar, this.name, this.label, this.fraction);
}

class SovereigntySummary {
  /// 0..100 over the verified pillars; null when nothing was verifiable.
  final int? score;
  final String? grade;

  /// One honest sentence about where the requests go.
  final String headline;

  /// Share (0..1) of the requests whose company's jurisdiction is unknown.
  final double unknownShare;
  final List<PillarLine> pillars;

  const SovereigntySummary({
    required this.score,
    required this.grade,
    required this.headline,
    required this.unknownShare,
    required this.pillars,
  });
}

String _pct(double share) => '${(share * 100).round()}%';

/// Score, pillar lines and the headline for a report. Unknown stays unknown:
/// no score without a verified pillar, and "all requests stay" is only said
/// when every request could be attributed.
SovereigntySummary summarizeSovereignty(SovereigntyReport r) {
  final relations = r.relationShare();
  final unknown = relations[Relation.unknown] ?? 0;
  final outside =
      (relations[Relation.adequate] ?? 0) + (relations[Relation.foreign] ?? 0);
  final home = jurisdictionLabel(r.home);

  final String headline;
  if (r.hosts.isEmpty) {
    headline = 'No requests to analyse.';
  } else if (unknown >= 1) {
    headline =
        'The jurisdiction of the companies behind the requests could not be determined.';
  } else if (outside == 0 && unknown == 0) {
    headline =
        "All requests stay with companies in the site's jurisdiction ($home)";
  } else if (outside == 0) {
    headline =
        "No request is known to go outside the site's jurisdiction ($home); "
        '${_pct(unknown)} of requests could not be attributed.';
  } else {
    headline =
        "${_pct(outside)} of requests go to companies outside the site's jurisdiction ($home)"
        '${unknown > 0 ? '; ${_pct(unknown)} of requests could not be attributed' : ''}';
  }

  return SovereigntySummary(
    score: r.score,
    grade: r.grade,
    headline: headline,
    unknownShare: unknown,
    pillars: [
      for (final p in Pillar.values)
        () {
          final s = r.pillarScore(p);
          return PillarLine(
            p,
            pillarLabels[p]!,
            s == null ? 'not verifiable' : '${s.round()}/${pillarMax[p]}',
            s == null ? null : s / pillarMax[p]!,
          );
        }(),
    ],
  );
}
