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
        if (htmlService.currentFile != null && 
            htmlService.currentFile!.path.startsWith('http') &&
            _urlController.text != htmlService.currentFile!.path) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _urlController.text = htmlService.currentFile!.path;
          });
        }
        
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: htmlService.currentFile != null && 
                          htmlService.currentFile!.path.startsWith('http')
                      ? 'Current URL'
                      : 'Enter URL',
                  hintText: htmlService.currentFile != null && 
                          htmlService.currentFile!.path.startsWith('http')
                      ? ''
                      : 'https://example.com',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: _urlController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _urlController.clear(),
                        )
                      : null,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _loadUrl(),
                readOnly: htmlService.currentFile != null && 
                         htmlService.currentFile!.path.startsWith('http'),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}