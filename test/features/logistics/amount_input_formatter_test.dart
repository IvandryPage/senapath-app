import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/logistics/presentation/amount_input_formatter.dart';

void main() {
  group('AmountInputFormatter.formatValue', () {
    test('groups integer digits with dots', () {
      expect(AmountInputFormatter.formatValue(1234567), '1.234.567');
      expect(AmountInputFormatter.formatValue(999), '999');
      expect(AmountInputFormatter.formatValue(1000), '1.000');
    });

    test('renders a decimal comma and strips trailing zeros', () {
      expect(AmountInputFormatter.formatValue(1234.5), '1.234,5');
      expect(AmountInputFormatter.formatValue(2.0), '2');
      expect(AmountInputFormatter.formatValue(1234.500000), '1.234,5');
    });

    test('returns empty text for non-finite values', () {
      expect(AmountInputFormatter.formatValue(double.nan), '');
      expect(AmountInputFormatter.formatValue(double.infinity), '');
    });
  });

  group('AmountInputFormatter.parse', () {
    test('parses plain integers', () {
      expect(AmountInputFormatter.parse('1234'), 1234);
      expect(AmountInputFormatter.parse('0'), 0);
    });

    test('parses grouped integers', () {
      expect(AmountInputFormatter.parse('1.234.567'), 1234567);
    });

    test('parses decimal commas', () {
      expect(AmountInputFormatter.parse('1.234,5'), 1234.5);
      expect(AmountInputFormatter.parse('0,5'), 0.5);
    });

    test('parses decimal points', () {
      expect(AmountInputFormatter.parse('12.5'), 12.5);
      expect(AmountInputFormatter.parse('1.2.3'), isNull);
      expect(AmountInputFormatter.parse('1.'), isNull);
      expect(AmountInputFormatter.parse('0.5'), 0.5);
    });

    test('rejects invalid input', () {
      expect(AmountInputFormatter.parse(''), isNull);
      expect(AmountInputFormatter.parse(null), isNull);
      expect(AmountInputFormatter.parse('12a'), isNull);
      expect(AmountInputFormatter.parse('1,2,3'), isNull);
      expect(AmountInputFormatter.parse('1,2.'), isNull);
    });
  });

  group('AmountInputFormatter.formatEditUpdate', () {
    const formatter = AmountInputFormatter();

    test('groups digits as they are typed', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '1234567'),
      );
      expect(result.text, '1.234.567');
    });

    test('supports a decimal comma', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '1234,5'),
      );
      expect(result.text, '1.234,5');
    });

    test('regroups grouped values when a digit is typed inside', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '1.234'),
        const TextEditingValue(text: '1.2345'),
      );
      expect(result.text, '12.345');
    });

    test('treats an inserted decimal point as a decimal comma', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '12'),
        const TextEditingValue(text: '12.5'),
      );
      expect(result.text, '12,5');
    });

    test('strips characters that are not digits or separators', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: 'a1b2c'),
      );
      expect(result.text, '12');
    });

    test('formats from an empty base value', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '12,34'),
      );
      expect(result.text, '12,34');
    });
  });

  group('AmountInputFormatter.formatMoney', () {
    test('formats with the Indonesian locale', () {
      expect(
        AmountInputFormatter.formatMoney(
          1234.5,
          currencyCode: 'EUR',
          decimalDigits: 2,
        ),
        'EUR 1.234,50',
      );
      expect(
        AmountInputFormatter.formatMoney(
          1234,
          currencyCode: 'IDR',
          decimalDigits: 0,
        ),
        'IDR 1.234',
      );
    });
  });
}
