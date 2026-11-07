import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/probe_general.dart'
    show RedirectStep;
import 'package:view_source_vibe/services/derive/request_timeline.dart';
import 'package:view_source_vibe/services/html_service.dart';

class RequestTimelineView extends StatelessWidget {
  const RequestTimelineView({super.key});

  /// Counts builds (tests check that unrelated changes do not rebuild).
  @visibleForTesting
  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    final state = context
        .select<HtmlService, Observed<TimelineModel>>((s) => s.timelineView);
    switch (state) {
      case Pending<TimelineModel>():
        return const Center(child: CircularProgressIndicator());
      case Failed<TimelineModel>(:final error):
        return _message('Error: $error', error: true);
      case Unavailable<TimelineModel>(:final detail, :final reason):
        return _message(
            detail.isEmpty ? unavailableMessage(reason, detail) : detail);
      case Present<TimelineModel>(value: final model):
        return _buildModel(context, model);
    }
  }

  Widget _message(String text, {bool error = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: error ? Colors.red : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildModel(BuildContext context, TimelineModel m) {
    final rows = m.rows;
    return Scrollbar(
      child: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
        children: [
          _buildOverviewCard(context, m),
          if (m.redirects.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildRedirectChainCard(context, m.redirects),
          ],
          const SizedBox(height: 16),
          Text(
            'Resource Timeline',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          switch (rows) {
            Present<List<TimelineRow>>(value: final list) when list.isEmpty =>
              _buildNoteCard(
                  context, 'The browser reported no requests for this page.'),
            Present<List<TimelineRow>>(value: final list) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (m.note != null) ...[
                    _buildNoteCard(context, m.note!, warn: true),
                    const SizedBox(height: 12),
                  ],
                  if (list.any((r) => r.hasBar)) ...[
                    _buildTimelineMap(context,
                        list.where((r) => r.hasBar).toList(), m.timelineEnd),
                    const SizedBox(height: 16),
                  ],
                  _buildWaterfallDetail(context, list, m.timelineEnd),
                ],
              ),
            Pending<List<TimelineRow>>() => _buildNoteCard(
                context, 'Waiting for the browser to report its requests…',
                busy: true),
            Failed<List<TimelineRow>>(:final error) => _buildNoteCard(
                context, 'The requests could not be read: $error',
                error: true),
            Unavailable<List<TimelineRow>>(:final reason, :final detail) =>
              _buildNoteCard(context,
                  'No request timing: ${unavailableMessage(reason, detail)}'),
          },
        ],
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, TimelineModel m) {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Timeline',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (m.url != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                m.url!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricChip(context, Icons.http, m.appStatus),
                _buildMetricChip(
                    context, Icons.account_tree_outlined, m.resourcesLabel),
                _buildMetricChip(
                    context, Icons.download_outlined, m.transferLabel),
                if (m.decodedLabel != null)
                  _buildMetricChip(context, Icons.data_object, m.decodedLabel!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedirectChainCard(
    BuildContext context,
    List<RedirectStep> redirects,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alt_route,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Redirect Chain',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...redirects.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final redirect = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.orange.withValues(alpha: 0.16),
                      child: Text(
                        '$index',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            redirect.statusText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            redirect.from,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.arrow_downward, size: 13),
                              const SizedBox(width: 4),
                              Expanded(
                                child: SelectableText(
                                  redirect.to ?? 'no Location header',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineMap(
    BuildContext context,
    List<TimelineRow> resources,
    double timelineEnd,
  ) {
    final entries = _buildTimelineEntries(resources, timelineEnd);
    final height = (entries.length * 64.0 + 96).clamp(320.0, 2200.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTimelineLegend(context),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final laneWidth =
                    (constraints.maxWidth * 0.38).clamp(128.0, 210.0);
                final labelLeft = laneWidth + 18;

                return SizedBox(
                  height: height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TimelineMapPainter(
                            entries: entries,
                            laneWidth: laneWidth,
                            labelLeft: labelLeft,
                            colors: _timelineTypeColors,
                            axisColor:
                                Theme.of(context).colorScheme.outlineVariant,
                            textColor: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.56),
                          ),
                        ),
                      ),
                      ...entries.map(
                        (entry) => Positioned(
                          left: labelLeft + 8,
                          right: 0,
                          top: (entry.y - 24).clamp(8.0, height - 54),
                          child: _buildTimelineLabel(context, entry),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterfallDetail(
    BuildContext context,
    List<TimelineRow> resources,
    double timelineEnd,
  ) {
    final maxEnd = timelineEnd <= 0 ? 1.0 : timelineEnd;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Waterfall Detail',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...resources.take(60).map((resource) {
              final type = resource.type;
              final color = _typeColor(type);
              final start = resource.start;
              final duration = resource.duration;
              final hasBar = resource.hasBar;
              final left = hasBar ? (start! / maxEnd).clamp(0.0, 1.0) : 0.0;
              final width =
                  hasBar ? (duration! / maxEnd).clamp(0.01, 1.0 - left) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_typeIcon(type), color: color, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            resource.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            resource.timingLabel,
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    if (hasBar) ...[
                      const SizedBox(height: 5),
                      LayoutBuilder(builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            Positioned(
                              left: constraints.maxWidth * left,
                              width: (constraints.maxWidth * width)
                                  .clamp(2.0, constraints.maxWidth),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      resource.sizeLabel,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.58),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (resources.length > 60)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${resources.length - 60} more not shown',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineLegend(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _timelineTypes.map((type) {
        final color = _typeColor(type);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.26)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_typeIcon(type), color: color, size: 14),
              const SizedBox(width: 5),
              Text(
                type,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimelineLabel(BuildContext context, _TimelineEntry entry) {
    final color = _typeColor(entry.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_typeIcon(entry.type), color: color, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  entry.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${formatMs(entry.start)} start  |  ${formatMs(entry.duration)}  |  ${entry.sizeLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.66),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineEntry> _buildTimelineEntries(
    List<TimelineRow> resources,
    double timelineEnd,
  ) {
    const top = 34.0;
    final bottom = (resources.length * 64.0 + 96).clamp(320.0, 2200.0) - 34;
    final span = bottom - top;
    var previousY = top - 54;

    return resources.map((resource) {
      final start = resource.start!;
      final rawY = timelineEnd <= 0 ? top : top + (start / timelineEnd) * span;
      final y = rawY < previousY + 54 ? previousY + 54 : rawY;
      previousY = y;

      return _TimelineEntry(
        name: resource.url,
        shortName: resource.shortName,
        type: resource.type,
        start: start,
        duration: resource.duration!,
        y: y.clamp(top, bottom),
        sizeLabel: resource.sizeLabel,
      );
    }).toList();
  }

  Widget _buildMetricChip(
    BuildContext context,
    IconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, String text,
      {bool warn = false, bool error = false, bool busy = false}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: warn
                ? Colors.orange.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (busy) ...[
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: error
                          ? Colors.red
                          : warn
                              ? Colors.orange
                              : null,
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'script':
        return Icons.javascript;
      case 'style':
        return Icons.css;
      case 'image':
        return Icons.image_outlined;
      case 'font':
        return Icons.title;
      case 'fetch':
        return Icons.sync_alt;
      case 'document':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'script':
        return Colors.amber;
      case 'style':
        return Colors.purple;
      case 'image':
        return Colors.teal;
      case 'font':
        return Colors.indigo;
      case 'fetch':
        return Colors.blue;
      case 'document':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

const List<String> _timelineTypes = [
  'document',
  'style',
  'script',
  'image',
  'font',
  'fetch',
  'other',
];

const Map<String, Color> _timelineTypeColors = {
  'document': Colors.green,
  'style': Colors.purple,
  'script': Colors.amber,
  'image': Colors.teal,
  'font': Colors.indigo,
  'fetch': Colors.blue,
  'other': Colors.grey,
};

class _TimelineEntry {
  final String name;
  final String shortName;
  final String type;
  final double start;
  final double duration;
  final double y;
  final String sizeLabel;

  const _TimelineEntry({
    required this.name,
    required this.shortName,
    required this.type,
    required this.start,
    required this.duration,
    required this.y,
    required this.sizeLabel,
  });
}

class _TimelineMapPainter extends CustomPainter {
  final List<_TimelineEntry> entries;
  final double laneWidth;
  final double labelLeft;
  final Map<String, Color> colors;
  final Color axisColor;
  final Color textColor;

  const _TimelineMapPainter({
    required this.entries,
    required this.laneWidth,
    required this.labelLeft,
    required this.colors,
    required this.axisColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const top = 18.0;
    final bottom = size.height - 18;
    final laneGap = laneWidth / (_timelineTypes.length + 1);
    final laneXs = <String, double>{
      for (var i = 0; i < _timelineTypes.length; i++)
        _timelineTypes[i]: laneGap * (i + 1),
    };

    final baselinePaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(labelLeft - 6, top),
      Offset(labelLeft - 6, bottom),
      baselinePaint,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    for (final type in _timelineTypes) {
      final x = laneXs[type]!;
      final color = colors[type] ?? Colors.grey;
      final lanePaint = Paint()
        ..color = color.withValues(alpha: 0.42)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x, top), Offset(x, bottom), lanePaint);

      textPainter.text = TextSpan(
        text: type,
        style: TextStyle(
          color: color.withValues(alpha: 0.85),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      canvas.save();
      canvas.translate(x - 5, 0);
      canvas.rotate(-1.5708);
      textPainter.paint(canvas, const Offset(-44, 0));
      canvas.restore();
    }

    for (final entry in entries) {
      final x = laneXs[entry.type] ?? laneXs['other']!;
      final color = colors[entry.type] ?? Colors.grey;
      final y = entry.y.clamp(top + 18, bottom - 18);
      final durationHeight =
          entry.duration <= 0 ? 8.0 : (entry.duration / 18).clamp(8.0, 46.0);

      final durationPaint = Paint()
        ..color = color
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, (y + durationHeight).clamp(top, bottom)),
        durationPaint,
      );

      final connectorPaint = Paint()
        ..color = color.withValues(alpha: 0.72)
        ..strokeWidth = 1.4;
      canvas.drawLine(Offset(x, y), Offset(labelLeft, y), connectorPaint);

      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(x, y), 4.5, dotPaint);
      canvas.drawCircle(
        Offset(labelLeft, y),
        2.5,
        Paint()..color = color.withValues(alpha: 0.85),
      );
    }

    final startLabel = TextPainter(
      text: TextSpan(
        text: 'start',
        style: TextStyle(color: textColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    startLabel.paint(canvas, Offset(labelLeft, top - 14));

    final endLabel = TextPainter(
      text: TextSpan(
        text: 'later',
        style: TextStyle(color: textColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    endLabel.paint(canvas, Offset(labelLeft, bottom + 3));
  }

  @override
  bool shouldRepaint(covariant _TimelineMapPainter oldDelegate) {
    return entries != oldDelegate.entries ||
        laneWidth != oldDelegate.laneWidth ||
        labelLeft != oldDelegate.labelLeft ||
        axisColor != oldDelegate.axisColor ||
        textColor != oldDelegate.textColor;
  }
}
