import 'package:flutter/material.dart';
import 'package:view_source_vibe/services/derive/score_band.dart';

/// The colour of a score card: the same band as the model's verdict text.
Color bandColor(ScoreBand? band) => switch (band) {
      ScoreBand.good => Colors.green,
      ScoreBand.fair => Colors.orange,
      ScoreBand.poor => Colors.red,
      null => Colors.grey,
    };
