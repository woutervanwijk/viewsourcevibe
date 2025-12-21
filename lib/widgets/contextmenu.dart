import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

class ContextMenuItemWidget extends PopupMenuItem<void>
    implements PreferredSizeWidget {
  ContextMenuItemWidget({
    super.key,
    required String text,
    required VoidCallback super.onTap,
  }) : super(child: Text(text));

  @override
  Size get preferredSize => const Size(150, 25);
}

class ContextMenuControllerImpl implements SelectionToolbarController {
  const ContextMenuControllerImpl();

  @override
  void hide(BuildContext context) {}

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // The anchors and renderRect from re_editor are relative to the CodeEditor widget
    final Rect localRect = renderRect ??
        Rect.fromPoints(
          anchors.primaryAnchor,
          anchors.secondaryAnchor ?? anchors.primaryAnchor,
        );

    final Offset globalTopLeft = renderBox.localToGlobal(localRect.topLeft);
    final Offset globalBottomRight =
        renderBox.localToGlobal(localRect.bottomRight);
    final Rect globalRect = Rect.fromPoints(globalTopLeft, globalBottomRight);

    // Get the horizontal center of the selection
    final double centerX = globalRect.center.dx;
    // ContextMenuItemWidget has preferredSize of 150 width
    const double menuWidth = 150.0;

    // Get the overlay's render box to determine the container size
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Calculate the left position to center the menu horizontally
    // Offset by half the width, and clamp to screen boundaries
    final double left =
        (centerX - (menuWidth / 2)).clamp(0.0, overlay.size.width - menuWidth);

    showMenu(
        requestFocus: false,
        context: context,
        position: RelativeRect.fromLTRB(
          left,
          globalRect.top,
          overlay.size.width - left - menuWidth,
          overlay.size.height - globalRect.bottom,
        ),
        items: [
          ContextMenuItemWidget(
            text: 'Copy',
            onTap: () {
              controller.copy();
            },
          ),
          ContextMenuItemWidget(
            text: 'Select All',
            onTap: () {
              controller.selectAll();
            },
          ),
        ]);
  }
}
