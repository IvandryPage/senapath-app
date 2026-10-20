import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/validation/validators.dart';

void main() {
  group('TextValidators.hasForbiddenCharacters / stripForbiddenCharacters', () {
    test('flags control characters in single-line mode', () {
      expect(TextValidators.hasForbiddenCharacters('abc\u0000def'), isTrue);
      expect(TextValidators.hasForbiddenCharacters('abc\ndef'), isTrue);
      expect(TextValidators.hasForbiddenCharacters('abc def'), isFalse);
    });

    test('allows line breaks when allowLineBreaks is true', () {
      expect(
        TextValidators.hasForbiddenCharacters('abc\ndef', allowLineBreaks: true),
        isFalse,
      );
      expect(
        TextValidators.hasForbiddenCharacters(
          'abc\u0000def',
          allowLineBreaks: true,
        ),
        isTrue,
      );
    });

    test('strips zero-width and bidi control characters', () {
      expect(
        TextValidators.stripForbiddenCharacters('a\u200Bb\u202Ec\uFEFFd'),
        'abcd',
      );
      expect(
        TextValidators.stripForbiddenCharacters('a\nb', allowLineBreaks: true),
        'a\nb',
      );
    });
  });

  group('TextValidators.sanitizeSingleLine', () {
    test('collapses whitespace and strips forbidden characters', () {
      expect(
        TextValidators.sanitizeSingleLine('  Budi   Santoso\u0000  '),
        'Budi Santoso',
      );
      expect(TextValidators.sanitizeSingleLine('\n\t'), '');
    });
  });

  group('TextValidators.name', () {
    test('rejects empty and null values', () {
      expect(
        TextValidators.name(null, label: 'nama'),
        'Isi nama.',
      );
      expect(TextValidators.name('   ', label: 'nama'), 'Isi nama.');
      expect(
        TextValidators.name('', label: 'nama', emptyMessage: 'Wajib diisi.'),
        'Wajib diisi.',
      );
    });

    test('rejects forbidden characters', () {
      expect(
        TextValidators.name('Budi\u0000', label: 'nama'),
        'nama memuat karakter yang tidak didukung.',
      );
    });

    test('enforces min and max length using rune length', () {
      expect(
        TextValidators.name('ab', label: 'nama', minLength: 3),
        'nama minimal 3 karakter.',
      );
      expect(
        TextValidators.name('a' * 61, label: 'nama'),
        'nama maksimal 60 karakter.',
      );
      expect(
        TextValidators.name('名' * 60, label: 'nama'),
        isNull,
      );
    });
  });

  group('TextValidators.optionalText', () {
    test('allows empty values', () {
      expect(
        TextValidators.optionalText(null, label: 'catatan', maxLength: 10),
        isNull,
      );
      expect(
        TextValidators.optionalText('   ', label: 'catatan', maxLength: 10),
        isNull,
      );
    });

    test('validates length and forbidden characters', () {
      expect(
        TextValidators.optionalText(
          'a' * 11,
          label: 'catatan',
          maxLength: 10,
        ),
        'catatan maksimal 10 karakter.',
      );
      expect(
        TextValidators.optionalText('a\u0000', label: 'catatan', maxLength: 10),
        'catatan memuat karakter yang tidak didukung.',
      );
      expect(
        TextValidators.optionalText(
          'a\nb',
          label: 'catatan',
          maxLength: 10,
          allowLineBreaks: true,
        ),
        isNull,
      );
    });
  });

  group('TextValidators.email', () {
    test('accepts reasonable addresses', () {
      expect(TextValidators.email('budi@example.com'), isNull);
      expect(TextValidators.email('  budi+tag@sub.domain.co.id  '), isNull);
      expect(TextValidators.email('a@b.c'), isNull);
    });

    test('rejects empty email', () {
      expect(TextValidators.email(null), 'Masukkan email.');
      expect(TextValidators.email(''), 'Masukkan email.');
    });

    test('rejects spaces and forbidden characters', () {
      expect(
        TextValidators.email('budi santoso@example.com'),
        'Email tidak boleh memuat spasi atau karakter yang tidak didukung.',
      );
      expect(
        TextValidators.email('budi\u0000@example.com'),
        'Email tidak boleh memuat spasi atau karakter yang tidak didukung.',
      );
    });

    test('rejects malformed addresses', () {
      const invalidMessage = 'Masukkan email yang valid, contoh nama@domain.com.';
      expect(TextValidators.email('budi'), invalidMessage);
      expect(TextValidators.email('budi@domain'), invalidMessage);
      expect(TextValidators.email('budi..x@example.com'), invalidMessage);
      expect(TextValidators.email('.budi@example.com'), invalidMessage);
      expect(TextValidators.email('budi@example.'), invalidMessage);
    });

    test('rejects emails longer than the limit', () {
      final email = '${'a' * 250}@example.com';
      expect(
        TextValidators.email(email),
        'Email maksimal 254 karakter.',
      );
    });
  });

  group('TextValidators.password', () {
    test('accepts passwords within the length limits', () {
      expect(TextValidators.password('rahasia123'), isNull);
      expect(TextValidators.password('a' * 128), isNull);
    });

    test('rejects short, long, and empty passwords', () {
      expect(TextValidators.password(''), 'Masukkan kata sandi.');
      expect(
        TextValidators.password('abc'),
        'Kata sandi harus terdiri dari minimal 8 karakter.',
      );
      expect(
        TextValidators.password('a' * 129),
        'Kata sandi maksimal 128 karakter.',
      );
      expect(
        TextValidators.password('abcdefgh\u0000'),
        'Kata sandi memuat karakter yang tidak didukung.',
      );
    });
  });

  group('TextValidators.passwordConfirmation', () {
    test('requires the confirmation to match', () {
      expect(TextValidators.passwordConfirmation(null, 'abc'), 'Ulangi kata sandi.');
      expect(TextValidators.passwordConfirmation('', 'abc'), 'Ulangi kata sandi.');
      expect(
        TextValidators.passwordConfirmation('abcd', 'abc'),
        'Kata sandi belum cocok.',
      );
      expect(TextValidators.passwordConfirmation('abc', 'abc'), isNull);
    });
  });

  group('TextValidators.inviteCode', () {
    test('accepts alphanumeric codes with dashes', () {
      expect(TextValidators.inviteCode('ABCD-1234'), isNull);
      expect(TextValidators.inviteCode('  abcd1234  '), isNull);
    });

    test('rejects empty, malformed, and out-of-range codes', () {
      expect(TextValidators.inviteCode(null), 'Masukkan kode undangan.');
      expect(
        TextValidators.inviteCode('ab!'),
        'Kode undangan hanya boleh berisi huruf, angka, dan tanda hubung.',
      );
      expect(
        TextValidators.inviteCode('abc'),
        'Kode undangan minimal 4 karakter.',
      );
      expect(
        TextValidators.inviteCode('A' * 17),
        'Kode undangan maksimal 16 karakter.',
      );
      expect(
        TextValidators.inviteCode('abc\u0000'),
        'Kode undangan memuat karakter yang tidak didukung.',
      );
    });
  });

  group('TextValidators.number', () {
    String? validate(String? value, {double? parsed, double max = 100}) =>
        TextValidators.number(
          value,
          label: 'jarak',
          parsed: parsed,
          max: max,
        );

    test('accepts valid numbers', () {
      expect(validate('10', parsed: 10), isNull);
      expect(
        validate('0', parsed: 0, max: 100),
        isNotNull,
        reason: 'zero is rejected unless allowEqualMin is set',
      );
      expect(validate('10.5', parsed: 10.5, max: 100), isNull);
    });

    test('requires a value and digits only', () {
      expect(validate(null), 'Isi jarak.');
      expect(validate('  '), 'Isi jarak.');
      expect(validate('abc', parsed: 1), 'jarak hanya boleh berisi angka.');
      expect(validate('1.2.3', parsed: 1), 'jarak hanya boleh berisi angka.');
    });

    test('requires a finite parsed value', () {
      expect(
        validate('10', parsed: null),
        'Masukkan jarak berupa angka yang valid.',
      );
      expect(
        validate('10', parsed: double.nan),
        'Masukkan jarak berupa angka yang valid.',
      );
    });

    test('enforces the minimum bound', () {
      expect(validate('0', parsed: 0), 'jarak harus lebih besar dari 0.0.');
      expect(
        validate('0', parsed: 0, max: 100),
        'jarak harus lebih besar dari 0.0.',
      );
    });

    test('enforces the maximum bound', () {
      expect(validate('200', parsed: 200), 'jarak maksimal 100.');
      expect(
        validate('100.6', parsed: 100.6),
        'jarak maksimal 100.',
      );
    });

    test('limits decimal places', () {
      expect(
        validate('1.234', parsed: 1.234),
        'jarak maksimal 2 angka di belakang koma.',
      );
    });
  });

  group('TextValidators.positiveInteger', () {
    test('accepts integers within range', () {
      expect(
        TextValidators.positiveInteger('5', label: 'target', parsed: 5, max: 30),
        isNull,
      );
    });

    test('rejects non-integer input', () {
      expect(
        TextValidators.positiveInteger(
          '1.5',
          label: 'target',
          parsed: 1,
          max: 30,
        ),
        'target harus berupa angka bulat tanpa titik atau koma.',
      );
    });

    test('requires a value and a parsed result', () {
      expect(
        TextValidators.positiveInteger(null, label: 'target', parsed: null, max: 30),
        'Isi target.',
      );
      expect(
        TextValidators.positiveInteger('5', label: 'target', parsed: null, max: 30),
        'Masukkan target yang valid.',
      );
    });

    test('enforces min and max bounds', () {
      expect(
        TextValidators.positiveInteger('0', label: 'target', parsed: 0, max: 30),
        'target minimal 1.',
      );
      expect(
        TextValidators.positiveInteger('31', label: 'target', parsed: 31, max: 30),
        'target maksimal 30.',
      );
    });
  });

  group('AmountValidators.amount', () {
    test('requires a value by default', () {
      expect(
        AmountValidators.amount(null, label: 'biaya', parsed: null),
        'Isi biaya.',
      );
      expect(
        AmountValidators.amount('  ', label: 'biaya', parsed: null, required: false),
        isNull,
      );
    });

    test('accepts grouped and decimal amounts', () {
      expect(
        AmountValidators.amount('150.000', label: 'biaya', parsed: 150000),
        isNull,
      );
      expect(AmountValidators.amount('12,5', label: 'biaya', parsed: 12.5), isNull);
      expect(AmountValidators.amount('12.5', label: 'biaya', parsed: 12.5), isNull);
    });

    test('rejects malformed amounts', () {
      expect(
        AmountValidators.amount('abc', label: 'biaya', parsed: 1),
        'Masukkan biaya berupa angka, contoh 150000 atau 12,5.',
      );
      expect(
        AmountValidators.amount('1', label: 'biaya', parsed: null),
        'Masukkan biaya berupa angka yang valid.',
      );
    });

    test('rejects negative, zero, and huge amounts', () {
      expect(
        AmountValidators.amount('1', label: 'biaya', parsed: -1),
        'biaya tidak boleh negatif.',
      );
      expect(
        AmountValidators.amount('0', label: 'biaya', parsed: 0),
        'biaya harus lebih dari nol.',
      );
      expect(
        AmountValidators.amount('0', label: 'biaya', parsed: 0, allowZero: true),
        isNull,
      );
      expect(
        AmountValidators.amount(
          '1.000.000.000.000.000',
          label: 'biaya',
          parsed: 1e15,
        ),
        'biaya terlalu besar (maksimal 1.000.000.000.000).',
      );
    });

    test('limits decimal places', () {
      expect(
        AmountValidators.amount('12,1234567', label: 'biaya', parsed: 12.1234567),
        'biaya maksimal 6 angka di belakang koma.',
      );
    });
  });

  group('InputLimits', () {
    test('exposes stable limits used across the app', () {
      expect(InputLimits.passwordMinLength, 8);
      expect(InputLimits.chatMessageMaxLength, 2000);
      expect(InputLimits.intervalCountMax, 30);
      expect(InputLimits.moneyMaxDecimals, 6);
    });
  });
}
