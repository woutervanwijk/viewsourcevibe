import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:view_source_vibe/services/html_service.dart';
import 'package:view_source_vibe/services/url_history_service.dart';
import 'package:view_source_vibe/utils/path_name.dart';

/// Key of the home screen's [UrlInput]; the Cmd/Ctrl+L shortcut focuses it.
final GlobalKey<UrlInputState> urlInputKey = GlobalKey<UrlInputState>();

class UrlInput extends StatefulWidget {
  const UrlInput({super.key});

  @override
  State<UrlInput> createState() => UrlInputState();
}

class UrlInputState extends State<UrlInput> {
  final _urlController = TextEditingController();
  final _focusNode = FocusNode();
  String _errorMessage = '';
  // Track if user has navigated the suggestions list using keyboard
  bool _userHasNavigated = false;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    _focusNode.addListener(_handleFocusChange);
  }

  /// Extract just the filename from a file path for display
  String _getDisplayNameForPath(String path) {
    // Handle file:// URLs
    if (path.startsWith('file://')) {
      path = path.replaceFirst('file://', '');
    }

    // Handle Windows paths (C:\path\to\file)
    if (path.contains('\\') || path.contains(':\\')) {
      return fileNameOfPath(path);
    }

    // Handle Unix paths (/path/to/file)
    if (path.startsWith('/')) {
      return path.split('/').last;
    }

    // If it's already just a filename, return as-is
    return path;
  }

  /// Focus the field and select its text, like Cmd/Ctrl+L in a browser.
  void focusLocationBar() {
    _focusNode.requestFocus();
    _urlController.selection =
        TextSelection(baseOffset: 0, extentOffset: _urlController.text.length);
  }

  void _onUrlChanged() {
    final htmlService = Provider.of<HtmlService>(context, listen: false);
    htmlService.currentInputText = _urlController.text;

    // Reset navigation state when user types
    if (_userHasNavigated) {
      setState(() {
        _userHasNavigated = false;
      });
    } else {
      setState(() {});
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _urlController.text.isEmpty) {
      // Use addPostFrameCallback to ensure this runs after any other focus/text operations
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _urlController.text.isEmpty && !_focusNode.hasFocus) {
          final htmlService = Provider.of<HtmlService>(context, listen: false);
          if (htmlService.currentFile != null) {
            if (htmlService.currentFile!.isUrl) {
              _urlController.text = htmlService.currentFile!.path;
            } else {
              // For local files, show only the filename without the full path
              _urlController.text =
                  _getDisplayNameForPath(htmlService.currentFile!.name);
            }
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

      await htmlService.openInputText(url, switchToTab: switchToTab);

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
    return Selector<HtmlService, _UrlInputStructure>(
      selector: (context, service) => _UrlInputStructure(
        currentInputText: service.currentInputText,
        currentFile: service.currentFile,
        isLoading: service.isLoading,
        activeTabIndex: service.activeTabIndex,
        fileNotice: service.fileNotice,
      ),
      builder: (context, structure, child) {
        final htmlService = Provider.of<HtmlService>(context, listen: false);

        // Update URL display when file changes
        if (structure.currentInputText != null) {
          final currentText = structure.currentInputText!;

          if (_urlController.text != currentText) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _urlController.text != currentText) {
                _urlController.text = currentText;
              }
            });
          }
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Hide keyboard on mobile when tapping outside the text field
            if (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.android)) {
              SystemChannels.textInput.invokeMethod('TextInput.hide');
            }
            // Also unfocus for consistency
            if (!_focusNode.hasFocus) {
              FocusScope.of(context).unfocus();
            }
          },
          child: Padding(
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
                          final historyService =
                              Provider.of<UrlHistoryService?>(
                            context,
                            listen: false,
                          );
                          final history = historyService?.history ?? [];

                          if (textEditingValue.text.isEmpty) {
                            return history;
                          }
                          return history.where((String option) {
                            return option.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase(),
                                );
                          });
                        },
                        onSelected: (String selection) {
                          // For local files, use just the filename in the URL bar
                          final isUrl = selection.startsWith('http://') ||
                              selection.startsWith('https://');
                          _urlController.text =
                              isUrl ? selection : fileNameOfPath(selection);
                          // Hide keyboard on mobile after selection
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              if (!kIsWeb &&
                                  (defaultTargetPlatform ==
                                          TargetPlatform.iOS ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.android)) {
                                SystemChannels.textInput
                                    .invokeMethod('TextInput.hide');
                              }
                              FocusScope.of(context).unfocus();
                            }
                          });
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          return KeyboardListener(
                            focusNode: FocusNode(skipTraversal: true),
                            onKeyEvent: (event) {
                              if (event is KeyDownEvent) {
                                if (event.logicalKey ==
                                        LogicalKeyboardKey.arrowDown ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.arrowUp) {
                                  if (!_userHasNavigated) {
                                    setState(() {
                                      _userHasNavigated = true;
                                    });
                                  }
                                }
                              }
                            },
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: structure.currentFile != null &&
                                        structure.currentFile!.isUrl
                                    ? ''
                                    : structure.currentFile != null
                                        ? 'Local file loaded: ${_getDisplayNameForPath(structure.currentFile!.name)}'
                                        : '',
                                prefixIcon: IconButton(
                                  icon: const Icon(Icons.link, size: 20),
                                  tooltip: 'Reload',
                                  onPressed: () {
                                    _loadUrl(
                                      switchToTab: structure.activeTabIndex,
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                suffixIcon: _UrlInputProgress(
                                    htmlService: htmlService,
                                    controller: _urlController),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.go,
                              onSubmitted: (value) {
                                if (_userHasNavigated) {
                                  onFieldSubmitted();
                                }

                                _loadUrl(); // stay on the current tab
                              },
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return _AutocompleteOptions(
                            displayStringForOption: (option) => option,
                            onSelected: onSelected,
                            onOptionTap: () => _loadUrl(),
                            options: options,
                            maxOptionsHeight: 200,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (_errorMessage.isNotEmpty ||
                    structure.fileNotice != null ||
                    (structure.currentFile?.isError ?? false)) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _errorMessage.isNotEmpty
                              ? _errorMessage
                              : structure.fileNotice ??
                                  'Load failed. See details below.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (!kIsWeb)
                        TextButton.icon(
                          icon: const Icon(Icons.language, size: 14),
                          label: const Text(
                            'Try in Browser Tab',
                            style: TextStyle(fontSize: 11),
                          ),
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
          ),
        );
      },
    );
  }
}

