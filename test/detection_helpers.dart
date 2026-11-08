import 'package:view_source_vibe/services/metadata_parser.dart';
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

/// Metadata plus the source scan under `detections` (the metadata isolate no
/// longer scans for detections).
Future<Map<String, dynamic>> extractMetadataWithDetections(
    String html, String baseUrl,
    {Map<String, String>? headers}) async {
  final m = await extractMetadataInIsolate(html, baseUrl, headers: headers);
  return {
    ...m,
    'detections': [
      for (final d
          in scanSource(html: html, headers: headers, pageUrl: baseUrl))
        d.toMap()
    ],
  };
}
