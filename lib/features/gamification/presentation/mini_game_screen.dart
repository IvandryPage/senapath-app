import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/senapath_design.dart';
import 'rider_gamification_cubit.dart';

/// A drag-and-drop jigsaw puzzle that reassembles a 3x3 grid into one image.
class MiniGameScreen extends StatefulWidget {
  const MiniGameScreen({super.key});

  static const String asset = 'assets/images/mini_games_image.jpg';
  static const int gridSize = 3;

  /// Experience awarded every time the puzzle is solved.
  static const int rewardExperience = 10;

  @override
  State<MiniGameScreen> createState() => _MiniGameScreenState();
}

class _MiniGameScreenState extends State<MiniGameScreen> {
  static const int _tileCount =
      MiniGameScreen.gridSize * MiniGameScreen.gridSize;

  final Random _random = Random();
  late List<int> _tiles;
  int _moves = 0;
  bool _solved = false;

  @override
  void initState() {
    super.initState();
    _tiles = _shuffledTiles();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(MiniGameScreen.asset), context);
  }

  List<int> _solvedTiles() => List<int>.generate(_tileCount, (index) => index);

  bool _isSolvedOrder(List<int> tiles) {
    for (var index = 0; index < tiles.length; index++) {
      if (tiles[index] != index) return false;
    }
    return true;
  }

  List<int> _shuffledTiles() {
    final tiles = _solvedTiles();
    do {
      tiles.shuffle(_random);
    } while (_isSolvedOrder(tiles));
    return tiles;
  }

  void _shuffle() {
    setState(() {
      _tiles = _shuffledTiles();
      _moves = 0;
      _solved = false;
    });
  }

  void _swap(int draggedTile, int targetPosition) {
    final from = _tiles.indexOf(draggedTile);
    if (from == -1 || from == targetPosition) return;
    setState(() {
      _tiles[from] = _tiles[targetPosition];
      _tiles[targetPosition] = draggedTile;
      _moves++;
      _solved = _isSolvedOrder(_tiles);
    });
    if (_solved) {
      unawaited(
        context.read<RiderGamificationCubit>().awardExperience(
          MiniGameScreen.rewardExperience,
        ),
      );
      _showSolvedDialog();
    }
  }

  Future<void> _showSolvedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SenapathAlertDialog(
        title: const Text('Puzzle selesai!'),
        content: Text(
          'Kamu menyusun gambar dalam $_moves langkah. '
          '+${MiniGameScreen.rewardExperience} EXP',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _shuffle();
            },
            child: const Text('Main lagi'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPreview() => showDialog<void>(
    context: context,
    builder: (dialogContext) => SenapathAlertDialog(
      title: const Text('Gambar target'),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(SenapathShape.small),
        child: Image.asset(MiniGameScreen.asset, fit: BoxFit.contain),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Susun balok 3x3 menjadi satu gambar utuh. Seret satu balok ke '
            'balok lain untuk menukar posisinya.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _solved
                      ? 'Selesai dalam $_moves langkah.'
                      : 'Langkah: $_moves',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _showPreview,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Contoh'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _shuffle,
                icon: const Icon(Icons.shuffle, size: 18),
                label: const Text('Acak'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Center(
                  child: SizedBox.square(
                    dimension: boardSize,
                    child: _buildBoard(boardSize),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(double boardSize) {
    final cellSize = boardSize / MiniGameScreen.gridSize;
    return Column(
      children: [
        for (var row = 0; row < MiniGameScreen.gridSize; row++)
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < MiniGameScreen.gridSize; column++)
                  Expanded(
                    child: _buildCell(
                      row * MiniGameScreen.gridSize + column,
                      cellSize,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCell(int position, double cellSize) {
    final tile = _tiles[position];
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != tile,
      onAcceptWithDetails: (details) => _swap(details.data, position),
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        final colors = Theme.of(context).colorScheme;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(
              color: highlighted ? colors.primary : colors.outlineVariant,
              width: highlighted ? 2 : 0.5,
            ),
          ),
          child: Draggable<int>(
            data: tile,
            feedback: SizedBox.square(
              dimension: cellSize,
              child: _PuzzlePiece(tile: tile, size: cellSize),
            ),
            childWhenDragging: ColoredBox(
              color: colors.surfaceContainerHighest,
            ),
            child: _PuzzlePiece(tile: tile, size: cellSize),
          ),
        );
      },
    );
  }
}

class _PuzzlePiece extends StatelessWidget {
  const _PuzzlePiece({required this.tile, required this.size});

  final int tile;
  final double size;

  @override
  Widget build(BuildContext context) {
    const grid = MiniGameScreen.gridSize;
    final row = tile ~/ grid;
    final column = tile % grid;
    final imageSize = size * grid;
    final alignment = Alignment(
      grid == 1 ? 0 : 2 * column / (grid - 1) - 1,
      grid == 1 ? 0 : 2 * row / (grid - 1) - 1,
    );
    return ClipRect(
      child: OverflowBox(
        alignment: alignment,
        minWidth: imageSize,
        maxWidth: imageSize,
        minHeight: imageSize,
        maxHeight: imageSize,
        child: Image.asset(
          MiniGameScreen.asset,
          width: imageSize,
          height: imageSize,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
