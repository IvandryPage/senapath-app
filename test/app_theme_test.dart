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
