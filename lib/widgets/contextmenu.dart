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
    showMenu(
        requestFocus: false,
        context: context,
        position: RelativeRect.fromLTRB(
          anchors.primaryAnchor.dx,
          anchors.primaryAnchor.dy,
          MediaQuery.of(context).size.width - anchors.primaryAnchor.dx,
          MediaQuery.of(context).size.height - anchors.primaryAnchor.dy,
        ),
        items: [
          // ContextMenuItemWidget(
          //   text: 'Cut',
          //   onTap: () {
          //     controller.cut();
          //   },
          // ),
          ContextMenuItemWidget(
            text: 'Copy',
            onTap: () {
              controller.copy();
            },
          ),
          // ContextMenuItemWidget(
          //   text: 'Paste',
          //   onTap: () {
          //     controller.paste();
          //   },
          // ),
          ContextMenuItemWidget(
            text: 'Select All',
            onTap: () {
              controller.selectAll();
            },
          ),
        ]);
  }
}
