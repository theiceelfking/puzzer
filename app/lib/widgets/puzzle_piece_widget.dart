import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/piece_shape.dart';
import '../models/puzzle_piece.dart';

class _PiecePainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;
  final double pieceSize;
  final Path path;
  final Color outlineColor;
  final double outlineWidth;
  final bool elevated;

  _PiecePainter({
    required this.image,
    required this.srcRect,
    required this.pieceSize,
    required this.path,
    required this.outlineColor,
    required this.outlineWidth,
    required this.elevated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (elevated) {
      canvas.drawShadow(path.shift(const Offset(0, 3)), Colors.black, 6, false);
    }
    canvas.save();
    canvas.clipPath(path);
    // Draw the whole image scaled so that this piece's cell (srcRect) lands
    // on the square at (pad, pad); the clip keeps only the piece's shape,
    // including tabs that reach into neighbouring cells.
    final pad = (size.width - pieceSize) / 2;
    final scaleX = pieceSize / srcRect.width;
    final scaleY = pieceSize / srcRect.height;
    final dst = Rect.fromLTWH(
      pad - srcRect.left * scaleX,
      pad - srcRect.top * scaleY,
      image.width * scaleX,
      image.height * scaleY,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
    if (outlineWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth
          ..color = outlineColor,
      );
    }
  }

  // Only the piece's actual outline is grabbable, so transparent corners
  // around a tab don't steal touches from the neighbouring piece.
  @override
  bool hitTest(Offset position) => path.contains(position);

  @override
  bool shouldRepaint(covariant _PiecePainter oldDelegate) {
    return oldDelegate.srcRect != srcRect ||
        oldDelegate.image != image ||
        oldDelegate.pieceSize != pieceSize ||
        oldDelegate.path != path ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.outlineWidth != outlineWidth ||
        oldDelegate.elevated != elevated;
  }
}

/// A single draggable jigsaw piece. Renders its own optimistic position
/// while being dragged, and otherwise follows the authoritative position
/// coming from [piece] (server state via GameService).
class PuzzlePieceWidget extends StatefulWidget {
  final PuzzlePiece piece;
  final ui.Image image;
  final Rect srcRect;
  final PieceEdges edges;
  final double renderSize;
  final double canvasOffsetX;
  final double canvasOffsetY;
  final double canvasWidth;
  final double canvasHeight;
  final bool isActive;
  final String? youId;
  final Color? heldByColor;
  final double Function() currentScale;
  final void Function(String pieceId) onPickUp;
  final void Function(String pieceId, double x, double y) onMove;
  final void Function(String pieceId, double x, double y) onDrop;

  const PuzzlePieceWidget({
    super.key,
    required this.piece,
    required this.image,
    required this.srcRect,
    required this.edges,
    required this.renderSize,
    required this.canvasOffsetX,
    required this.canvasOffsetY,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.isActive,
    required this.youId,
    required this.heldByColor,
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
  // True from the moment a drop is sent until the server's echo for THIS
  // drop actually lands. GameService mutates PuzzlePiece objects in place,
  // so widget.piece can still hold the pre-drop x/y for a bit after we let
  // go; without this guard, the next unrelated rebuild (e.g. another
  // player's move, or our own z-order reset) would sync _x/_y back to that
  // stale value and the piece would visibly snap backwards before jumping
  // to its real dropped spot once the echo arrives.
  bool _pendingConfirm = false;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  late Path _path;

  // Extra room around the square cell so tabs aren't cut off.
  double get _tabPad => widget.renderSize * kTabRatio;

  void _buildPath() {
    _path = buildPiecePath(widget.edges, widget.renderSize, Offset(_tabPad, _tabPad));
  }

  @override
  void initState() {
    super.initState();
    _buildPath();
    _x = widget.piece.x;
    _y = widget.piece.y;
    _clamp();
  }

  bool get _heldByOther =>
      !widget.piece.placed && widget.piece.heldBy != null && widget.piece.heldBy != widget.youId;

  @override
  void didUpdateWidget(covariant PuzzlePieceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.edges != widget.edges || oldWidget.renderSize != widget.renderSize) {
      _buildPath();
    }

    if (_dragging && _heldByOther) {
      // Someone else's pick_piece won the race after we'd already started
      // dragging optimistically; give up and snap to the authoritative spot.
      _dragging = false;
      _pendingConfirm = false;
    }
    if (_dragging) return;

    if (_pendingConfirm) {
      final matchesSent = (widget.piece.x - _x).abs() < 0.5 && (widget.piece.y - _y).abs() < 0.5;
      if (!widget.piece.placed && !matchesSent) {
        return; // still stale; keep showing our locally-dropped position
      }
      _pendingConfirm = false;
    }

    _x = widget.piece.x;
    _y = widget.piece.y;
    _clamp();
  }

  // _x/_y are board-local (can be negative, into the scatter padding), and
  // rendered at canvasOffsetX/Y + _x/_y. Clamp so that the piece, tabs
  // included, stays within [0, canvasWidth/Height].
  double get _minX => -widget.canvasOffsetX + _tabPad;
  double get _maxX => widget.canvasWidth - widget.canvasOffsetX - widget.renderSize - _tabPad;
  double get _minY => -widget.canvasOffsetY + _tabPad;
  double get _maxY => widget.canvasHeight - widget.canvasOffsetY - widget.renderSize - _tabPad;

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
    final heldByOther = _heldByOther;
    final locked = widget.piece.placed || heldByOther;
    final boxSize = widget.renderSize + _tabPad * 2;

    return Positioned(
      left: widget.canvasOffsetX + _x - _tabPad,
      top: widget.canvasOffsetY + _y - _tabPad,
      width: boxSize,
      height: boxSize,
      // Uses raw pointer events (Listener) instead of GestureDetector's pan
      // recognizer: a GestureDetector here would compete in the same gesture
      // arena as the ancestor InteractiveViewer's scale recognizer and can
      // lose, silently swallowing the drag. Listener bypasses the arena
      // entirely, so it isn't affected by that ancestor.
      child: Listener(
        // deferToChild: only hits inside the piece outline count (see
        // _PiecePainter.hitTest), not the transparent padding around tabs.
        behavior: HitTestBehavior.deferToChild,
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
                setState(() {
                  _dragging = false;
                  _pendingConfirm = true;
                });
                widget.onDrop(widget.piece.id, _x, _y);
              },
        onPointerCancel: locked
            ? null
            : (_) {
                setState(() {
                  _dragging = false;
                  _pendingConfirm = true;
                });
                widget.onDrop(widget.piece.id, _x, _y);
              },
        child: CustomPaint(
          size: Size.square(boxSize),
          painter: _PiecePainter(
            image: widget.image,
            srcRect: widget.srcRect,
            pieceSize: widget.renderSize,
            path: _path,
            outlineColor: heldByOther
                ? (widget.heldByColor ?? Colors.grey.shade600)
                : widget.piece.placed
                    ? Colors.black.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.85),
            outlineWidth: heldByOther ? 2.5 : (widget.piece.placed ? 0.8 : 1.2),
            elevated: !locked && (_dragging || widget.isActive),
          ),
        ),
      ),
    );
  }
}
