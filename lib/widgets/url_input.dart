import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/url_history_service.dart';

class UrlInput extends StatefulWidget {
  const UrlInput({super.key});

  @override
  State<UrlInput> createState() => _UrlInputState();
}

class _UrlInputState extends State<UrlInput> {
  final _urlController = TextEditingController();
  final _focusNode = FocusNode();
  String _errorMessage = '';
  String? _lastKnownPath; // Track the last path we synchronized from the model

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    final url = _urlController.text.trim();
    // if (url.isEmpty) {
    //   setState(() => _errorMessage = 'Please enter a URL');
    //   return;
    // }

    setState(() => _errorMessage = '');

    try {
      // probe the URL if we are loading a new one
      // This satisfies "Only an enter will probe for a new url"
      // We do this in parallel or after load? Use the same URL.
      Provider.of<HtmlService>(context, listen: false).probeUrl(url).ignore();
      await Provider.of<HtmlService>(context, listen: false).loadFromUrl(url);

      // Clear the input after successful load
      // _urlController.clear();
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
        debugPrint(
            'url ${htmlService.currentFile?.path} ${htmlService.currentFile?.extension}');
        if (htmlService.currentFile != null) {
          final currentPath = htmlService.currentFile!.path;

          // Only update the controller if the model has changed to a NEW path
          // that we haven't seen before.
          if (_lastKnownPath != currentPath) {
            _lastKnownPath = currentPath;

            if (htmlService.currentFile!.isUrl) {
              // Show URL for web content
              if (_urlController.text != currentPath) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Check again to be safe
                  if (mounted && _urlController.text != currentPath) {
                    _urlController.text = currentPath;
                  }
                });
              }
            } else {
              // Clear URL bar for local files
              if (_urlController.text.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _urlController.clear();
                });
              }
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: htmlService.canGoBack
                        ? () => htmlService.goBack()
                        : null,
                  ),
                  Expanded(
                    child: RawAutocomplete<String>(
                      textEditingController: _urlController,
                      focusNode: _focusNode,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        final historyService = Provider.of<UrlHistoryService?>(
                            context,
                            listen: false);
                        final history = historyService?.history ?? [];

                        if (textEditingValue.text.isEmpty) {
                          return history;
                        }
                        return history.where((String option) {
                          return option
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        _urlController.text = selection;
                        _loadUrl();
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: htmlService.currentFile != null &&
                                    htmlService.currentFile!.isUrl
                                ? 'Current URL'
                                : htmlService.currentFile != null &&
                                        htmlService.currentFile!.name != ''
                                    ? 'File: ${htmlService.currentFile!.name}'
                                    : 'Enter URL',
                            hintText: htmlService.currentFile != null &&
                                    htmlService.currentFile!.isUrl
                                ? ''
                                : htmlService.currentFile != null
                                    ? 'Local file loaded: ${htmlService.currentFile!.name}'
                                    : '',
                            prefixIcon: const Icon(Icons.link, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6)),
                            suffixIcon: _urlController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      _urlController.clear();
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (value) {
                            onFieldSubmitted();
                            _loadUrl();
                          },
                          style: const TextStyle(fontSize: 14),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: MediaQuery.of(context).size.width -
                                  56, // Adjust width for back button
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Theme.of(context).cardColor,
                              ),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (BuildContext context, int index) {
                                  final String option =
                                      options.elementAt(index);
                                  return ListTile(
                                    title: Text(option,
                                        style: const TextStyle(fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    onTap: () => onSelected(option),
                                    dense: true,
                                    leading:
                                        const Icon(Icons.history, size: 16),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_errorMessage.isNotEmpty &&
                  htmlService.currentFile != null) ...[
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
