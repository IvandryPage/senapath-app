import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/app/theme/app_theme.dart';

void main() {
  test('app theme uses light brightness and light surfaces', () {
    final theme = AppTheme.light;

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, isNot(Colors.black));
  });
}
