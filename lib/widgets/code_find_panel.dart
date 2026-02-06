import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'dart:math';

const EdgeInsetsGeometry _kDefaultFindMargin = EdgeInsets.only(right: 4);

const double _kDefaultFindPanelHeight = 40; // Reduced from 54
const double _kDefaultReplacePanelHeight = _kDefaultFindPanelHeight * 2;
const double _kDefaultFindIconSize = 14; // Reduced from 16
const double _kDefaultFindIconWidth = 24; // Reduced from 30
const double _kDefaultFindIconHeight = 24; // Reduced from 30
const double _kDefaultFindInputFontSize = 12; // Reduced from 13
const double _kDefaultFindResultFontSize = 11; // Reduced from 12
const EdgeInsetsGeometry _kDefaultFindPadding =
    EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2);
const EdgeInsetsGeometry _kDefaultFindInputContentPadding =
    EdgeInsets.symmetric(
  vertical: 8,
  horizontal: 8,
);

class CodeFindPanelView extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController controller;
  final EdgeInsetsGeometry margin;
  final bool readOnly;
  final Color? iconColor;
  final Color? iconSelectedColor;
  final double iconSize;
  final double inputFontSize;
  final double resultFontSize;
  final Color? inputTextColor;
  final Color? resultFontColor;
  final EdgeInsetsGeometry padding;
  final InputDecoration decoration;

  const CodeFindPanelView(
      {super.key,
      required this.controller,
      this.margin = _kDefaultFindMargin,
      required this.readOnly,
      this.iconSelectedColor,
      this.iconColor,
      this.iconSize = _kDefaultFindIconSize,
      this.inputFontSize = _kDefaultFindInputFontSize,
      this.resultFontSize = _kDefaultFindResultFontSize,
      this.inputTextColor,
      this.resultFontColor,
      this.padding = _kDefaultFindPadding,
      this.decoration = const InputDecoration(
        filled: true,
        contentPadding: _kDefaultFindInputContentPadding,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            gapPadding: 0), // Radius 6
      )});

  @override
  Size get preferredSize => Size(
      double.infinity,
      controller.value == null
          ? 0
          : ((controller.value!.replaceMode
                  ? _kDefaultReplacePanelHeight
                  : _kDefaultFindPanelHeight) +
              margin.vertical));

  @override
  Widget build(BuildContext context) {
    if (controller.value == null) {
      return const SizedBox(width: 0, height: 0);
    }
    return Container(
        margin: margin,
        alignment: Alignment.topRight,
        // height: preferredSize.height, // Allow dynamic height
        child: Column(
          children: [
            _buildFindInputView(context),
            if (controller.value!.replaceMode) _buildReplaceInputView(context),
          ],
        ));
  }

  Widget _buildFindInputView(BuildContext context) {
    final CodeFindValue value = controller.value!;
    final String result;
    if (value.result == null) {
      result = 'none';
    } else {
      result = '${value.result!.index + 1}/${value.result!.matches.length}';
    }
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
              // height: _kDefaultFindPanelHeight, // Remove fixed height
              child: Stack(
            alignment: Alignment.center,
            children: [
              _buildTextField(
                  context: context,
                  controller: controller.findInputController,
                  focusNode: controller.findInputFocusNode,
                  iconsWidth: _kDefaultFindIconWidth * 1.5,
                  onSubmitted: (_) {
                    controller.nextMatch();
                    controller.findInputFocusNode.requestFocus();
                  }),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildCheckIcon(
                      context: context,
                      icon: Icons.abc,
                      checked: value.option.caseSensitive,
                      tooltip: 'Match Case',
                      onPressed: () {
                        controller.toggleCaseSensitive();
                      }),
                  SizedBox(width: 12),
                  // _buildCheckText(
                  //     context: context,
                  //     text: '.*',
                  //     checked: value.option.regex,
                  //     onPressed: () {
                  //       controller.toggleRegex();
                  //     })
                ],
              )
            ],
          )),
        ),
        Text(result,
            style: TextStyle(color: resultFontColor, fontSize: resultFontSize)),
        Expanded(
          flex: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconButton(
                  onPressed: value.result == null
                      ? null
                      : () {
                          controller.previousMatch();
                        },
                  icon: Icons.arrow_upward,
                  tooltip: 'Previous'),
              _buildIconButton(
                  onPressed: value.result == null
                      ? null
                      : () {
                          controller.nextMatch();
                        },
                  icon: Icons.arrow_downward,
                  tooltip: 'Next'),
              _buildIconButton(
                  onPressed: () {
                    controller.close();
                  },
                  icon: Icons.close,
                  tooltip: 'Close')
            ],
          ),
        )
      ],
    );
  }

  Widget _buildReplaceInputView(BuildContext context) {
    final CodeFindValue value = controller.value!;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            // height: _kDefaultFindPanelHeight, // Remove fixed height
            child: _buildTextField(
              context: context,
              controller: controller.replaceInputController,
              focusNode: controller.replaceInputFocusNode,
              onSubmitted: (_) {
                controller.replaceMatch();
                controller.replaceInputFocusNode.requestFocus();
              },
            ),
          ),
        ),
        _buildIconButton(
            onPressed: value.result == null
                ? null
                : () {
                    controller.replaceMatch();
                  },
            icon: Icons.done,
            tooltip: 'Replace'),
        _buildIconButton(
            onPressed: value.result == null
                ? null
                : () {
                    controller.replaceAllMatches();
                  },
            icon: Icons.done_all,
            tooltip: 'Replace All')
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    double iconsWidth = 0,
    ValueChanged<String>? onSubmitted,
  }) {
    return Padding(
      padding: padding,
      child: TextField(
        maxLines: 1,
        focusNode: focusNode,
        // textInputAction: TextInputAction.next, // Removed to prevent focus jumping
        style: TextStyle(color: inputTextColor, fontSize: inputFontSize),
        decoration: decoration.copyWith(
            isDense: true,
            contentPadding: (decoration.contentPadding ?? EdgeInsets.zero)
                .add(EdgeInsets.only(right: iconsWidth))),
        controller: controller,
        onSubmitted: onSubmitted,
      ),
    );
  }

  Widget _buildCheckIcon({
    required BuildContext context,
    required IconData icon,
    required bool checked,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final Color selectedColor =
        iconSelectedColor ?? Theme.of(context).primaryColor;
    return GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(
              icon,
              size: iconSize,
              color: checked ? selectedColor : iconColor,
            ),
          ),
        ));
  }

  Widget _buildIconButton(
      {required IconData icon, VoidCallback? onPressed, String? tooltip}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: iconSize,
      ),
      padding: const EdgeInsets.all(2),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(
          maxWidth: _kDefaultFindIconWidth, maxHeight: _kDefaultFindIconHeight),
      tooltip: tooltip,
      splashRadius: max(_kDefaultFindIconWidth, _kDefaultFindIconHeight) / 2,
    );
  }
}
