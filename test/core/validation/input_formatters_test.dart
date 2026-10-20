import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/validation/input_formatters.dart';

void main() {
  group('SingleLineInputFormatter', () {
    const formatter = SingleLineInputFormatter();

    test('keeps single-line text unchanged', () {
      const value = TextEditingValue(text: 'Budi Santoso');
      expect(formatter.formatEditUpdate(value, value), value);
    });

    test('replaces line breaks with spaces', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: 'Budi\nSantoso\r\nJr'),
      );
      expect(result.text, 'Budi Santoso  Jr');
      expect(result.selection.baseOffset, result.text.length);
      expect(result.composing.isValid, isFalse);
    });
  });

  group('ForbiddenCharactersInputFormatter', () {
    const formatter = ForbiddenCharactersInputFormatter();

    test('strips control and zero-width characters', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: 'a\u0000b\u200Bc\u202Ed'),
      );
      expect(result.text, 'abcd');
    });

    test('strips line breaks in single-line mode', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: 'a\nb'),
      );
      expect(result.text, 'ab');
    });

    test('keeps line breaks when allowLineBreaks is true', () {
      const multiline = ForbiddenCharactersInputFormatter(allowLineBreaks: true);
      final result = multiline.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: 'a\nb\u0000c'),
      );
      expect(result.text, 'a\nbc');
    });

    test('clamps the cursor when characters are removed', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: 'ab\u0000',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(result.text, 'ab');
      expect(result.selection.baseOffset, 2);
    });
  });
}
