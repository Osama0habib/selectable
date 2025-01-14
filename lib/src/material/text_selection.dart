import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../selection_controls.dart';

final SelectionControls exMaterialTextSelectionControls =
_MaterialTextSelectionControls();

const double _kHandleSize = 22.0;
const double _kButtonPadding = 10.0;

class _MaterialTextSelectionControls extends SelectionControls {
  OverlayEntry? _overlayEntry;

  /// Shows the context menu as an overlay.
  void _showOverlay(BuildContext context, Offset position, Widget menu) {
    _hideOverlay(); // Remove any existing overlay before showing a new one.

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            elevation: 4.0,
            child: menu,
          ),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Overlay.of(context).insert(_overlayEntry!);
    });
  }

  /// Hides the context menu overlay.
  void _hideOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  Widget buildPopupMenu(
      BuildContext context,
      Rect viewport,
      List<Rect>? selectionRects,
      SelectionDelegate delegate,
      double topOverlayHeight,
      bool useExperimentalPopupMenu,
      ) {
    final Offset position = Offset(
      (selectionRects!.first.left + selectionRects.last.right) / 2,
      selectionRects.first.top - 50, // Adjust offset as needed.
    );

    final menu = _TextSelectionPopupMenu(delegate: delegate);

    _showOverlay(context, position, menu);

    // Return a placeholder widget, as the actual menu is now in the overlay.
    return const SizedBox();
  }

  @override
  Widget buildHandle(
      BuildContext context, TextSelectionHandleType type, double textHeight) {
    final ThemeData theme = Theme.of(context);
    final Color handleColor =
        TextSelectionTheme.of(context).selectionHandleColor ??
            theme.colorScheme.primary;
    final Widget handle = SizedBox(
      width: _kHandleSize,
      height: _kHandleSize,
      child: CustomPaint(
        painter: _TextSelectionHandlePainter(color: handleColor),
      ),
    );

    switch (type) {
      case TextSelectionHandleType.left:
        return Transform.rotate(angle: math.pi / 2.0, child: handle);
      case TextSelectionHandleType.right:
        return handle;
      case TextSelectionHandleType.collapsed:
        return Transform.rotate(angle: math.pi / 4.0, child: handle);
    }
  }

  @override
  Size getHandleSize(double textLineHeight) => const Size(_kHandleSize, _kHandleSize);

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    switch (type) {
      case TextSelectionHandleType.left:
        return const Offset(_kHandleSize, 0);
      case TextSelectionHandleType.right:
        return Offset.zero;
      case TextSelectionHandleType.collapsed:
        return const Offset(_kHandleSize / 2, -4);
    }
  }
}

class _TextSelectionHandlePainter extends CustomPainter {
  const _TextSelectionHandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double radius = size.width / 2.0;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    canvas.drawRect(Rect.fromLTWH(0.0, 0.0, radius, radius), paint);
  }

  @override
  bool shouldRepaint(_TextSelectionHandlePainter oldPainter) {
    return color != oldPainter.color;
  }
}

class _TextSelectionPopupMenu extends StatelessWidget {
  const _TextSelectionPopupMenu({required this.delegate});

  final SelectionDelegate delegate;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final items = delegate.menuItems
        .where((item) => item.isEnabled!(delegate.controller))
        .map((item) => _PopupMenuButton(
      icon: item.icon,
      title: item.title ?? '',
      isDarkMode: isDarkMode,
      onPressed: () => item.handler!(delegate.controller),
    ))
        .toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Material(
      elevation: 4.0,
      color: Theme.of(context).canvasColor,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 44.0,
        padding: const EdgeInsets.symmetric(horizontal: _kButtonPadding),
        child: Row(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}

class _PopupMenuButton extends StatelessWidget {
  const _PopupMenuButton({
    this.icon,
    required this.title,
    required this.isDarkMode,
    required this.onPressed,
  });

  final IconData? icon;
  final String title;
  final bool isDarkMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: _kButtonPadding),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 20.0,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          Text(
            icon == null ? title : ' $title',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
