/// Central input constraints and validators used across the app.
///
/// Every user-facing field should validate through these helpers so limits and
/// messages stay consistent and defensible against strange input.
library;

abstract final class InputLimits {
  static const int displayNameMinLength = 1;
  static const int displayNameMaxLength = 60;

  static const int relationshipMinLength = 1;
  static const int relationshipMaxLength = 40;

  static const int teamNameMinLength = 2;
  static const int teamNameMaxLength = 60;

  static const int inviteCodeMinLength = 4;
  static const int inviteCodeMaxLength = 16;

  static const int emailMaxLength = 254;
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 128;

  static const int workoutNameMaxLength = 60;
  static const int intervalLabelMaxLength = 40;
  static const int intervalCountMax = 30;
  static const int intervalDurationMaxSeconds = 86400;
  static const int intervalDistanceMaxMeters = 1000000;

  static const int sessionNameMaxLength = 60;

  static const int itemNameMaxLength = 60;
  static const int expenseNoteMaxLength = 120;
  static const int areaHintMaxLength = 100;

  static const int searchQueryMaxLength = 80;
  static const int chatMessageMaxLength = 2000;
  static const int preferencesMaxLength = 300;

  static const double moneyMaxAmount = 1000000000000;
  static const int moneyMaxDecimals = 6;

  static const double goalSessionsMax = 100000;
  static const double goalDistanceKmMax = 1000000;
  static const double goalActiveHoursMax = 100000;
  static const int goalMaxDecimals = 2;
}

