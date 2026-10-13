import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/logistics/domain/logistics_models.dart';
import 'package:senapath/features/logistics/presentation/amount_input_formatter.dart';

void main() {
  const formatter = AmountInputFormatter();

  test('groups thousands with dots and keeps the parsed amount numeric', () {
    final formatted = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '1234567',
        selection: TextSelection.collapsed(offset: 7),
      ),
    );

    expect(formatted.text, '1.234.567');
    expect(AmountInputFormatter.parse(formatted.text), 1234567);
    expect(formatted.selection, const TextSelection.collapsed(offset: 9));
  });

  test('formats pasted decimal amounts without losing the decimal value', () {
    final formatted = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '1234567,89',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );

    expect(formatted.text, '1.234.567,89');
    expect(AmountInputFormatter.parse(formatted.text), 1234567.89);
  });

  test('allows decimal input and turns a typed decimal dot into a comma', () {
    final decimalStart = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '1',
        selection: TextSelection.collapsed(offset: 1),
      ),
      const TextEditingValue(
        text: '1.',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    final decimalValue = formatter.formatEditUpdate(
      decimalStart,
      TextEditingValue(
        text: '${decimalStart.text}25',
        selection: TextSelection.collapsed(
          offset: decimalStart.text.length + 2,
        ),
      ),
    );

    expect(decimalStart.text, '1,');
    expect(decimalValue.text, '1,25');
    expect(AmountInputFormatter.parse(decimalValue.text), 1.25);
  });

  test('keeps inserted digits grouped and removes grouping on deletion', () {
    final appended = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '1.234',
        selection: TextSelection.collapsed(offset: 5),
      ),
      const TextEditingValue(
        text: '1.2345',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    final deleted = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '1.234',
        selection: TextSelection.collapsed(offset: 4),
      ),
      const TextEditingValue(
        text: '1.23',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );

    expect(appended.text, '12.345');
    expect(AmountInputFormatter.parse(appended.text), 12345);
    expect(deleted.text, '123');
    expect(AmountInputFormatter.parse(deleted.text), 123);
  });

  test('accepts a pasted grouped value over an existing grouped value', () {
    final formatted = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '1.234.567',
        selection: TextSelection.collapsed(offset: 9),
      ),
      const TextEditingValue(
        text: '2.345.678',
        selection: TextSelection.collapsed(offset: 9),
      ),
    );

    expect(formatted.text, '2.345.678');
    expect(AmountInputFormatter.parse(formatted.text), 2345678);
  });

  test('renders rates with decimal commas and money with dot grouping', () {
    expect(AmountInputFormatter.formatValue(1.2345), '1,2345');
    expect(
      AmountInputFormatter.formatMoney(
        1234567,
        currencyCode: BudgetCurrency.idr.code,
        decimalDigits: BudgetCurrency.idr.decimalDigits,
      ),
      'IDR 1.234.567',
    );
    expect(
      AmountInputFormatter.formatMoney(
        1234.5,
        currencyCode: BudgetCurrency.usd.code,
        decimalDigits: BudgetCurrency.usd.decimalDigits,
      ),
      'USD 1.234,50',
    );
  });

  test('rejects malformed grouping and incomplete decimal values', () {
    expect(AmountInputFormatter.parse('1.23.4'), isNull);
    expect(AmountInputFormatter.parse('1.234,'), isNull);
  });
}
