import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/derive/techniques.dart';
import 'package:view_source_vibe/services/html_service.dart';

/// Suspicious techniques the page used (see [deriveTechniques]). Findings are
/// indications from what the page called, not proof of intent.
class TechniquesSection extends StatefulWidget {
  const TechniquesSection({super.key});

  @override
  State<TechniquesSection> createState() => _TechniquesSectionState();
}

class _TechniquesSectionState extends State<TechniquesSection> {
  late final HtmlService _service = context.read<HtmlService>();
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    // The hostname lookups run only while a view shows them. Not from build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _watching = true;
      _service.watchCloaking(true);
    });
  }

  @override
  void dispose() {
    if (_watching) _service.watchCloaking(false);
    super.dispose();
  }

  static Color _color(TechniqueSeverity s) => switch (s) {
        TechniqueSeverity.high => Colors.red,
        TechniqueSeverity.medium => Colors.orange,
        TechniqueSeverity.low => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    final model =
        context.select<HtmlService, TechniquesModel>((s) => s.techniquesView);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Techniques',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final f in model.findings) _FindingTile(finding: f),
        if (model.callChecksNote != null)
          Row(
            children: [
              Expanded(child: Text(model.callChecksNote!, style: muted)),
              if (model.callChecksCanRun)
                FilledButton.tonal(
                  onPressed: _service.measureFreshLoad,
                  child: const Text('Run fresh load'),
                ),
            ],
          ),
        if (model.sharedIdsNote != null)
          Text(model.sharedIdsNote!, style: muted),
        if (model.cloakingNote != null) Text(model.cloakingNote!, style: muted),
        if (model.notChecked.isNotEmpty)
          Text('Not checked (lookup failed): ${model.notChecked.join(', ')}',
              style: muted),
        if (model.findings.isEmpty && model.complete)
          const Text('No suspicious techniques seen by the checks that ran.'),
      ],
    );
  }
}

class _FindingTile extends StatelessWidget {
  final TechniqueFinding finding;
  const _FindingTile({required this.finding});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _TechniquesSectionState._color(finding.severity);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 10),
              child: Semantics(
                label: '${finding.severity.name} severity',
                child: Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(finding.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(finding.detail, style: const TextStyle(fontSize: 13)),
                  if (finding.scripts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      finding.hosts.join(', '),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
