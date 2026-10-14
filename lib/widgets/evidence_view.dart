import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/detection_evidence.dart';
import 'package:view_source_vibe/services/html_service.dart';

IconData _iconFor(EvidenceKind kind) => switch (kind) {
      EvidenceKind.html => Icons.code,
      EvidenceKind.request => Icons.swap_horiz,
      EvidenceKind.cookie => Icons.cookie_outlined,
      EvidenceKind.header => Icons.list_alt,
      EvidenceKind.hint => Icons.link,
    };

/// Rows explaining where a detection came from. HTML lines jump to Source.
class EvidenceList extends StatelessWidget {
  final List<DetectionEvidence> evidence;

  /// Show at most this many rows, plus a "+N more" note; null shows all.
  final int? max;
  final bool compact;

  const EvidenceList(
      {super.key, required this.evidence, this.max, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final shown = max == null ? evidence : evidence.take(max!).toList();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in shown)
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 2 : 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(item.kind),
                    size: compact ? 14 : 18, color: muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: compact ? 1 : null,
                          overflow: compact ? TextOverflow.ellipsis : null,
                          style: TextStyle(
                              fontSize: compact ? 11 : 13,
                              fontWeight: FontWeight.w600)),
                      if (item.detail != null)
                        Text(item.detail!,
                            maxLines: compact ? 1 : 6,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: compact ? 10 : 12,
                                fontFamily: 'monospace',
                                color: muted)),
                    ],
                  ),
                ),
                if (item.line != null && !compact)
                  TextButton(
                    onPressed: () {
                      final htmlService = context.read<HtmlService>();
                      Navigator.of(context).maybePop();
                      htmlService.revealSourceLine(item.line!);
                    },
                    child: Text('Line ${item.line}'),
                  ),
              ],
            ),
          ),
        if (shown.length < evidence.length)
          Text('+${evidence.length - shown.length} more',
              style: TextStyle(fontSize: 11, color: muted)),
      ],
    );
  }
}

/// Bottom sheet listing every source for one detection.
void showEvidenceSheet(
    BuildContext context, String title, List<DetectionEvidence> evidence,
    {Widget? leading, String? description}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (leading != null) ...[leading, const SizedBox(width: 10)],
                Expanded(
                  child: Text(title,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ]),
              if (description != null) ...[
                const SizedBox(height: 6),
                Text(description),
              ],
              const SizedBox(height: 4),
              Text(
                  evidence.isEmpty
                      ? 'No source details recorded for this detection.'
                      : 'Detected from ${evidence.length} source${evidence.length == 1 ? '' : 's'}:',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              EvidenceList(evidence: evidence),
            ],
          ),
        ),
      ),
    ),
  );
}
