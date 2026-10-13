import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/app/theme/app_theme.dart';
import 'package:senapath/app/theme/senapath_design.dart';

void main() {
  test('app theme uses light brightness and light surfaces', () {
    final theme = AppTheme.light;

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, isNot(Colors.black));
  });

  test('dark theme reverses light surfaces and text contrast', () {
    final theme = AppTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF071122));
    expect(theme.colorScheme.surface, const Color(0xFF10243A));
    expect(theme.colorScheme.onSurface, const Color(0xFFF4F7FB));
    expect(theme.cardTheme.color, const Color(0xFF10243A));
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
      const Color(0xFF7FC8FF),
    );
  });

  testWidgets('shared alert dialogs use comfortable internal spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SenapathAlertDialog(
          title: Text('Judul'),
          content: Text('Konten'),
          actions: [TextButton(onPressed: null, child: Text('Tutup'))],
        ),
      ),
    );

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.titlePadding, const EdgeInsets.fromLTRB(24, 24, 24, 0));
    expect(dialog.contentPadding, const EdgeInsets.fromLTRB(24, 16, 24, 8));
    expect(dialog.actionsPadding, const EdgeInsets.fromLTRB(16, 8, 16, 16));
    expect(dialog.actionsOverflowButtonSpacing, SenapathSpacing.xs);
  });
}
