import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../selection_controls.dart';

final SelectionControls exCupertinoTextSelectionControls =
_CupertinoTextSelectionControls();

const double _kHandleSize = 22.0;
const double _kArrowHeight = 7.0;
const double _kArrowWidth = 14.0;

class _CupertinoTextSelectionControls extends SelectionControls {
  OverlayEntry? _overlayEntry;

  /// Shows the context menu as an overlay.
  void _showOverlay(BuildContext context, Offset position, Widget menu) {
    _removeOverlay(); // Remove any existing overlay before showing a new one.

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx,
          top: position.dy,
          child: menu,
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Hides the context menu overlay.
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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
    final double arrowTipX =
    ((selectionRects!.first.left + selectionRects.last.right) / 2)
        .clamp(26.0, viewport.width - 26.0);
    final double menuTopY = selectionRects.first.top - 50;

    final menu = _CupertinoTextSelectionPopupMenu(
      delegate: delegate,
      arrowTipX: arrowTipX,
    );

    _showOverlay(context, Offset(arrowTipX - 50, menuTopY), menu);

    // Return a placeholder widget, as the actual menu is now in the overlay.
    return const SizedBox();
  }

  @override
  Widget buildHandle(
      BuildContext context, TextSelectionHandleType type, double textHeight) {
    final Widget handle = SizedBox(
      height: _kHandleSize,
      width: _kHandleSize,
      child: CustomPaint(
        painter: _TextSelectionHandlePainter(
          color: CupertinoTheme.of(context).primaryColor,
        ),
      ),
    );

    switch (type) {
      case TextSelectionHandleType.left:
        return handle;
      case TextSelectionHandleType.right:
        return Transform.rotate(angle: math.pi, child: handle);
      case TextSelectionHandleType.collapsed:
        return const SizedBox.shrink();
    }
  }

  @override
  Size getHandleSize(double textLineHeight) => const Size(_kHandleSize, _kHandleSize);

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    switch (type) {
      case TextSelectionHandleType.left:
        return Offset(_kHandleSize / 2, _kHandleSize);
      case TextSelectionHandleType.right:
        return Offset(_kHandleSize / 2, _kHandleSize);
      case TextSelectionHandleType.collapsed:
        return Offset(_kHandleSize / 2, _kHandleSize / 2);
    }
  }
}

class _CupertinoTextSelectionPopupMenu extends StatelessWidget {
  const _CupertinoTextSelectionPopupMenu({
    required this.delegate,
    required this.arrowTipX,
  });

  final SelectionDelegate delegate;
  final double arrowTipX;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = delegate.menuItems
        .where((item) => item.isEnabled!(delegate.controller))
        .map((item) => CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xEB202020),
      onPressed: () => item.handler!(delegate.controller),
      child: Text(
        item.title ?? '',
        style: const TextStyle(
          fontSize: 14,
          color: CupertinoColors.white,
        ),
      ),
    ))
        .toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomPaint(
            painter: _ArrowPainter(),
            size: const Size(_kArrowWidth, _kArrowHeight),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xEB202020),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: items,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = const Color(0xEB202020);
    final Path path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TextSelectionHandlePainter extends CustomPainter {
  const _TextSelectionHandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
