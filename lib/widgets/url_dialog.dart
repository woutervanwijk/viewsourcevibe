import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';

class UrlDialog extends StatefulWidget {
  const UrlDialog({super.key});

  @override
  State<UrlDialog> createState() => _UrlDialogState();
}

class _UrlDialogState extends State<UrlDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final url = _urlController.text.trim();
      await Provider.of<HtmlService>(context, listen: false).loadFromUrl(url);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Open URL'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://github.com/woutervanwijk/viewsourcevibe',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a URL';
                }
                return null;
              },
              onFieldSubmitted: (_) => _loadUrl(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter a website URL to view its HTML source',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _loadUrl,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Load'),
        ),
      ],
    );
  }
}

void showUrlDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const UrlDialog(),
  );
}
