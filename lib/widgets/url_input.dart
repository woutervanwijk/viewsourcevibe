import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  Future<void> _loadUrl({int? switchToTab}) async {
    final url = _urlController.text.trim();
    // if (url.isEmpty) {
    //   setState(() => _errorMessage = 'Please enter a URL');
    //   return;
    // }

    setState(() => _errorMessage = '');

    try {
      await Provider.of<HtmlService>(context, listen: false)
          .loadFromUrl(url, switchToTab: switchToTab);

      // Clear the input after successful load
      // _urlController.clear();
    } catch (e) {
      if (mounted) {
        String errorStr = e.toString().replaceFirst('Exception: ', '');
        setState(() => _errorMessage = 'Error: $errorStr');
      }
    }
  }

  Future<void> _loadViaWebView() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _errorMessage = '');

    final htmlService = Provider.of<HtmlService>(context, listen: false);
    htmlService.triggerWebViewLoad(url);
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
                        _loadUrl(switchToTab: 0);
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: htmlService.currentFile != null &&
                                    htmlService.currentFile!.isUrl
                                ? ''
                                : htmlService.currentFile != null
                                    ? 'Local file loaded: ${htmlService.currentFile!.name}'
                                    : '',
                            prefixIcon: const Icon(Icons.link, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6)),
                            suffixIcon: htmlService.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: SizedBox(
                                      width: 8,
                                      height: 8,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1,
                                      ),
                                    ),
                                  )
                                : (_urlController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          _urlController.clear();
                                        },
                                      )
                                    : null),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (value) {
                            onFieldSubmitted();
                            _loadUrl(switchToTab: 0);
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
                                  16, // Adjust width for full screen minus padding
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Theme.of(context).cardColor,
                              ),
                              child: ListView.separated(
                                primary: false,
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
              if (_errorMessage.isNotEmpty ||
                  (htmlService.currentFile?.isError ?? false)) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _errorMessage.isNotEmpty
                            ? _errorMessage
                            : 'Load failed. See details below.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (!kIsWeb)
                      TextButton.icon(
                        icon: const Icon(Icons.language, size: 14),
                        label: const Text('Force load with Browser',
                            style: TextStyle(fontSize: 11)),
                        onPressed: _loadViaWebView,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
