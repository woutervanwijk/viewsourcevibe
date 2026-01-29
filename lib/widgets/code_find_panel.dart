import 'package:flutter/material.dart';

class CodeFindPanelView extends StatefulWidget implements PreferredSizeWidget {
  final dynamic controller;
  final bool readOnly;

  const CodeFindPanelView({
    super.key,
    required this.controller,
    required this.readOnly,
  });

  @override
  State<CodeFindPanelView> createState() => _CodeFindPanelViewState();

  @override
  Size get preferredSize => const Size.fromHeight(200); // Adjust height as needed
}

class _CodeFindPanelViewState extends State<CodeFindPanelView> {
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();
  final FocusNode _replaceFocusNode = FocusNode();

  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _regex = false;
  bool _showReplace = false;

  int _currentMatchIndex = 0;
  List<Map<String, int>> _findResults = []; // List of {start, end} maps

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
    _replaceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4.0,
            spreadRadius: 1.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFindField(),
          if (_showReplace) ...[
            const SizedBox(height: 8),
            _buildReplaceField(),
          ],
          const SizedBox(height: 8),
          _buildOptionsRow(),
          const SizedBox(height: 8),
          _buildActionButtons(),
          if (_findResults.isNotEmpty)
            _buildMatchInfo(),
        ],
      ),
    );
  }

  Widget _buildFindField() {
    return TextField(
      controller: _findController,
      focusNode: _findFocusNode,
      decoration: InputDecoration(
        labelText: 'Find',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _findController.clear();
            _clearFindResults();
          },
        ),
      ),
      onChanged: (text) {
        if (text.isEmpty) {
          _clearFindResults();
        } else {
          _performFind(text);
        }
      },
      onSubmitted: (text) {
        if (text.isNotEmpty) {
          _findNext();
        }
      },
    );
  }

  Widget _buildReplaceField() {
    return TextField(
      controller: _replaceController,
      focusNode: _replaceFocusNode,
      decoration: InputDecoration(
        labelText: 'Replace with',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _replaceController.clear();
          },
        ),
      ),
      onSubmitted: (text) {
        _replaceCurrent();
      },
    );
  }

  Widget _buildOptionsRow() {
    return Row(
      children: [
        FilterChip(
          label: const Text('Case sensitive'),
          selected: _caseSensitive,
          onSelected: (selected) {
            setState(() {
              _caseSensitive = selected;
            });
            _performFind(_findController.text);
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Whole word'),
          selected: _wholeWord,
          onSelected: (selected) {
            setState(() {
              _wholeWord = selected;
            });
            _performFind(_findController.text);
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Regex'),
          selected: _regex,
          onSelected: (selected) {
            setState(() {
              _regex = selected;
            });
            _performFind(_findController.text);
          },
        ),
        const Spacer(),
        if (!_showReplace)
          TextButton(
            onPressed: () {
              setState(() {
                _showReplace = true;
              });
            },
            child: const Text('Replace'),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: _findResults.isEmpty ? null : _findPrevious,
          child: const Text('Previous'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _findResults.isEmpty ? null : _findNext,
          child: const Text('Next'),
        ),
        if (_showReplace) ...[
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _findResults.isEmpty || _replaceController.text.isEmpty
                ? null
                : _replaceCurrent,
            child: const Text('Replace'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _findResults.isEmpty || _replaceController.text.isEmpty
                ? null
                : _replaceAll,
            child: const Text('Replace All'),
          ),
        ],
      ],
    );
  }

  Widget _buildMatchInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        '${_currentMatchIndex + 1} of ${_findResults.length} matches',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodySmall?.color,
          fontSize: 12,
        ),
      ),
    );
  }

  void _performFind(String text) {
    if (text.isEmpty) {
      _clearFindResults();
      return;
    }

    // Implement actual search functionality
    try {
      final controller = widget.controller;
      if (controller == null) {
        debugPrint('❌ Find controller is null');
        return;
      }

      // Get the text content from the controller
      final content = controller.text ?? '';
      if (content.isEmpty) {
        _clearFindResults();
        return;
      }

      // Perform case-sensitive search if enabled
      final searchText = _caseSensitive ? text : text.toLowerCase();
      final contentToSearch = _caseSensitive ? content : content.toLowerCase();

      // Find all matches
      final matches = <Map<String, int>>[];
      int startIndex = 0;
      
      while (startIndex < contentToSearch.length) {
        final matchIndex = contentToSearch.indexOf(searchText, startIndex);
        if (matchIndex == -1) break;

        // Check for whole word match if enabled
        if (_wholeWord) {
          final isWholeWord = _isWholeWordMatch(contentToSearch, matchIndex, searchText.length);
          if (!isWholeWord) {
            startIndex = matchIndex + 1;
            continue;
          }
        }

        matches.add({
          'start': matchIndex,
          'end': matchIndex + searchText.length,
        });
        startIndex = matchIndex + 1;
      }

      setState(() {
        _findResults = matches;
        _currentMatchIndex = 0;
      });

      // Highlight the first match
      _highlightCurrentMatch();
    } catch (e) {
      debugPrint('❌ Error performing find: $e');
      _clearFindResults();
    }
  }

  bool _isWholeWordMatch(String content, int startIndex, int length) {
    // Check if the match is a whole word
    final endIndex = startIndex + length;
    
    // Check character before the match
    if (startIndex > 0) {
      final charBefore = content[startIndex - 1];
      if (charBefore != ' ' && charBefore != '\n' && charBefore != '\t' && charBefore != '\r') {
        return false;
      }
    }

    // Check character after the match
    if (endIndex < content.length) {
      final charAfter = content[endIndex];
      if (charAfter != ' ' && charAfter != '\n' && charAfter != '\t' && charAfter != '\r') {
        return false;
      }
    }

    return true;
  }

  void _highlightCurrentMatch() {
    if (_findResults.isEmpty) return;

    try {
      final controller = widget.controller;
      if (controller == null) return;

      // For now, just ensure the controller is updated
      // The actual highlighting will be handled by the editor's built-in selection
      if (controller.notifyListeners != null) {
        controller.notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error highlighting match: $e');
    }
  }

  void _findNext() {
    if (_findResults.isEmpty) return;

    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _findResults.length;
    });

    _highlightCurrentMatch();
  }

  void _findPrevious() {
    if (_findResults.isEmpty) return;

    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _findResults.length) % _findResults.length;
    });

    _highlightCurrentMatch();
  }

  void _replaceCurrent() {
    if (_findResults.isEmpty || _replaceController.text.isEmpty) return;

    try {
      final controller = widget.controller;
      if (controller == null) return;

      final currentMatch = _findResults[_currentMatchIndex];
      final start = currentMatch['start'] ?? 0;
      final end = currentMatch['end'] ?? 0;

      // Replace the current match
      final currentText = controller.text ?? '';
      final newText = currentText.replaceRange(
        start,
        end,
        _replaceController.text,
      );

      // Update the controller text
      controller.text = newText;

      // Re-perform the search to update matches after replacement
      _performFind(_findController.text);
    } catch (e) {
      debugPrint('❌ Error replacing current: $e');
    }
  }

  void _replaceAll() {
    if (_findResults.isEmpty || _replaceController.text.isEmpty) return;

    try {
      final controller = widget.controller;
      if (controller == null) return;

      final replaceText = _replaceController.text;
      
      // Replace all occurrences
      String newText = controller.text ?? '';
      int replaceCount = 0;

      // We need to process replacements from the end to avoid index shifting
      final matches = List<Map<String, int>>.from(_findResults);
      
      for (int i = matches.length - 1; i >= 0; i--) {
        final match = matches[i];
        final start = match['start'] ?? 0;
        final end = match['end'] ?? 0;

        newText = newText.replaceRange(
          start,
          end,
          replaceText,
        );
        replaceCount++;
      }

      // Update the controller text
      controller.text = newText;

      // Show a snackbar with the replacement count
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Replaced $replaceCount occurrences'),
            duration: const Duration(seconds: 2),
          ),
        );
      });

      // Clear the find results and search field
      _findController.clear();
      _clearFindResults();
    } catch (e) {
      debugPrint('❌ Error replacing all: $e');
    }
  }

  void _clearFindResults() {
    setState(() {
      _findResults = [];
      _currentMatchIndex = 0;
    });
  }
}