/// Text based validation. Character rules are intentionally lenient (almost
/// everything is allowed) but control, invisible, and line-break characters are
/// handled explicitly per field.
abstract final class TextValidators {
  static final RegExp _singleLineForbidden = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
  );
  static final RegExp _multiLineForbidden = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
  );
  static final RegExp _email = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
    r'[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$',
  );

  static bool hasForbiddenCharacters(
    String value, {
    bool allowLineBreaks = false,
  }) => (allowLineBreaks ? _multiLineForbidden : _singleLineForbidden)
      .hasMatch(value);

  static String stripForbiddenCharacters(
    String value, {
    bool allowLineBreaks = false,
  }) => value.replaceAll(
    allowLineBreaks ? _multiLineForbidden : _singleLineForbidden,
    '',
  );

  /// Trims and collapses whitespace into a single, clean line.
  static String sanitizeSingleLine(String value) =>
      stripForbiddenCharacters(value).replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Validates free-form names/labels. [label] is used to build messages such
  /// as "Isi nama." and "Nama maksimal 60 karakter.".
  static String? name(
    String? value, {
    required String label,
    int minLength = 1,
    int maxLength = 60,
    String? emptyMessage,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return emptyMessage ?? 'Isi $label.';
    if (hasForbiddenCharacters(text)) {
      return '$label memuat karakter yang tidak didukung.';
    }
    final length = text.runes.length;
    if (length < minLength) return '$label minimal $minLength karakter.';
    if (length > maxLength) return '$label maksimal $maxLength karakter.';
    return null;
  }

  /// Optional free-form text (notes, hints). Empty is always allowed.
  static String? optionalText(
    String? value, {
    required String label,
    required int maxLength,
    bool allowLineBreaks = false,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (hasForbiddenCharacters(text, allowLineBreaks: allowLineBreaks)) {
      return '$label memuat karakter yang tidak didukung.';
    }
    if (text.runes.length > maxLength) {
      return '$label maksimal $maxLength karakter.';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Masukkan email.';
    if (text.length > InputLimits.emailMaxLength) {
      return 'Email maksimal ${InputLimits.emailMaxLength} karakter.';
    }
    if (hasForbiddenCharacters(text) || text.contains(RegExp(r'\s'))) {
      return 'Email tidak boleh memuat spasi atau karakter yang tidak didukung.';
    }
    if (text.startsWith('.') ||
        text.contains('..') ||
        !_email.hasMatch(text)) {
      return 'Masukkan email yang valid, contoh nama@domain.com.';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Masukkan kata sandi.';
    if (text.length < InputLimits.passwordMinLength) {
      return 'Kata sandi harus terdiri dari minimal '
          '${InputLimits.passwordMinLength} karakter.';
    }
    if (text.length > InputLimits.passwordMaxLength) {
      return 'Kata sandi maksimal ${InputLimits.passwordMaxLength} karakter.';
    }
    if (hasForbiddenCharacters(text)) {
      return 'Kata sandi memuat karakter yang tidak didukung.';
    }
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) return 'Ulangi kata sandi.';
    if (value != password) return 'Kata sandi belum cocok.';
    return null;
  }

  static String? inviteCode(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Masukkan kode undangan.';
    if (hasForbiddenCharacters(text)) {
      return 'Kode undangan memuat karakter yang tidak didukung.';
    }
    final code = text.toUpperCase();
    if (!RegExp(r'^[A-Z0-9-]+$').hasMatch(code)) {
      return 'Kode undangan hanya boleh berisi huruf, angka, dan tanda hubung.';
    }
    if (code.length < InputLimits.inviteCodeMinLength) {
      return 'Kode undangan minimal ${InputLimits.inviteCodeMinLength} karakter.';
    }
    if (code.length > InputLimits.inviteCodeMaxLength) {
      return 'Kode undangan maksimal ${InputLimits.inviteCodeMaxLength} karakter.';
    }
    return null;
  }

  /// Bounds a raw numeric target typed by the user. [parsed] is the already
  /// parsed value (before unit conversion).
  static String? number(
    String? value, {
    required String label,
    required double? parsed,
    required double max,
    double min = 0,
    bool allowEqualMin = false,
    int maxDecimals = 2,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Isi $label.';
    if (!RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(text)) {
      return '$label hanya boleh berisi angka.';
    }
    if (parsed == null || !parsed.isFinite) {
      return 'Masukkan $label berupa angka yang valid.';
    }
    if (parsed < min || (!allowEqualMin && parsed == min)) {
      return allowEqualMin
          ? '$label minimal $min.'
          : '$label harus lebih besar dari $min.';
    }
    if (parsed > max) return '$label maksimal ${_formatLimit(max)}.';
    if (_fractionDigits(text) > maxDecimals) {
      return '$label maksimal $maxDecimals angka di belakang koma.';
    }
    return null;
  }

  static String? positiveInteger(
    String? value, {
    required String label,
    required int? parsed,
    int min = 1,
    required int max,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Isi $label.';
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return '$label harus berupa angka bulat tanpa titik atau koma.';
    }
    final result = parsed;
    if (result == null) return 'Masukkan $label yang valid.';
    if (result < min) return '$label minimal $min.';
    if (result > max) return '$label maksimal $max.';
    return null;
  }

  static int _fractionDigits(String text) {
    final comma = text.indexOf(',');
    if (comma != -1) {
      return text.substring(comma + 1).replaceAll(RegExp(r'[^\d]'), '').length;
    }
    final dot = text.indexOf('.');
    if (dot == -1) return 0;
    return text.substring(dot + 1).replaceAll(RegExp(r'[^\d]'), '').length;
  }

  static String _formatLimit(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}

/// Validation for money/amount fields that use grouped digit formatting.
abstract final class AmountValidators {
  static final RegExp _groupedInteger = RegExp(r'^\d{1,3}(?:\.\d{3})+$');
  static final RegExp _amountFormat = RegExp(
    r'^(?:\d{1,3}(?:\.\d{3})*(?:,\d+)?|\d+(?:[.,]\d+)?)$',
  );

  /// Validates a raw amount string. [parsed] should come from
  /// `AmountInputFormatter.parse` so the app uses one parsing rule.
  static String? amount(
    String? raw, {
    required String label,
    required double? parsed,
    bool required = true,
    bool allowZero = false,
    double max = InputLimits.moneyMaxAmount,
    int maxDecimals = InputLimits.moneyMaxDecimals,
  }) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return required ? 'Isi $label.' : null;
    if (!_amountFormat.hasMatch(text)) {
      return 'Masukkan $label berupa angka, contoh 150000 atau 12,5.';
    }
    final value = parsed;
    if (value == null || !value.isFinite) {
      return 'Masukkan $label berupa angka yang valid.';
    }
    if (value < 0) return '$label tidak boleh negatif.';
    if (!allowZero && value == 0) return '$label harus lebih dari nol.';
    if (value > max) {
      return '$label terlalu besar (maksimal '
          '${max == InputLimits.moneyMaxAmount ? '1.000.000.000.000' : max}).';
    }
    if (_fractionDigits(text) > maxDecimals) {
      return '$label maksimal $maxDecimals angka di belakang koma.';
    }
    return null;
  }

  static int _fractionDigits(String text) {
    final comma = text.indexOf(',');
    if (comma != -1) {
      return text.substring(comma + 1).replaceAll(RegExp(r'[^\d]'), '').length;
    }
    if (_groupedInteger.hasMatch(text)) return 0;
    final dot = text.indexOf('.');
    if (dot == -1) return 0;
    return text.substring(dot + 1).replaceAll(RegExp(r'[^\d]'), '').length;
  }
}
