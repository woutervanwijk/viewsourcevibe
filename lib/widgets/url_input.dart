import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htmlviewer/services/html_service.dart';

class UrlInput extends StatefulWidget {
  const UrlInput({super.key});

  @override
  State<UrlInput> createState() => _UrlInputState();
}

class _UrlInputState extends State<UrlInput> {
  final _urlController = TextEditingController();
  String _errorMessage = '';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please enter a URL');
      return;
    }

    setState(() => _errorMessage = '');

    try {
      await Provider.of<HtmlService>(context, listen: false).loadFromUrl(url);
      // Clear the input after successful load
      _urlController.clear();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HtmlService>(
      builder: (context, htmlService, child) {
        // Update URL display when file changes
        if (htmlService.currentFile != null) {
          if (htmlService.currentFile!.path.startsWith('http')) {
            // Show URL for web content
            if (_urlController.text != htmlService.currentFile!.path) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _urlController.text = htmlService.currentFile!.path;
              });
            }
          } else {
            // Clear URL bar for local files
            if (_urlController.text.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _urlController.clear();
              });
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: htmlService.currentFile != null &&
                          htmlService.currentFile!.path.startsWith('http')
                      ? 'Current URL'
                      : htmlService.currentFile != null
                          ? 'Local File Loaded'
                          : 'Enter URL',
                  hintText: htmlService.currentFile != null &&
                          htmlService.currentFile!.path.startsWith('http')
                      ? ''
                      : htmlService.currentFile != null
                          ? ''
                          : 'https://example.com',
                  prefixIcon: const Icon(Icons.link, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  suffixIcon: _urlController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => _urlController.clear(),
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  isDense: true,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _loadUrl(),
                style: const TextStyle(fontSize: 14),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  _errorMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
