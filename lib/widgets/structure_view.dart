import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/observed_text.dart';
import 'package:view_source_vibe/services/derive/structure_view.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/widgets/structure_painter.dart';

/// The Structure tab: a wireframe of the rendered page, coloured by who owns
/// each box or by what it is, plus the heading outline. Everything comes from
/// [HtmlService.structureView].
class StructureView extends StatefulWidget {
  const StructureView({super.key});

  @override
  State<StructureView> createState() => _StructureViewState();
}

class _StructureViewState extends State<StructureView> {
  StructureColoring _coloring = StructureColoring.owner;

  @override
  Widget build(BuildContext context) {
    final state = context
        .select<HtmlService, Observed<StructureModel>>((s) => s.structureView);
    final hasBrowser = context
        .select<HtmlService, bool>((s) => s.store.current.target is UrlTarget);
    return switch (state) {
      Pending<StructureModel>() => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('Measuring the page…',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      Present<StructureModel>(:final value) => _model(context, value),
      _ => _unknown(context, state, hasBrowser),
    };
  }

  Widget _unknown(
      BuildContext context, Observed<StructureModel> state, bool hasBrowser) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_outlined,
                size: 64, color: scheme.outlineVariant),
            const SizedBox(height: 16),
            Text(unknownText(state),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: state is Failed ? scheme.error : scheme.outline)),
            if (hasBrowser) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.read<HtmlService>().collectLayout(),
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _model(BuildContext context, StructureModel model) {
    final scheme = Theme.of(context).colorScheme;
    final palette = StructurePalette(scheme);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in model.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.outline),
                  const SizedBox(width: 8),
                  Expanded(child: Text(note)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<StructureColoring>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: StructureColoring.owner, label: Text('Owner')),
                    ButtonSegment(
                        value: StructureColoring.element,
                        label: Text('Element')),
                  ],
                  selected: {_coloring},
                  onSelectionChanged: (s) =>
                      setState(() => _coloring = s.first),
                ),
              ),
              IconButton(
                tooltip: 'Measure again',
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<HtmlService>().collectLayout(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final (label, color) in palette.legend(_coloring))
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.55),
                      border: Border.all(color: scheme.outline),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ]),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final scale = wireframeScale(model.layout, constraints.maxWidth);
            return GestureDetector(
              onTapUp: (d) => _openDetails(
                  context,
                  blockAt(model, d.localPosition.dx / scale,
                      d.localPosition.dy / scale)),
              child: CustomPaint(
                key: const Key('structure-wireframe'),
                size: Size(
                    model.layout.width * scale, model.layout.height * scale),
                painter: StructurePainter(
                    model: model,
                    scale: scale,
                    coloring: _coloring,
                    scheme: scheme),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text('Headings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (model.headings.isEmpty)
            const Text('No headings.')
          else
            for (final h in model.headings)
              Padding(
                padding: EdgeInsets.only(left: (h.level - 1) * 16.0, top: 2),
                child: Text(h.text.isEmpty ? '(empty h${h.level})' : h.text),
              ),
        ],
      ),
    );
  }

  void _openDetails(BuildContext context, StructureBlock? s) {
    if (s == null) return;
    final service = context.read<HtmlService>();
    final b = s.block;
    final line = b.id.isEmpty ? null : service.sourceLineOfId(b.id);
    String n(double v) => v.round().toString();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.label, style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('${n(b.width)} × ${n(b.height)} px at '
                  '(${n(b.x)}, ${n(b.y)})'),
              Text('Kind: ${b.kind.name}'),
              Text('Owner: ${s.owner.name}'),
              if (s.service != null) Text('Service: ${s.service}'),
              if (b.src.isNotEmpty) Text('Source: ${b.src}'),
              Text('Contains ${b.descendants} elements'),
              if (b.fixed) const Text('fixed'),
              if (line != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    service.revealSourceLine(line);
                  },
                  child: const Text('Show in source'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
