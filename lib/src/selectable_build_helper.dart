// Copyright (c) 2021 Ron Booth. All rights reserved.
// Use of this source code is governed by a license that can be found in the
// LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  bool showParagraphRects = false; //kDebugMode;

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

  void _autoscroll(
      ScrollController? scrollController,
      GlobalKey globalKey,
      Offset? dragPt,
      double maxY,
      double topOverlayHeight,
      ) {
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
        math.max(
          -renderObjectTop,
          scrollOffset + (scrollDelta * scrollDistanceMultiplier),
        ),
      );
      unawaited(scrollController.animateTo(
        newScrollOffset + renderObjectTop,
        duration: const Duration(milliseconds: 250),
        curve: Curves.ease,
      ));
    }
  }

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
    if (selection == null || !selection.isTextSelected) return [];

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
    final endHandlePt = usingCupertinoControls
        ? (isRtl
        ? selection.rects!.last.topLeft
        : selection.rects!.last.topRight)
        : (isRtl
        ? selection.rects!.last.bottomLeft
        : selection.rects!.last.bottomRight);

    final startPt = Offset(
      startHandlePt.dx - startOffset.dx,
      startHandlePt.dy - startOffset.dy,
    );
    final endPt = Offset(endHandlePt.dx - endOffset.dx, endHandlePt.dy);

    final startSize = controls!.getHandleSize(startLineHeight);
    final endSize = controls!.getHandleSize(endLineHeight);

    final startRect =
    Rect.fromLTWH(startPt.dx, startPt.dy, startSize.width, startSize.height)
        .inflate(20);
    final endRect =
    Rect.fromLTWH(endPt.dx, endPt.dy, endSize.width, endSize.height)
        .inflate(20);

    if (showPopupMenu && !isScrolling) {
      final popupMenu = _PopupMenu(
        constraints: constraints,
        controls: controls!,
        mainKey: mainKey,
        scrollController: scrollController,
        selectionDelegate: selectionDelegate,
        selectionRects: selection.rects!,
        topOverlayHeight: topOverlayHeight,
        isShowing: showPopupMenu,
        useExperimentalPopupMenu: useExperimentalPopupMenu,
      );
      return [popupMenu];
    }

    return [
      Positioned.fromRect(
        rect: startRect,
        child: _SelectionHandle(
          delegate: selectionDelegate,
          handleType: SelectionHandleType.left,
          mainKey: mainKey,
          child: controls!.buildHandle(
            context,
            startHandleType,
            startLineHeight,
          ),
        ),
      ),
      Positioned.fromRect(
        rect: endRect,
        child: _SelectionHandle(
          delegate: selectionDelegate,
          handleType: SelectionHandleType.right,
          mainKey: mainKey,
          child: controls!.buildHandle(
            context,
            endHandleType,
            endLineHeight,
          ),
        ),
      ),
    ];
  }
}

class _PopupMenu extends StatefulWidget {
  const _PopupMenu({
    required this.constraints,
    required this.controls,
    required this.mainKey,
    required this.scrollController,
    required this.selectionDelegate,
    required this.selectionRects,
    required this.topOverlayHeight,
    required this.isShowing,
    required this.useExperimentalPopupMenu,
  });

  final BoxConstraints constraints;
  final SelectionControls controls;
  final GlobalKey mainKey;
  final ScrollController? scrollController;
  final SelectionDelegate selectionDelegate;
  final List<Rect> selectionRects;
  final double topOverlayHeight;
  final bool isShowing;
  final bool useExperimentalPopupMenu;

  @override
  _PopupMenuState createState() => _PopupMenuState();
}

class _PopupMenuState extends State<_PopupMenu> {
  OverlayEntry? _overlayEntry;

  @override
  void didUpdateWidget(covariant _PopupMenu oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isShowing) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = _buildOverlay();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Overlay.of(context).insert(_overlayEntry!);
      });
    }
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }
  }

  OverlayEntry _buildOverlay() {
    Rect? viewport = Rect.fromLTWH(
      0,
      0,
      widget.constraints.maxWidth,
      widget.constraints.maxHeight,
    );

    if (widget.scrollController?.hasOneClient ?? false) {
      final renderObject = widget.mainKey.currentContext!.findRenderObject();
      final vp = RenderAbstractViewport.maybeOf(renderObject);
      if (vp != null) {
        try {
          final renderObjScrollPos =
              renderObject!.getTransformTo(vp).getTranslation().y;
          final scrollOffset = -renderObjScrollPos + widget.topOverlayHeight;
          final viewportExtent =
              widget.scrollController!.position.viewportDimension -
                  widget.topOverlayHeight;
          viewport = Rect.fromLTWH(
            0,
            scrollOffset,
            viewport.width,
            viewportExtent,
          ).intersect(viewport);
        } catch (e) {
          print('Error building popup menu viewport: $e');
        }
      }
    }

    final popupMenu = widget.controls.buildPopupMenu(
      context,
      viewport!,
      widget.selectionRects,
      widget.selectionDelegate,
      widget.topOverlayHeight,
      widget.useExperimentalPopupMenu,
    );

    return OverlayEntry(
      builder: (context) => Positioned(
        left: viewport?.left,
        top: viewport?.top,
        child: Material(
          elevation: 4,
          child: popupMenu,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
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
