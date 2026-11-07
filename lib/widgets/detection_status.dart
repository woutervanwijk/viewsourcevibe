import 'package:flutter/material.dart';
import 'package:view_source_vibe/services/derive/detections_view.dart';

/// What a Services/Privacy tab shows when it has no findings: scanning,
/// scan failed, nothing could be read, or (only when the scan finished and
/// read something) "none found" with the sources it checked.
class DetectionEmptyState extends StatelessWidget {
  final DetectionsView view;
  final IconData icon;
  final String noneTitle;
  final String noneText;

  const DetectionEmptyState({
    super.key,
    required this.view,
    required this.icon,
    required this.noneTitle,
    required this.noneText,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12);
    final Widget lead;
    final String title;
    String? text;
    var isError = false;
    if (view.failure != null) {
      lead = Icon(Icons.error_outline, size: 64, color: scheme.error);
      title = 'Scan failed';
      text = view.failure;
      isError = true;
    } else if (view.scanning) {
      lead = const CircularProgressIndicator();
      title = 'Scanning…';
    } else if (!view.sources.anythingChecked) {
      lead = Icon(icon, size: 64, color: scheme.outlineVariant);
      title = 'Nothing to check';
    } else {
      lead = Icon(icon, size: 64, color: scheme.outlineVariant);
      title = noneTitle;
      text = noneText;
    }
    final line = view.sources.line;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            lead,
            const SizedBox(height: 16),
            Text(title),
            if (text != null) ...[
              const SizedBox(height: 8),
              Text(text,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: isError ? scheme.error : Colors.grey)),
            ],
            if (line.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(line, textAlign: TextAlign.center, style: muted),
            ],
          ],
        ),
      ),
    );
  }
}

/// A line above or below a list of findings: still scanning, scan failed
/// (only part of the findings are shown), and the sources that were checked.
class DetectionNote extends StatelessWidget {
  final DetectionsView view;
  const DetectionNote({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = view.sources.line;
    final failed = view.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (failed != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
                'Scan of the page source failed ($failed); only requests and cookies are listed.',
                style: TextStyle(color: scheme.error, fontSize: 12)),
          )
        else if (view.scanning)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('Still scanning; more findings may follow',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ]),
          ),
        if (line.isNotEmpty)
          Text(line,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }
}
