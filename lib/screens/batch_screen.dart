import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:view_source_vibe/services/batch_input_store.dart';
import 'package:view_source_vibe/services/batch_runner.dart';
import 'package:view_source_vibe/services/derive/inspection_summary.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';
import 'package:view_source_vibe/widgets/share_package_dialog.dart';

/// Paste a list of sites and start visiting them one by one.
class BatchScreen extends StatefulWidget {
  const BatchScreen({super.key});

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  final _store = BatchInputStore();
  final _controller = TextEditingController();
  bool _clearSiteData = true;
  bool _freshLoad = false;

  @override
  void initState() {
    super.initState();
    _store.load().then((text) {
      if (mounted && _controller.text.isEmpty) {
        setState(() => _controller.text = text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start(List<Uri> urls) {
    context
        .read<BatchRunner>()
        .run(urls,
            options: BatchOptions(
                clearSiteData: _clearSiteData, freshLoad: _freshLoad))
        .ignore();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseBatchInput(_controller.text);
    final running = context.watch<BatchRunner>().running;
    return Scaffold(
      appBar: AppBar(title: const Text('Batch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            decoration: const InputDecoration(
                hintText: 'One site per line', border: OutlineInputBorder()),
            onChanged: (text) {
              _store.save(text);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Text('${parsed.urls.length} site(s)'),
          if (parsed.rejected.isNotEmpty)
            Text(
                '${parsed.rejected.length} line(s) skipped: '
                '${parsed.rejected.take(3).join(', ')}',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          SwitchListTile(
            title: const Text('Clear site data before each site'),
            value: _clearSiteData,
            onChanged: (v) => setState(() => _clearSiteData = v),
          ),
          SwitchListTile(
            title: const Text('Also measure a fresh load (slower)'),
            value: _freshLoad,
            onChanged: (v) => setState(() => _freshLoad = v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: parsed.urls.isEmpty || running
                  ? null
                  : () => _start(parsed.urls),
              child: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tile per site, and the zip to share or save.
class BatchResultsScreen extends StatelessWidget {
  const BatchResultsScreen({super.key});

  bool get _mobile => Platform.isIOS || Platform.isAndroid;

  Future<void> _export(BuildContext context, BatchRunner runner) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_mobile && !await confirmSharePackage(context)) return;
      final file = await runner.writeZip();
      if (file == null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('No site finished: nothing to export')));
        return;
      }
      if (_mobile) {
        await UnifiedSharingService.shareFile(file.path,
            mimeType: 'application/zip');
        messenger
            .showSnackBar(const SnackBar(content: Text('Batch zip shared')));
        return;
      }
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save Batch Zip',
        fileName: file.uri.pathSegments.last,
        bytes: Uint8List.fromList(await file.readAsBytes()),
      );
      if (savePath == null) return;
      messenger
          .showSnackBar(SnackBar(content: Text('Batch zip saved: $savePath')));
    } catch (e) {
      debugPrint('Batch export error: $e');
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final runner = context.watch<BatchRunner>();
    final rows = runner.rows;
    return Scaffold(
      appBar: AppBar(title: Text('Batch results (${rows.length})')),
      body: Column(children: [
        Expanded(
          child: ListView(children: [
            for (final r in rows)
              ListTile(
                title: Text(r.url.host),
                subtitle: Text([
                  r.state + (r.error == null ? '' : ': ${r.error}'),
                  for (final f in r.summary?.top.take(3) ?? const <Finding>[])
                    '${f.severity.label}: ${f.title}',
                ].join('\n')),
                isThreeLine: (r.summary?.top.isNotEmpty ?? false),
              ),
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(
              onPressed: runner.running || rows.isEmpty
                  ? null
                  : () => _export(context, runner),
              child: Text(_mobile ? 'Share zip' : 'Save zip'),
            ),
          ),
        ),
      ]),
    );
  }
}
