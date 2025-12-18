import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:view_source_vibe/services/code_editor_context_menu.dart';

/// A wrapper widget that adds context menu functionality to CodeEditor
class CodeEditorWithContextMenu extends StatefulWidget {
  final CodeLineEditingController controller;
  final bool readOnly;
  final bool wordWrap;
  final EdgeInsetsGeometry padding;
  final dynamic scrollController;
  final CodeEditorStyle style;
  final Widget? sperator;
  final dynamic indicatorBuilder;

  const CodeEditorWithContextMenu({
    super.key,
    required this.controller,
    this.readOnly = true,
    this.wordWrap = false,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 24, 48),
    required this.scrollController,
    required this.style,
    this.sperator,
    this.indicatorBuilder,
  });

  @override
  State<CodeEditorWithContextMenu> createState() => _CodeEditorWithContextMenuState();
}

class _CodeEditorWithContextMenuState extends State<CodeEditorWithContextMenu> {
  late CodeEditorContextMenuController _contextMenuController;

  @override
  void initState() {
    super.initState();
    _contextMenuController = CodeEditorContextMenuController(
      context: context,
      editingController: widget.controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (LongPressStartDetails details) {
        // Show context menu on long press (mobile) with position details
        _contextMenuController.showContextMenu(details.globalPosition, readOnly: widget.readOnly);
      },
      onSecondaryTapDown: (TapDownDetails details) {
        // Show context menu on right-click (desktop)
        _contextMenuController.showContextMenu(details.globalPosition, readOnly: widget.readOnly);
      },
      child: CodeEditor(
        controller: widget.controller,
        readOnly: widget.readOnly,
        wordWrap: widget.wordWrap,
        padding: widget.padding,
        scrollController: widget.scrollController,
        style: widget.style,
        sperator: widget.sperator,
        indicatorBuilder: widget.indicatorBuilder,
      ),
    );
  }
}