import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/models/inspection/page_layout.dart';
import 'package:view_source_vibe/models/inspection/page_inspection.dart';
import 'package:view_source_vibe/services/derive/dom_tree.dart';
import 'package:view_source_vibe/services/derive/observed_text.dart';
import 'package:view_source_vibe/services/derive/structure_view.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/screenshot_stitch.dart';
import 'package:view_source_vibe/widgets/dom_tree_view.dart';
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

  /// The page's screenshots, decoded, drawn behind the wireframe: one tile
  /// per screen of the scroll-through capture, or the top-of-page shot as a
  /// single tile at 0 until that capture is done.
  List<(ui.Image, double)> _tiles = const [];

  /// CSS width the decoded [_tiles] cover; null for the top-of-page shot
  /// (the painter then uses the measured viewport width).
  double? _tilesCssWidth;

  /// What the tiles are (being) decoded from: the [PageShotTiles] or the
  /// top-of-page shot's bytes. A newer source makes an older decode drop.
  Object? _tilesSource;

  /// Whether the selected source is the full-page capture. Each tile carries
  /// its own page offset, so this only reports which one is shown.
  bool _tilesFullPage = false;

  /// Decoded pixels across all tiles, at most: a long page has up to 50
  /// tiles, each decoded only as wide as this budget allows (~100 MB RGBA).
  static const _tilePixelBudget = 24000000;

  @override
  void dispose() {
    _disposeTiles(_tiles);
    super.dispose();
  }

  static void _disposeTiles(List<(ui.Image, double)> tiles) {
    for (final (image, _) in tiles) {
      image.dispose();
    }
  }

  /// Decodes [shots] into [_tiles], replacing the old ones. Each is decoded
  /// at most as wide as the wireframe can show it sharp (2x its max width)
  /// and as the pixel budget across all tiles allows; never upscaled.
  Future<void> _loadTiles(Object source, List<(Uint8List, double)> shots,
      double? cssWidth) async {
    final out = <(ui.Image, double)>[];
    try {
      for (final (shot, cssY) in shots) {
        final buffer = await ui.ImmutableBuffer.fromUint8List(shot);
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        final w = descriptor.width, h = descriptor.height;
        final budgetWidth = w > 0 && h > 0
            ? math.sqrt(_tilePixelBudget * w / (shots.length * h))
            : 0.0;
        final maxWidth =
            math.min(2 * kMaxWireframeWidth, budgetWidth).floor();
        final codec = await descriptor.instantiateCodec(
            targetWidth: maxWidth > 0 && w > maxWidth ? maxWidth : null);
        final frame = await codec.getNextFrame();
        codec.dispose();
        descriptor.dispose();
        buffer.dispose();
        out.add((frame.image, cssY));
        if (!mounted || !identical(source, _tilesSource)) break;
      }
    } catch (_) {
      // A shot that does not decode: draw what did decode (or nothing).
    }
    if (!mounted || !identical(source, _tilesSource)) {
      _disposeTiles(out);
      return;
    }
    setState(() {
      _disposeTiles(_tiles);
      _tiles = out;
      _tilesCssWidth = cssWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context
        .select<HtmlService, Observed<StructureModel>>((s) => s.structureView);
    final hasBrowser = context
        .select<HtmlService, bool>((s) => s.store.current.target is UrlTarget);
    final fullTiles =
        context.select<HtmlService, PageShotTiles?>((s) => s.fullPageTiles);
    final liveShot = context.select<HtmlService, Observed<Uint8List>>(
        (s) => s.store.current.liveScreenshot);
    final liveBytes = liveShot is Present<Uint8List> ? liveShot.value : null;
    // Prefer the full-page capture; until the scroll-through is done, show
    // the top-of-page shot taken without scrolling. The old tiles stay on
    // screen until the new ones are decoded (both are drawn at their own
    // page offsets, so either lines up with the wireframe).
    final Object? source = fullTiles ?? liveBytes;
    if (!identical(source, _tilesSource)) {
      _tilesSource = source;
      _tilesFullPage = fullTiles != null;
      final shots = fullTiles?.tiles ??
          [if (liveBytes != null) (liveBytes, 0.0)];
      final cssWidth = fullTiles?.cssWidth;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(source, _tilesSource)) return;
        if (source == null) {
          if (_tiles.isNotEmpty) {
            setState(() {
              _disposeTiles(_tiles);
              _tiles = const [];
            });
          }
        } else {
          _loadTiles(source, shots, cssWidth);
        }
      });
    }
    final bytes = liveBytes ??
        (fullTiles != null && fullTiles.tiles.isNotEmpty
            ? fullTiles.tiles.first.$1
            : null);
    final body = switch (state) {
      Pending<StructureModel>(:final detail) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(detail ?? 'Measuring the page…',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      Present<StructureModel>(:final value) => _model(context, value),
      _ => _unknown(context, state, hasBrowser),
    };
    // While the wireframe is not measured yet, the screenshot already shows
    // behind the message (the wireframe draws it itself once present).
    if (state is Present<StructureModel> || bytes == null) return body;
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.3,
            child: Image.memory(bytes,
                fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
        body,
      ],
    );
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
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(model.measuredAt,
                style: Theme.of(context).textTheme.bodySmall),
          ),
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
          // The wireframe is as wide as the page, scaled down to the tab's
          // width when the page is wider (never wider than 1000 px), centred
          // in the tab.
          LayoutBuilder(builder: (context, constraints) {
            final scale = wireframeScale(model.layout, constraints.maxWidth);
            final w = model.layout.width * scale;
            final boxWidth =
                w < constraints.maxWidth ? constraints.maxWidth : w;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: boxWidth,
                child: Center(
                  child: GestureDetector(
                    onTapUp: (d) => _openDetails(
                        context,
                        blockAt(model, d.localPosition.dx / scale,
                            d.localPosition.dy / scale)),
                    child: Semantics(
                      label: 'Page wireframe, ${model.blocks.length} blocks',
                      child: CustomPaint(
                        key: const Key('structure-wireframe'),
                        size: Size(model.layout.width * scale,
                            model.layout.height * scale),
                        painter: StructurePainter(
                            model: model,
                            scale: scale,
                            coloring: _coloring,
                            scheme: scheme,
                            background: _tiles,
                            backgroundCssWidth: _tilesCssWidth,
                            backgroundFullPage: _tilesFullPage),
                      ),
                    ),
                  ),
                ),
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
          const SizedBox(height: 16),
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
        ],
      ),
    );
  }

  void _openDetails(BuildContext context, StructureBlock? s) {
    if (s == null) return;
    // Large sheet: the details plus the element's DOM subtree need room.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheet, scrollController) => _BlockDetailsSheet(
          block: s,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// The body of the Structure tab's details sheet: the block's facts, the
/// actions, and a small DOM tree of just the selected element's subtree.
class _BlockDetailsSheet extends StatelessWidget {
  final StructureBlock block;
  final ScrollController scrollController;

  const _BlockDetailsSheet({
    required this.block,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<HtmlService>();
    final s = block;
    final b = s.block;
    final line = service.sourceLineOfBlock(s);
    final theme = Theme.of(context);
    String n(double v) => v.round().toString();

    // The DOM node matching this block (tag/id/classes + occurrence), so the
    // sheet can show only its subtree. The tree builds lazily for large
    // pages: selecting it starts the build and this sheet rebuilds when the
    // notifyListeners from the finished build arrives.
    final layout = context.select<HtmlService, PageLayout?>((s) {
      final l = s.store.current.layout;
      return l is Present<PageLayout> ? l.value : null;
    });
    final tree = context.select<HtmlService, DomTree?>((s) => s.domTree);
    final node = (layout != null && tree != null)
        ? findNodeBySignature(
            tree.roots,
            DomReveal(
              tag: b.tag,
              id: b.id,
              classes: b.classes,
              occurrence: occurrenceOfBlock(layout.blocks, b),
            ))
        : null;

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('${n(b.width)} × ${n(b.height)} px at (${n(b.x)}, ${n(b.y)})'),
        Text('Kind: ${b.kind.name}'),
        Text('Owner: ${s.owner.name}'),
        if (s.service != null) Text('Service: ${s.service}'),
        if (b.src.isNotEmpty) Text('Source: ${b.src}'),
        Text('Contains ${b.descendants} elements'),
        if (b.fixed) const Text('fixed'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                service.revealDomBlock(s);
              },
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Open in DOM tree'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                if (line != null) {
                  service.revealSourceLine(line);
                } else {
                  service.showSourceTab();
                }
              },
              icon: const Icon(Icons.code),
              label: const Text('Open in source'),
            ),
          ],
        ),
      ],
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The facts and buttons take what they need (at most half the
              // sheet) and scroll when there is less room.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.5),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: details,
                ),
              ),
              if (node != null) ...[
                const SizedBox(height: 12),
                Text('DOM of ${s.label}', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                // The subtree fills the rest of the sheet downward.
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DomSubtreeView(root: node),
                  ),
                ),
              ] else if (tree == null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Building the DOM tree…'),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('No matching DOM node for ${s.label}.',
                      style: TextStyle(color: theme.colorScheme.outline)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
