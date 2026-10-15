import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/gamification/presentation/mini_game_screen.dart';

void main() {
  Widget app() => const MaterialApp(home: Scaffold(body: MiniGameScreen()));

  testWidgets('renders a 3x3 draggable puzzle board', (tester) async {
    await tester.pumpWidget(app());

    expect(find.textContaining('Susun balok 3x3'), findsOneWidget);
    expect(find.text('Acak'), findsOneWidget);
    expect(find.text('Contoh'), findsOneWidget);
    expect(find.byType(Draggable<int>), findsNWidgets(9));
    expect(find.text('Langkah: 0'), findsOneWidget);

    await tester.tap(find.text('Contoh'));
    await tester.pumpAndSettle();
    expect(find.text('Gambar target'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
  });

  testWidgets('each tile paints a board-sized slice of the image', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    final cellSize = tester.getSize(find.byType(Draggable<int>).first).width;
    final imageSize = tester.getSize(
      find
          .descendant(
            of: find.byType(Draggable<int>).first,
            matching: find.byType(Image),
          )
          .first,
    );

    expect(imageSize.width, closeTo(cellSize * MiniGameScreen.gridSize, 0.5));
    expect(imageSize.height, closeTo(cellSize * MiniGameScreen.gridSize, 0.5));
  });

  testWidgets('dragging a tile onto another swaps their positions', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    AlignmentGeometry alignmentOfFirstTile() {
      final align = find
          .descendant(
            of: find.byType(Draggable<int>).first,
            matching: find.byType(OverflowBox),
          )
          .first;
      return tester.widget<OverflowBox>(align).alignment;
    }

    final before = alignmentOfFirstTile();

    await tester.drag(find.byType(Draggable<int>).first, const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(alignmentOfFirstTile(), isNot(before));
    expect(find.text('Langkah: 1'), findsOneWidget);
  });
}
