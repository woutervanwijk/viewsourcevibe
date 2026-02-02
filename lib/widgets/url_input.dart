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

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    _focusNode.addListener(_handleFocusChange);
  }

  void _onUrlChanged() {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    htmlService.currentInputText = _urlController.text;
    setState(() {});
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _urlController.text.isEmpty) {
      // Use addPostFrameCallback to ensure this runs after any other focus/text operations
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _urlController.text.isEmpty && !_focusNode.hasFocus) {
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          if (htmlService.currentFile != null &&
              htmlService.currentFile!.isUrl) {
            _urlController.text = htmlService.currentFile!.path;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _focusNode.removeListener(_handleFocusChange);
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
        if (htmlService.currentInputText != null) {
          final currentText = htmlService.currentInputText!;

          if (_urlController.text != currentText) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _urlController.text != currentText) {
                _urlController.text = currentText;
              }
            });
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
                          onTapOutside: (event) {
                            FocusScope.of(context).unfocus();
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

                                  String displayName = option;
                                  final isUrl = option.startsWith('http://') ||
                                      option.startsWith('https://');

                                  if (!isUrl) {
                                    // Assume it's a file path, extract filename
                                    // Handle both forward and backward slashes
                                    final parts =
                                        option.split(RegExp(r'[/\\]'));
                                    if (parts.isNotEmpty) {
                                      displayName = 'File: ${parts.last}';
                                    }
                                  }

                                  return ListTile(
                                    title: Text(displayName,
                                        style: const TextStyle(fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    onTap: () => onSelected(option),
                                    dense: true,
                                    leading: Icon(
                                        isUrl
                                            ? Icons.history
                                            : Icons.insert_drive_file_outlined,
                                        size: 16),
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
