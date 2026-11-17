import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/screens/batch_screen.dart';
import 'package:view_source_vibe/services/batch_runner.dart';

/// Progress of a batch above the tab bar; the result links once it is done.
class BatchBanner extends StatelessWidget {
  const BatchBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final runner = context.watch<BatchRunner>();
    final String text;
    final List<Widget> actions;
    if (runner.running) {
      final phase = runner.phase == 'waiting'
          ? 'waiting for ${runner.currentPending.join(', ')}'
          : runner.phase;
      text = 'Batch ${runner.index + 1}/${runner.total}'
          ' · ${runner.currentUrl?.host ?? ''}'
          '${phase.isEmpty ? '' : ' · $phase'}';
      actions = [
        TextButton(onPressed: runner.cancel, child: const Text('Cancel'))
      ];
    } else if (runner.error != null || runner.rows.isNotEmpty) {
      text = runner.error != null
          ? 'Batch failed: ${runner.error}'
          : 'Batch done: ${runner.rows.length} site(s)';
      actions = [
        if (runner.rows.isNotEmpty)
          TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const BatchResultsScreen())),
              child: const Text('Results')),
        TextButton(onPressed: runner.dismiss, child: const Text('Dismiss')),
      ];
    } else {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSecondaryContainer))),
          ...actions,
        ]),
      ),
    );
  }
}
