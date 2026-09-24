import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/puzzle_piece.dart';

class _PiecePainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;
  final bool placed;

  _PiecePainter({required this.image, required this.srcRect, required this.placed});

  @override
  void paint(Canvas canvas, Size size) {
    final dstRect = Offset.zero & size;
    canvas.drawImageRect(image, srcRect, dstRect, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(covariant _PiecePainter oldDelegate) {
    return oldDelegate.srcRect != srcRect || oldDelegate.placed != placed || oldDelegate.image != image;
  }
}

/// A single draggable jigsaw piece. Renders its own optimistic position
/// while being dragged, and otherwise follows the authoritative position
/// coming from [piece] (server state via GameService).
class PuzzlePieceWidget extends StatefulWidget {
  final PuzzlePiece piece;
  final ui.Image image;
  final Rect srcRect;
  final double renderSize;
  final double canvasOffsetX;
  final double canvasOffsetY;
  final double canvasWidth;
  final double canvasHeight;
  final bool isActive;
  final double Function() currentScale;
  final void Function(String pieceId) onPickUp;
  final void Function(String pieceId, double x, double y) onMove;
  final void Function(String pieceId, double x, double y) onDrop;

  const PuzzlePieceWidget({
    super.key,
    required this.piece,
    required this.image,
    required this.srcRect,
    required this.renderSize,
    required this.canvasOffsetX,
    required this.canvasOffsetY,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.isActive,
    required this.currentScale,
    required this.onPickUp,
    required this.onMove,
    required this.onDrop,
  });

  @override
  State<PuzzlePieceWidget> createState() => _PuzzlePieceWidgetState();
}

class _PuzzlePieceWidgetState extends State<PuzzlePieceWidget> {
  late double _x;
  late double _y;
  bool _dragging = false;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _x = widget.piece.x;
    _y = widget.piece.y;
    _clamp();
  }

  @override
  void didUpdateWidget(covariant PuzzlePieceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) {
      _x = widget.piece.x;
      _y = widget.piece.y;
      _clamp();
    }
  }

  // _x/_y are board-local (can be negative, into the scatter padding), and
  // rendered at canvasOffsetX/Y + _x/_y. Clamp so that rendered position
  // stays within [0, canvasWidth/Height], i.e. _x in
  // [-canvasOffsetX, canvasWidth - canvasOffsetX - renderSize].
  double get _minX => -widget.canvasOffsetX;
  double get _maxX => widget.canvasWidth - widget.canvasOffsetX - widget.renderSize;
  double get _minY => -widget.canvasOffsetY;
  double get _maxY => widget.canvasHeight - widget.canvasOffsetY - widget.renderSize;

  void _clamp() {
    _x = _x.clamp(_minX, _maxX < _minX ? _minX : _maxX);
    _y = _y.clamp(_minY, _maxY < _minY ? _minY : _maxY);
  }

  void _maybeSendMove() {
    final now = DateTime.now();
    if (now.difference(_lastSent).inMilliseconds >= 40) {
      _lastSent = now;
      widget.onMove(widget.piece.id, _x, _y);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.piece.placed;

    return Positioned(
      left: widget.canvasOffsetX + _x,
      top: widget.canvasOffsetY + _y,
      width: widget.renderSize,
      height: widget.renderSize,
      // Uses raw pointer events (Listener) instead of GestureDetector's pan
      // recognizer: a GestureDetector here would compete in the same gesture
      // arena as the ancestor InteractiveViewer's scale recognizer and can
      // lose, silently swallowing the drag. Listener bypasses the arena
      // entirely, so it isn't affected by that ancestor.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: locked
            ? null
            : (_) {
                setState(() => _dragging = true);
                widget.onPickUp(widget.piece.id);
              },
        onPointerMove: locked
            ? null
            : (event) {
                final scale = widget.currentScale();
                setState(() {
                  _x += event.delta.dx / scale;
                  _y += event.delta.dy / scale;
                  _clamp();
                });
                _maybeSendMove();
              },
        onPointerUp: locked
            ? null
            : (_) {
                setState(() => _dragging = false);
                widget.onDrop(widget.piece.id, _x, _y);
              },
        onPointerCancel: locked
            ? null
            : (_) {
                setState(() => _dragging = false);
                widget.onDrop(widget.piece.id, _x, _y);
              },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: locked ? Colors.transparent : Colors.white.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: locked || _dragging == false && !widget.isActive
                ? const []
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: CustomPaint(
            size: Size.square(widget.renderSize),
            painter: _PiecePainter(image: widget.image, srcRect: widget.srcRect, placed: locked),
          ),
        ),
      ),
    );
  }
}
