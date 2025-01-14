import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'common.dart';
import 'pan_gesture_detector.dart';
import 'selection.dart';
import 'selection_controls.dart';

class SelectableBuildHelper {
  bool usingCupertinoControls = false;
  SelectionControls? controls;

  bool showPopupMenu = false;
  bool isScrolling = false;

  bool showParagraphRects = false; // kDebugMode;

  OverlayEntry? _popupMenuOverlayEntry;

  void maybeAutoscroll(
      ScrollController? scrollController,
      GlobalKey globalKey,
      Offset? selectionPt,
      double maxY,
      double topOverlayHeight,
      ) {
    if (scrollController?.hasOneClient ?? false) {
      _autoscroll(
          scrollController, globalKey, selectionPt, maxY, topOverlayHeight);
    }
  }

  /// Autoscrolls if the drag point is near the top or bottom of the viewport.
  void _autoscroll(ScrollController? scrollController, GlobalKey globalKey,
      Offset? dragPt, double maxY, double topOverlayHeight) {
    assert(scrollController?.hasOneClient ?? false);

    final renderObject = globalKey.currentContext!.findRenderObject();
    if (!(renderObject is RenderBox && renderObject.hasSize)) {
      return;
    }

    final vp = RenderAbstractViewport.maybeOf(renderObject);
    assert(vp != null);
    if (vp == null) return;

    final renderObjScrollPos =
        renderObject.getTransformTo(vp).getTranslation().y;
    final renderObjectTop = scrollController!.offset + renderObjScrollPos;
    final renderObjectBottom = maxY;
    final scrollOffset = -renderObjScrollPos;
    final viewportExtent = scrollController.position.viewportDimension;

    final autoscrollAreaHeight = viewportExtent / 10.0;
    const scrollDistanceMultiplier = 3.0;

    final y = dragPt!.dy;
    var scrollDelta = 0.0;

    if (scrollOffset > -topOverlayHeight &&
        y < scrollOffset + autoscrollAreaHeight + topOverlayHeight) {
      scrollDelta =
          y - (scrollOffset + autoscrollAreaHeight + topOverlayHeight);
    } else if (y > scrollOffset + viewportExtent - autoscrollAreaHeight) {
      scrollDelta = y - (scrollOffset + viewportExtent - autoscrollAreaHeight);
    }

    if (scrollDelta != 0.0) {
      final newScrollOffset = math.min(
          renderObjectBottom - viewportExtent + 100.0,
          math.max(-renderObjectTop,
              scrollOffset + (scrollDelta * scrollDistanceMultiplier)));
      unawaited(scrollController.animateTo(newScrollOffset + renderObjectTop,
          duration: const Duration(milliseconds: 250), curve: Curves.ease));
    }
  }

  /// Builds the selection handles and optionally the popup menu.
  List<Widget> buildSelectionControls(
      Selection? selection,
      BuildContext context,
      BoxConstraints constraints,
      SelectionDelegate selectionDelegate,
      GlobalKey mainKey,
      ScrollController? scrollController,
      double topOverlayHeight,
      bool useExperimentalPopupMenu,
      ) {
    if (selection == null || !selection.isTextSelected) {
      _removePopupMenu();
      return [];
    }

    final startLineHeight = selection.rects!.first.height;
    final endLineHeight = selection.rects!.last.height;

    final isRtl = Directionality.maybeOf(context) == TextDirection.rtl;

    final startHandleType = isRtl && !usingCupertinoControls
        ? TextSelectionHandleType.right
        : TextSelectionHandleType.left;
    final endHandleType = isRtl && !usingCupertinoControls
        ? TextSelectionHandleType.left
        : TextSelectionHandleType.right;

    final startOffset =
    controls!.getHandleAnchor(startHandleType, startLineHeight);
    final endOffset = controls!.getHandleAnchor(endHandleType, endLineHeight);

    final startHandlePt = isRtl
        ? selection.rects!.first.bottomRight
        : selection.rects!.first.bottomLeft;
    final endHandlePt = isRtl
        ? selection.rects!.last.bottomLeft
        : selection.rects!.last.bottomRight;

    final startPt = Offset(
        startHandlePt.dx - startOffset.dx, startHandlePt.dy - startOffset.dy);
    final endPt = Offset(endHandlePt.dx - endOffset.dx, endHandlePt.dy);

    final startSize = controls!.getHandleSize(startLineHeight);
    final endSize = controls!.getHandleSize(endLineHeight);

    final startRect =
    Rect.fromLTWH(startPt.dx, startPt.dy, startSize.width, startSize.height)
        .inflate(20);
    final endRect =
    Rect.fromLTWH(endPt.dx, endPt.dy, endSize.width, endSize.height)
        .inflate(20);

    final isShowingPopupMenu = (showPopupMenu && !isScrolling);

    if (isShowingPopupMenu) {
      _showPopupMenu(context, selection.rects!, selectionDelegate, constraints,
          topOverlayHeight, useExperimentalPopupMenu);
    }

    return [
      Positioned.fromRect(
        rect: startRect,
        child: _SelectionHandle(
          delegate: selectionDelegate,
          handleType: SelectionHandleType.left,
          mainKey: mainKey,
          child:
          controls!.buildHandle(context, startHandleType, startLineHeight),
        ),
      ),
      Positioned.fromRect(
        rect: endRect,
        child: _SelectionHandle(
          delegate: selectionDelegate,
          handleType: SelectionHandleType.right,
          mainKey: mainKey,
          child: controls!.buildHandle(context, endHandleType, endLineHeight),
        ),
      ),
    ];
  }

  void _showPopupMenu(BuildContext context, List<Rect> selectionRects,
      SelectionDelegate delegate, BoxConstraints constraints,
      double topOverlayHeight, bool useExperimentalPopupMenu) {
    _removePopupMenu(); // Remove any existing overlay entry.

    final viewport = Rect.fromLTWH(
        0, 0, constraints.maxWidth, constraints.maxHeight);

    final menu = controls!.buildPopupMenu(
        context, viewport, selectionRects, delegate, topOverlayHeight, false);

    _popupMenuOverlayEntry = OverlayEntry(builder: (context) => menu);
    Overlay.of(context).insert(_popupMenuOverlayEntry!);
  }

  void _removePopupMenu() {
    _popupMenuOverlayEntry?.remove();
    _popupMenuOverlayEntry = null;
  }
}

class _SelectionHandle extends StatelessWidget {
  const _SelectionHandle({
    required this.delegate,
    required this.handleType,
    required this.child,
    required this.mainKey,
  });

  final SelectionDelegate delegate;
  final SelectionHandleType handleType;
  final Widget child;
  final GlobalKey mainKey;

  void _onPanStart(DragStartDetails details) =>
      _onPan(details.globalPosition, details.kind);

  void _onPanUpdate(DragUpdateDetails details) =>
      _onPan(details.globalPosition, null);

  void _onPan(Offset globalPosition, PointerDeviceKind? pointerKind) {
    final mainKeyRenderObject = mainKey.currentContext!.findRenderObject();
    if (mainKeyRenderObject is RenderBox) {
      final offset = mainKeyRenderObject.globalToLocal(globalPosition);
      delegate.onDragSelectionHandleUpdate(handleType, offset,
          kind: pointerKind);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    delegate.onDragSelectionHandleEnd(handleType);
  }

  void _onPanCancel() {
    delegate.onDragSelectionHandleEnd(handleType);
  }

  @override
  Widget build(BuildContext context) {
    return SelectablePanGestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      dragStartBehavior: DragStartBehavior.down,
      behavior: HitTestBehavior.translucent,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}