class _AutocompleteOptions extends StatefulWidget {
  const _AutocompleteOptions({
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
      // The background color lives on the Material itself: a colored
      // DecoratedBox/ColoredBox between the ListTiles and the Material would
      // hide their background and ink splashes (framework error).
      child: Material(
        elevation: 4.0,
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: MediaQuery.of(context).size.width - 16,
          constraints: BoxConstraints(maxHeight: widget.maxOptionsHeight),
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
                displayName = 'File: ${fileNameOfPath(option)}';
              }

              // tileColor paints on the Material above, so the highlight
              // and the ink splash stay visible.
              return ListTile(
                tileColor: isHighlighted
                    ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withAlpha(77)
                    : null,
                title: Text(
                  displayName,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  widget.onSelected(option);
                  widget.onOptionTap();
                },
                dense: true,
                leading: Icon(
                  isUrl ? Icons.history : Icons.insert_drive_file_outlined,
                  size: 16,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Helper component to isolate progress indicator rebuilds
class _UrlInputProgress extends StatelessWidget {
  final HtmlService htmlService;
  final TextEditingController controller;

  const _UrlInputProgress({
    required this.htmlService,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<HtmlService, _UrlInputProgressData>(
      selector: (context, service) => _UrlInputProgressData(
        isLoading: service.isLoading,
        webViewLoadingProgress: service.webViewLoadingProgress,
      ),
      builder: (context, data, child) {
        final bool showProgress = data.isLoading ||
            (data.webViewLoadingProgress > 0 &&
                data.webViewLoadingProgress < 1.0);

        if (showProgress) {
          return GestureDetector(
            onTap: () => htmlService.cancelWebViewLoad(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  value: data.webViewLoadingProgress > 0
                      ? data.webViewLoadingProgress
                      : null,
                  strokeWidth: 1,
                ),
              ),
            ),
          );
        }

        // Use ListenableBuilder for the controller text to avoid rebuilding the whole UrlInput
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (controller.text.isNotEmpty) {
              return IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  controller.clear();
                  htmlService.cancelWebViewLoad();
                },
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

@immutable
class _UrlInputStructure {
  final String? currentInputText;
  final dynamic
      currentFile; // Use dynamic to avoid deep dependency check if not needed
  final bool isLoading;
  final int activeTabIndex;
  final String? fileNotice;

  const _UrlInputStructure({
    this.currentInputText,
    this.currentFile,
    required this.isLoading,
    required this.activeTabIndex,
    this.fileNotice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UrlInputStructure &&
          runtimeType == other.runtimeType &&
          currentInputText == other.currentInputText &&
          currentFile == other.currentFile &&
          isLoading == other.isLoading &&
          activeTabIndex == other.activeTabIndex &&
          fileNotice == other.fileNotice;

  @override
  int get hashCode =>
      currentInputText.hashCode ^
      currentFile.hashCode ^
      isLoading.hashCode ^
      activeTabIndex.hashCode ^
      fileNotice.hashCode;
}

@immutable
class _UrlInputProgressData {
  final bool isLoading;
  final double webViewLoadingProgress;

  const _UrlInputProgressData({
    required this.isLoading,
    required this.webViewLoadingProgress,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UrlInputProgressData &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          webViewLoadingProgress == other.webViewLoadingProgress;

  @override
  int get hashCode => isLoading.hashCode ^ webViewLoadingProgress.hashCode;
}
