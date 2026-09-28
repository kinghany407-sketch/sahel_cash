import 'dart:math' as math;

import 'package:flutter/material.dart';

class DraggableDialogController {
  void Function(Offset delta)? _onDragUpdate;
  void Function(bool isDragging)? _onDragStateChanged;

  void _attach(
    void Function(Offset delta) onDragUpdate,
    void Function(bool isDragging) onDragStateChanged,
  ) {
    _onDragUpdate = onDragUpdate;
    _onDragStateChanged = onDragStateChanged;
  }

  void _clear() {
    _onDragUpdate = null;
    _onDragStateChanged = null;
  }

  Widget dragHandle({required Widget child}) {
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _onDragStateChanged?.call(true),
        onPanUpdate: (details) {
          _onDragUpdate?.call(details.delta);
        },
        onPanEnd: (_) => _onDragStateChanged?.call(false),
        onPanCancel: () => _onDragStateChanged?.call(false),
        child: child,
      ),
    );
  }

  void dispose() {
    _clear();
  }
}

class DraggableDialog extends StatefulWidget {
  final Widget child;
  final DraggableDialogController? controller;
  final String? title;
  final double? width;
  final double? height;

  const DraggableDialog({
    super.key,
    required this.child,
    this.controller,
    this.title,
    this.width,
    this.height,
  });

  @override
  State<DraggableDialog> createState() => _DraggableDialogState();
}

class _DraggableDialogState extends State<DraggableDialog> {
  Offset _offset = Offset.zero;
  BoxConstraints? _constraints;
  bool _isDragging = false;

  void _moveDialog(Offset delta) {
    final constraints = _constraints;
    if (constraints == null) return;

    final dialogWidth = widget.width ?? 500.0;
    final dialogHeight = widget.height ?? 600.0;

    final maxOffsetX = math.max(0.0, (constraints.maxWidth - dialogWidth) / 2);
    final maxOffsetY = math.max(0.0, (constraints.maxHeight - dialogHeight) / 2);

    setState(() {
      _offset = Offset(
        (_offset.dx + delta.dx).clamp(-maxOffsetX, maxOffsetX),
        (_offset.dy + delta.dy).clamp(-maxOffsetY, maxOffsetY),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant DraggableDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._clear();
      _attachController(widget.controller);
    }
  }

  void _attachController(DraggableDialogController? controller) {
    controller?._attach(
      _moveDialog,
      (dragging) {
        if (mounted) setState(() => _isDragging = dragging);
      },
    );
  }

  @override
  void dispose() {
    widget.controller?._clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _constraints = constraints;
        final dialogWidth = widget.width ?? 500.0;
        final dialogHeight = widget.height ?? 600.0;

        final maxOffsetX = math.max(0.0, (constraints.maxWidth - dialogWidth) / 2);
        final maxOffsetY = math.max(0.0, (constraints.maxHeight - dialogHeight) / 2);

        final clampedOffset = Offset(
          _offset.dx.clamp(-maxOffsetX, maxOffsetX),
          _offset.dy.clamp(-maxOffsetY, maxOffsetY),
        );

        final left = math.max(0.0, (constraints.maxWidth - dialogWidth) / 2 + clampedOffset.dx);
        final top = math.max(0.0, (constraints.maxHeight - dialogHeight) / 2 + clampedOffset.dy);

        final headerContent = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              // Back Arrow (RTL: on the right)
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 20,
              ),
              const SizedBox(width: 8),
              // Title (centered)
              Expanded(
                child: Text(
                  widget.title ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              // Close icon (RTL: on the left)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 20,
              ),
            ],
          ),
        );

        Widget headerWidget;
        if (widget.controller != null) {
          headerWidget = widget.controller!.dragHandle(child: headerContent);
        } else {
          headerWidget = MouseRegion(
            cursor: SystemMouseCursors.move,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanUpdate: (details) => _moveDialog(details.delta),
              onPanEnd: (_) => setState(() => _isDragging = false),
              onPanCancel: () => setState(() => _isDragging = false),
              child: headerContent,
            ),
          );
        }

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: dialogWidth,
              height: dialogHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      headerWidget,
                      Expanded(
                        child: IgnorePointer(
                          ignoring: _isDragging,
                          child: widget.child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}