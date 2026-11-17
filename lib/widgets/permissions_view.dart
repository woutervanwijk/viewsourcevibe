import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/models/inspection/browser_snapshot.dart';
import 'package:view_source_vibe/models/inspection/observed.dart';
import 'package:view_source_vibe/services/derive/observed_text.dart';
import 'package:view_source_vibe/services/derive/page_size.dart';
import 'package:view_source_vibe/services/derive/permissions_view.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/widgets/observed_value.dart';
import 'package:view_source_vibe/widgets/section_box.dart';

/// The Permissions tab: what the page's policy allows, what it hands to
/// embedded frames, what it asked for while loading (the app denies all of
/// it) and what it keeps on this device.
class PermissionsView extends StatelessWidget {
  const PermissionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select<HtmlService, Observed<PermissionsModel>>(
        (s) => s.permissionsView);
    return switch (state) {
      Present<PermissionsModel>(:final value) => _content(context, value),
      Pending<PermissionsModel>() =>
        const Center(child: CircularProgressIndicator()),
      Failed<PermissionsModel>(:final error) => _message('Error: $error'),
      Unavailable<PermissionsModel>() => _message(notPresentText(state)),
    };
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );

  Widget _content(BuildContext context, PermissionsModel m) {
    final theme = Theme.of(context);
    return Scrollbar(
      child: ListView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 66),
        children: [
          for (final n in m.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(n)),
                ],
              ),
            ),
          _title(theme, 'Allowed by the site'),
          _declared(m),
          _title(theme, 'Handed to embedded frames'),
          _delegations(context, m),
          _title(theme, 'Asked while loading'),
          _requests(context, m),
          _title(theme, 'Stored on this device'),
          _stored(m),
        ],
      ),
    );
  }

  Widget _title(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(text,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.all(12), child: child);

  Widget _line(String label, Widget value) => _pad(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: value),
        ],
      ));

  /// Why a section has no data (never an empty box).
  Widget _why(Observed<Object?> o) =>
      _pad(ObservedValue<Object?>(value: o, format: (_) => ''));

  Widget _declared(PermissionsModel m) {
    final declared = m.declared;
    if (declared is! Present<List<DeclaredFeature>>) {
      return SectionBox(children: [_why(declared)]);
    }
    return SectionBox(children: [
      if (m.legacyHeaderOnly)
        _pad(const Text(
            'Only the older Feature-Policy header was sent, not Permissions-Policy.')),
      if (declared.value.isEmpty)
        _pad(const Text('The header is present and lists no features.')),
      for (final f in declared.value)
        _line(f.feature,
            Text(f.allowed + (f.powerful ? ' (device access)' : ''))),
      if (m.invalidDeclarations.isNotEmpty)
        _pad(Text('Could not read: ${m.invalidDeclarations.join(', ')}')),
    ]);
  }

  Widget _delegations(BuildContext context, PermissionsModel m) {
    final d = m.delegations;
    if (d is! Present<List<Delegation>>) {
      return SectionBox(children: [_why(d)]);
    }
    if (d.value.isEmpty) {
      return SectionBox(children: [
        _pad(Text(m.frameCount == 0
            ? 'The page has no embedded frames.'
            : 'None of the ${m.frameCount} embedded frames got an allow attribute.')),
      ]);
    }
    return SectionBox(children: [
      for (final f in d.value)
        _line(
          f.frameHost.isEmpty ? 'inline frame' : f.frameHost,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (f.thirdParty) _badge(context, 'third-party'),
              if (f.sandboxed) _badge(context, 'sandboxed'),
              Text(f.features.isEmpty ? 'no features' : f.features.join(', ')),
            ],
          ),
        ),
    ]);
  }

  Widget _badge(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }

  Widget _requests(BuildContext context, PermissionsModel m) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return SectionBox(children: [
      _pad(Text('Denied by this app', style: muted)),
      if (m.requests.isEmpty) _pad(const Text('No requests while loading.')),
      for (final r in m.requests)
        _line(r.resources.join(', '),
            Text('${r.origin}, ${_seconds(r.sinceLoadStart)}')),
    ]);
  }

  String _seconds(Duration d) {
    final tenths = (d.inMilliseconds / 100).round();
    return tenths < 100
        ? '${(tenths / 10).toStringAsFixed(1)} s'
        : '${(tenths / 10).round()} s';
  }

  Widget _stored(PermissionsModel m) {
    final s = m.stored;
    String size(Observed<int> o) =>
        presentOrUnknown(o, (v) => formatDownloadSize(v)!);
    String names(Observed<List<String>> o) =>
        presentOrUnknown(o, (v) => v.isEmpty ? 'none' : v.join(', '));
    return SectionBox(children: [
      if (s is Present<SiteStorage>) ...[
        _line(
            'Used',
            Text(
                '${size(s.value.usageBytes)} of ${size(s.value.quotaBytes)} used')),
        _line('IndexedDB', Text(names(s.value.indexedDbNames))),
        _line('Caches', Text(names(s.value.cacheNames))),
        _line(
            'Service workers',
            Text(presentOrUnknown(s.value.serviceWorkers,
                (v) => v.isEmpty ? 'none' : v.map((w) => w.scope).join(', ')))),
      ] else
        _why(s),
      _line('localStorage', Text(_area(m.webStorage, (w) => w.local))),
      _line('sessionStorage', Text(_area(m.webStorage, (w) => w.session))),
    ]);
  }

  String _area(Observed<BrowserStorage> o,
      Observed<StorageArea> Function(BrowserStorage) pick) {
    if (o is! Present<BrowserStorage>) return unknownText(o);
    return presentOrUnknown(pick(o.value), (a) {
      final bytes = a.bytes;
      final size =
          bytes is Present<int> ? ', ${formatDownloadSize(bytes.value)}' : '';
      return '${a.count} items$size';
    });
  }
}
