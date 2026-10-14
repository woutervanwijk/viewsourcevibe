import 'package:view_source_vibe/services/detection/engine.dart';

/// Technologies as `{category: names}` plus `{name Version: version}`.
Map<String, String> techSummary(Iterable<Detection> detections) {
  final tech = <String, String>{};
  for (final d in detections.where((d) => d.category.tech)) {
    final key = d.category.label;
    tech[key] = tech[key] == null ? d.name : '${tech[key]}, ${d.name}';
    if (d.version != null) tech['${d.name} Version'] = d.version!;
  }
  return tech;
}

Map<String, String> techOf(Map<String, dynamic> metadata) =>
    techSummary(Detection.listFrom(metadata['detections']));
