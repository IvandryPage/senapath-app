import 'package:flutter/services.dart';

/// Blocks newlines so a field stays a single line even when the platform
/// keyboard offers a return key.
class SingleLineInputFormatter extends TextInputFormatter {
  const SingleLineInputFormatter();

  static final RegExp _lineBreaks = RegExp(r'[\r\n]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.replaceAll(_lineBreaks, ' ');
    if (filtered == newValue.text) return newValue;
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
      composing: TextRange.empty,
    );
  }
}

/// Strips control, invisible (zero-width/bidi), and optionally line-break
/// characters while the user types. Keeps the field resilient to pasted junk.
class ForbiddenCharactersInputFormatter extends TextInputFormatter {
  const ForbiddenCharactersInputFormatter({this.allowLineBreaks = false});

  final bool allowLineBreaks;

  static final RegExp _singleLine = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
  );
  static final RegExp _multiLine = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.replaceAll(
      allowLineBreaks ? _multiLine : _singleLine,
      '',
    );
    if (filtered == newValue.text) return newValue;
    final offset = newValue.selection.baseOffset.clamp(0, filtered.length);
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}
