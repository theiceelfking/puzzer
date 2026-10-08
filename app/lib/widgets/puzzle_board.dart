import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/piece_shape.dart';
import '../services/game_service.dart';
import 'puzzle_piece_widget.dart';

/// Padding ratio around the solved-board area where pieces may start
/// scattered. Kept generous enough to comfortably contain every piece the
/// server can generate (see server/src/puzzle.js).
const double _kPadRatio = 0.55;

class PuzzleBoard extends StatefulWidget {
  final ui.Image image;

  const PuzzleBoard({super.key, required this.image});

  @override
  State<PuzzleBoard> createState() => _PuzzleBoardState();
}

class _PuzzleBoardState extends State<PuzzleBoard> {
  final TransformationController _controller = TransformationController();
  String? _activePieceId;
  bool _initialFitDone = false;

  double get _currentScale => _controller.value.getMaxScaleOnAxis();

  void _fitToScreen(double viewportW, double viewportH, double canvasW, double canvasH) {
    final scale = (viewportW / canvasW).clamp(0.15, 1.0);
    final dx = (viewportW - canvasW * scale) / 2;
    final dy = (viewportH - canvasH * scale) / 2;
    _controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameService>();
    final rows = game.rows;
    final cols = game.cols;
    final pieceSize = game.pieceSize;
    if (rows == 0 || cols == 0) return const SizedBox.shrink();

    final boardW = cols * pieceSize;
    final boardH = rows * pieceSize;
    final padX = boardW * _kPadRatio;
    final padY = boardH * _kPadRatio;
    final canvasW = boardW + padX * 2;
    final canvasH = boardH + padY * 2;

    // The grid's aspect ratio rarely matches the picture exactly, so use the
    // largest centred region of the picture with the board's ratio (like
    // BoxFit.cover) instead of stretching it.
    final imageW = widget.image.width.toDouble();
    final imageH = widget.image.height.toDouble();
    final boardRatio = boardW / boardH;
    final cropW = imageW / imageH > boardRatio ? imageH * boardRatio : imageW;
    final cropH = imageW / imageH > boardRatio ? imageH : imageW / boardRatio;
    final cropLeft = (imageW - cropW) / 2;
    final cropTop = (imageH - cropH) / 2;
    final cellSrcW = cropW / cols;
    final cellSrcH = cropH / rows;

    // Placed pieces always sit underneath loose ones, so a piece locked into
    // the board can never cover one that still needs to be picked up.
    final picture = game.pictureProvider;
    final sortedPieces = [...game.pieces]..sort((a, b) {
        if (a.placed != b.placed) return a.placed ? -1 : 1;
        return a.z.compareTo(b.z);
      });
    if (_activePieceId != null) {
      final idx = sortedPieces.indexWhere((p) => p.id == _activePieceId);
      if (idx != -1) {
        final active = sortedPieces.removeAt(idx);
        sortedPieces.add(active);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_initialFitDone && constraints.maxWidth > 0) {
          _initialFitDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _fitToScreen(constraints.maxWidth, constraints.maxHeight, canvasW, canvasH));
            }
          });
        }
        return InteractiveViewer(
          transformationController: _controller,
          panEnabled: false,
          scaleEnabled: true,
          minScale: 0.15,
          maxScale: 3.0,
          boundaryMargin: const EdgeInsets.all(400),
          constrained: false,
          child: SizedBox(
            width: canvasW,
            height: canvasH,
            child: Stack(
              children: [
                Positioned(
                  left: padX,
                  top: padY,
                  width: boardW,
                  height: boardH,
                  // The frame is painted over the guide picture (or over nothing,
                  // when the room was created without it).
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
                    ),
                    child: game.showBackground && picture != null
                        ? Opacity(opacity: 0.25, child: Image(image: picture, fit: BoxFit.cover))
                        : const SizedBox.expand(),
                  ),
                ),
                for (final piece in sortedPieces)
                  PuzzlePieceWidget(
                    key: ValueKey(piece.id),
                    piece: piece,
                    image: widget.image,
                    srcRect: Rect.fromLTWH(
                      cropLeft + piece.col * cellSrcW,
                      cropTop + piece.row * cellSrcH,
                      cellSrcW,
                      cellSrcH,
                    ),
                    edges: PieceEdges.forPiece(
                      seed: game.roomId ?? '',
                      row: piece.row,
                      col: piece.col,
                      rows: rows,
                      cols: cols,
                    ),
                    renderSize: pieceSize,
                    canvasOffsetX: padX,
                    canvasOffsetY: padY,
                    canvasWidth: canvasW,
                    canvasHeight: canvasH,
                    isActive: piece.id == _activePieceId,
                    youId: game.youId,
                    heldByColor: piece.heldBy == null ? null : game.players[piece.heldBy]?.color,
                    currentScale: () => _currentScale,
                    onPickUp: (id) {
                      setState(() => _activePieceId = id);
                      game.pickPiece(id);
                    },
                    onMove: game.movePiece,
                    onDrop: (id, x, y) {
                      game.dropPiece(id, x, y);
                      setState(() => _activePieceId = null);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
