import 'dart:convert';

import '../../../core/storage/secure_vault.dart';
import '../domain/feedback_submission.dart';

class FeedbackRepository {
  const FeedbackRepository(this._secureVault);

  static const _storageKey = 'senapath.feedback.outbox.v1';

  final SecureVault _secureVault;

  Future<List<FeedbackSubmission>> loadPending() async {
    final value = await _secureVault.read(_storageKey);
    if (value == null) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Invalid feedback outbox.');
    }
    return [
      for (final item in decoded)
        if (item is Map)
          FeedbackSubmission.fromJson(Map<String, Object?>.from(item))
        else
          throw const FormatException('Invalid feedback outbox item.'),
    ];
  }

  Future<void> savePending(List<FeedbackSubmission> submissions) async {
    if (submissions.isEmpty) {
      await _secureVault.delete(_storageKey);
      return;
    }
    await _secureVault.write(
      _storageKey,
      jsonEncode(submissions.map((submission) => submission.toJson()).toList()),
    );
  }
}
