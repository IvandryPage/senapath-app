import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter();

  static final _groupedInteger = RegExp(r'^\d{1,3}(?:\.\d{3})+$');

  static String formatValue(double value) {
    if (!value.isFinite) return '';
    final canonical = value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    final decimalIndex = canonical.indexOf('.');
    final integer = decimalIndex == -1
        ? canonical
        : canonical.substring(0, decimalIndex);
    final fraction = decimalIndex == -1
        ? ''
        : canonical.substring(decimalIndex + 1);
    return _groupInteger(integer) + (fraction.isEmpty ? '' : ',$fraction');
  }

  static double? parse(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || !RegExp(r'^[\d.,]+$').hasMatch(text)) return null;

    final commaIndex = text.lastIndexOf(',');
    if (commaIndex != -1) {
      if (text.indexOf(',') != commaIndex) return null;
      final integer = text.substring(0, commaIndex);
      final fraction = text.substring(commaIndex + 1);
      if (fraction.isEmpty || !_isValidInteger(integer)) return null;
      return double.tryParse('${integer.replaceAll('.', '')}.$fraction');
    }

    if (_groupedInteger.hasMatch(text)) {
      return double.tryParse(text.replaceAll('.', ''));
    }
    if (text.contains('.')) {
      if (text.indexOf('.') != text.lastIndexOf('.')) return null;
      final parts = text.split('.');
      if (parts.first.isEmpty || parts.last.isEmpty) return null;
      return double.tryParse('${parts.first}.${parts.last}');
    }
    return double.tryParse(text);
  }

  static String formatMoney(
    double amount, {
    required String currencyCode,
    required int decimalDigits,
  }) => NumberFormat.currency(
    locale: 'id_ID',
    name: currencyCode,
    symbol: '$currencyCode ',
    decimalDigits: decimalDigits,
  ).format(amount);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var input = newValue.text;
    final oldWasGrouped = _groupedInteger.hasMatch(oldValue.text);
    final insertedText = _insertedText(oldValue.text, input);

    if (oldWasGrouped &&
        !oldValue.text.contains(',') &&
        !_groupedInteger.hasMatch(input)) {
      if (insertedText.contains('.')) {
        final insertedStart = _insertedStart(oldValue.text, input);
        final insertedEnd = insertedStart + insertedText.length;
        input = input.replaceRange(
          insertedStart,
          insertedEnd,
          insertedText.replaceAll('.', ','),
        );
      } else {
        input = input.replaceAll('.', '');
      }
    }

    final formatted = _formatInput(input);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: _formattedOffset(
          formatted,
          input,
          newValue.selection.baseOffset,
        ),
        extentOffset: _formattedOffset(
          formatted,
          input,
          newValue.selection.extentOffset,
        ),
      ),
      composing: TextRange.empty,
    );
  }

  static String _formatInput(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d.,]'), '');
    if (cleaned.isEmpty) return '';

    final commaIndex = cleaned.lastIndexOf(',');
    String integer;
    String fraction;
    var hasDecimal = false;

    if (commaIndex != -1) {
      integer = cleaned.substring(0, commaIndex);
      fraction = cleaned
          .substring(commaIndex + 1)
          .replaceAll(RegExp(r'[^\d]'), '');
      hasDecimal = true;
    } else if (cleaned.contains('.') && !_groupedInteger.hasMatch(cleaned)) {
      final decimalIndex = cleaned.lastIndexOf('.');
      integer = cleaned.substring(0, decimalIndex);
      fraction = cleaned
          .substring(decimalIndex + 1)
          .replaceAll(RegExp(r'[^\d]'), '');
      hasDecimal = true;
    } else {
      integer = cleaned;
      fraction = '';
    }

    integer = integer.replaceAll(RegExp(r'[^\d]'), '');
    if (integer.isEmpty && (hasDecimal || fraction.isNotEmpty)) integer = '0';
    return _groupInteger(integer) + (hasDecimal ? ',$fraction' : '');
  }

  static bool _isValidInteger(String value) =>
      RegExp(r'^\d+$').hasMatch(value) || _groupedInteger.hasMatch(value);

  static String _groupInteger(String value) {
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';
    return digits.replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+$)'), (_) => '.');
  }

  static String _insertedText(String oldText, String newText) {
    final start = _insertedStart(oldText, newText);
    var end = newText.length;
    var oldEnd = oldText.length;
    while (end > start &&
        oldEnd > start &&
        newText[end - 1] == oldText[oldEnd - 1]) {
      end--;
      oldEnd--;
    }
    return newText.substring(start, end);
  }

  static int _insertedStart(String oldText, String newText) {
    var index = 0;
    final limit = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (index < limit && oldText[index] == newText[index]) {
      index++;
    }
    return index;
  }

  static int _formattedOffset(
    String formatted,
    String input,
    int sourceOffset,
  ) {
    final boundedOffset = sourceOffset.clamp(0, input.length);
    final semanticCharacters = input
        .substring(0, boundedOffset)
        .replaceAll('.', '')
        .length;
    if (semanticCharacters == 0) return 0;
    var seen = 0;
    for (var index = 0; index < formatted.length; index++) {
      final character = formatted[index];
      if (character != '.') seen++;
      if (seen >= semanticCharacters) return index + 1;
    }
    return formatted.length;
  }
}
