import 'package:flutter/material.dart';

import '../models/inspection/observed.dart';

/// Renders any [Observed] value: formatted value with source badge,
/// an explicit "not available" message, a spinner, or the error.
class ObservedValue<T> extends StatelessWidget {
  final Observed<T> value;
  final String Function(T) format;

  const ObservedValue({super.key, required this.value, required this.format});

  static String _sourceLabel(DataSource s) => switch (s) {
        DataSource.browser => 'browser',
        DataSource.server => 'server',
        DataSource.file => 'file',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    switch (value) {
      case Present<T>(:final value, :final source, :final provenance):
        final prefix = provenance == Provenance.estimated ? '≈ ' : '';
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text('$prefix${format(value)}'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_sourceLabel(source), style: muted),
            ),
          ],
        );
      case Unavailable<T>(:final reason, :final detail):
        return Text(unavailableMessage(reason, detail),
            style: muted?.copyWith(fontStyle: FontStyle.italic));
      case Pending<T>():
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case Failed<T>(:final error):
        return Text(error, style: TextStyle(color: theme.colorScheme.error));
    }
  }
}
