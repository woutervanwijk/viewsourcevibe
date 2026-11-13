/// One place for the thresholds that turn a 0–100 score into good / fair /
/// poor. The models use them for their verdict text and the widgets for the
/// colour, so a score never reads "Good" in a red card.
enum ScoreBand { good, fair, poor }

class ScoreScale {
  /// Lowest score that is [ScoreBand.good].
  final int good;

  /// Lowest score that is [ScoreBand.fair].
  final int fair;

  const ScoreScale({required this.good, required this.fair});

  /// The band of [score]; null when there is no score.
  ScoreBand? band(int? score) => score == null
      ? null
      : score >= good
          ? ScoreBand.good
          : score >= fair
              ? ScoreBand.fair
              : ScoreBand.poor;
}

/// Security headers score (share of passing checks).
const securityScale = ScoreScale(good: 80, fair: 50);

/// Content-Security-Policy score.
const cspScale = ScoreScale(good: 80, fair: 50);

/// Sovereignty score ("Good" / "Fair" / "Poor").
const sovereigntyScale = ScoreScale(good: 80, fair: 50);

/// Cookie Privacy Lens score (low / moderate / heavy tracking pressure).
const cookieScale = ScoreScale(good: 75, fair: 45);
