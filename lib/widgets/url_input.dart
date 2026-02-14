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
          if (htmlService.currentFile != null) {
            _urlController.text = htmlService.currentFile!.isUrl
                ? htmlService.currentFile!.path
                : htmlService.currentFile!.name;
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
      final htmlService = Provider.of<HtmlService>(context, listen: false);

      // Check if we are incorrectly reloading a local file by its name
      // This prevents "index.html" -> "https://index.html" conversion in loadUrl
      if (htmlService.currentFile != null &&
          !htmlService.currentFile!.isUrl &&
          url == htmlService.currentFile!.name) {
        await htmlService.reloadCurrentFile();
      } else {
        await htmlService.loadFromUrl(url, switchToTab: switchToTab ?? 0);
      }

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
            'url input change ${htmlService.currentFile?.path} ${htmlService.currentFile?.extension}');
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
                        // We don't load here anymore to avoid double loading on Enter.
                        // Loading is handled by onSubmitted (Enter key) or onTap (Click).
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
                            prefixIcon: IconButton(
                              icon: const Icon(Icons.link, size: 20),
                              tooltip: 'Reload',
                              onPressed: () {
                                _loadUrl(
                                    switchToTab: htmlService.activeTabIndex);
                              },
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6)),
                            suffixIcon: (htmlService.isLoading ||
                                    (htmlService.webViewLoadingProgress > 0 &&
                                        htmlService.webViewLoadingProgress <
                                            1.0))
                                ? GestureDetector(
                                    onTap: () =>
                                        htmlService.cancelWebViewLoad(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: htmlService
                                                          .webViewLoadingProgress >
                                                      0
                                                  ? htmlService
                                                      .webViewLoadingProgress
                                                  : null,
                                              strokeWidth: 1,
                                            ),
                                            // if (htmlService
                                            //         .webViewLoadingProgress >
                                            //     0)
                                            //   Text(
                                            //     '${(htmlService.webViewLoadingProgress * 100).toInt()}%',
                                            //     style: const TextStyle(
                                            //         fontSize: 8),
                                            //   ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : (_urlController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          _urlController.clear();
                                          htmlService.cancelWebViewLoad();
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
                            // Call onFieldSubmitted to handle autocomplete selection
                            onFieldSubmitted();
                            // If no option was selected (or onFieldSubmitted didn't handle it),
                            // we might need to manually trigger load.
                            // However, RawAutocomplete's onFieldSubmitted usually triggers onSelected if an option is highlighted.
                            // If no option is highlighted, it might do nothing.

                            // We need to know if an option was selected.
                            // A simple way is to check if the text changed or if onSelected was called.
                            // But onSelected is a callback.

                            // Actually, standard behavior: if panel is open and item highlighted -> select it.
                            // If not -> submit current text.
                            // onFieldSubmitted handles the first case.
                            // But it doesn't return anything.

                            // Use a small delay to allow onSelected to fire if it's going to.
                            // If _urlController.text hasn't changed effectively (or we just want to ensure load),
                            // we can call _loadUrl.
                            // *However*, calling _loadUrl immediately might race with onSelected setting the text.

                            // Better approach:
                            // 1. Call onFieldSubmitted().
                            // 2. If the autocomplete overlay is NOT visible (or no option is highlighted),
                            // then we should just load.
                            // But we don't have easy access to that state here.

                            // Alternative: relies on onSelected calling _loadUrl.
                            // If we call onFieldSubmitted, and it selects an option, onSelected (line 144) is called.
                            // Line 146 calls _loadUrl(switchToTab: 0).
                            // So if an option is selected, _loadUrl is called.

                            // What if NO option is selected?
                            // onFieldSubmitted does nothing.
                            // So we still need to call _loadUrl.
                            // But if we call it here, it might run TWICE if onSelected also runs.

                            // To prevent double loading:
                            // We can remove _loadUrl from onSelected (line 146) and ONLY do it here?
                            // No, clicking an option should also load.

                            // We can check if the text matches the value? No.

                            // Let's rely on the fact that if onSelected is called, it might be async or sync.
                            // A robust way:
                            // Check if an option is highlighted? We can't easily here.

                            // Let's try calling onFieldSubmitted();
                            // And ONLY if we didn't just select an option, we load.
                            // But how to know?

                            // Actually, RawAutocomplete documentation says onFieldSubmitted is called when user submits.
                            // We are inside BuildContext. We can check AutocompleteHighlightedOption.of(context)?
                            // No, that's available in optionsViewBuilder, not here.

                            // Let's simply call onFieldSubmitted() and then _loadUrl() *if* text is likely unchanged?
                            // Or just accept a potential double load (which might be cancelled by the second one)?
                            // _loadUrl cancels previous loads usually.

                            // Actually, if onSelected is called, it updates the text controller and calls _loadUrl.
                            // If we call _loadUrl here with the *old* text (before onSelected updates it), that's bad.
                            // onFieldSubmitted is synchronous. If it selects, it updates controller synchronously.
                            // So if we call onFieldSubmitted(), the controller.text might change immediately.
                            // Then we call _loadUrl().

                            // Wait, onSelected in RawAutocomplete implementation:
                            // It calls the onSelected callback passed to RawAutocomplete.
                            // Our onSelected (line 144) sets text and calls _loadUrl.

                            // So:
                            // 1. onFieldSubmitted() -> (internally finds highlighted option) -> calls our onSelected -> sets text, calls _loadUrl.
                            // 2. We then returns here.
                            // 3. We call _loadUrl again?

                            // If onSelected is called, _loadUrl runs.
                            // If we call _loadUrl again here, we load twice.

                            // To fix this, we can remove _loadUrl from onSelected and let the submit handler do it?
                            // But clicking an option (onTap) also calls onSelected. We want that to load.

                            // So:
                            // modify onSelected to NOT load? And call onFieldSubmitted() in onTap?
                            // No, onTap calls onSelected directly usually (in our code line 384: widget.onSelected(option)).
                            // So we can wrap the onSelected usage.

                            // Plan:
                            // 1. Modify onSelected (line 144) to ONLY set text.
                            // 2. Update onTap in _AutocompleteOptions to call onSelected AND _loadUrl.
                            // 3. Update onSubmitted here to call onFieldSubmitted() (which calls onSelected, setting text) AND then _loadUrl.

                            // This ensures:
                            // - Click: onTap -> onSelected (sets text) -> _loadUrl.
                            // - Enter (highlighted): onFieldSubmitted -> onSelected (sets text) -> return -> _loadUrl.
                            // - Enter (no highlight): onFieldSubmitted (no-op) -> return -> _loadUrl.

                            // Let's do this.

                            // Update onSubmitted first (this tool call).
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
                        return _AutocompleteOptions(
                          displayStringForOption: (option) => option,
                          onSelected: onSelected,
                          onOptionTap: () => _loadUrl(switchToTab: 0),
                          options: options,
                          maxOptionsHeight: 200,
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
                        label: const Text('Try in Browser Tab',
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

class _AutocompleteOptions extends StatefulWidget {
  const _AutocompleteOptions({
    super.key,
    required this.displayStringForOption,
    required this.onSelected,
    required this.onOptionTap,
    required this.options,
    required this.maxOptionsHeight,
  });

  final AutocompleteOptionToString<String> displayStringForOption;
  final AutocompleteOnSelected<String> onSelected;
  final VoidCallback onOptionTap;
  final Iterable<String> options;
  final double maxOptionsHeight;

  @override
  State<_AutocompleteOptions> createState() => _AutocompleteOptionsState();
}

class _AutocompleteOptionsState extends State<_AutocompleteOptions> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToItem(int index) {
    if (!_scrollController.hasClients) return;
    // Estimated item height (ListTile dense + divider)
    const double itemHeight = 48.0 + 1.0;

    // Simple scrolling logic: ensure the item is visible
    final double targetOffset = index * itemHeight;
    final double currentOffset = _scrollController.offset;
    final double viewportHeight = _scrollController.position.viewportDimension;

    if (targetOffset < currentOffset) {
      _scrollController.jumpTo(targetOffset);
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      _scrollController.jumpTo(targetOffset + itemHeight - viewportHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This listener will rebuild when highlighted option changes
    final int highlightedIndex = AutocompleteHighlightedOption.of(context);

    if (highlightedIndex >= 0 && highlightedIndex < widget.options.length) {
      // Schedule scroll after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToItem(highlightedIndex);
      });
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: MediaQuery.of(context).size.width - 16,
          constraints: BoxConstraints(maxHeight: widget.maxOptionsHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: Theme.of(context).cardColor,
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            controller: _scrollController,
            itemCount: widget.options.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final String option = widget.options.elementAt(index);
              final bool isHighlighted = index == highlightedIndex;

              String displayName = option;
              final isUrl =
                  option.startsWith('http://') || option.startsWith('https://');

              if (!isUrl) {
                final parts = option.split(RegExp(r'[/\\]'));
                if (parts.isNotEmpty) {
                  displayName = 'File: ${parts.last}';
                }
              }

              return Container(
                color: isHighlighted
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3)
                    : null,
                child: ListTile(
                  title: Text(displayName,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  onTap: () {
                    widget.onSelected(option);
                    widget.onOptionTap();
                  },
                  dense: true,
                  leading: Icon(
                      isUrl ? Icons.history : Icons.insert_drive_file_outlined,
                      size: 16),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
