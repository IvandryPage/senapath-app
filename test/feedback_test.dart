import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/feedback/data/feedback_gateway.dart';
import 'package:senapath/features/feedback/data/feedback_repository.dart';
import 'package:senapath/features/feedback/domain/feedback_submission.dart';
import 'package:senapath/features/feedback/presentation/feedback_cubit.dart';
import 'package:senapath/features/feedback/presentation/feedback_screen.dart';

void main() {
  testWidgets('feedback page shows hardcoded suggestions and impressions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FeedbackScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Saran dan Kesan'), findsOneWidget);
    expect(find.text('Saran'), findsOneWidget);
    expect(find.text('Kesan'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  test('requires consent before saving or sending feedback', () async {
    final vault = _MemorySecureVault();
    final gateway = _FakeFeedbackGateway();
    final cubit = FeedbackCubit(FeedbackRepository(vault), gateway);
    addTearDown(cubit.close);

    final accepted = await cubit.submit('Saran', consent: false);

    expect(accepted, isFalse);
    expect(cubit.state.pending, isEmpty);
    expect(gateway.submissions, isEmpty);
    expect(cubit.state.error, 'Persetujuan diperlukan sebelum mengirim.');
  });

  test(
    'keeps failed feedback for retry and removes it after acknowledgement',
    () async {
      final vault = _MemorySecureVault();
      final gateway = _FakeFeedbackGateway()..shouldFail = true;
      final cubit = FeedbackCubit(FeedbackRepository(vault), gateway);
      addTearDown(cubit.close);

      await cubit.submit('Masukan tersimpan', consent: true);

      expect(cubit.state.pending, hasLength(1));
      expect(cubit.state.error, contains('belum terkirim'));
      final submissionId = cubit.state.pending.single.id;

      gateway.shouldFail = false;
      await cubit.retry(submissionId);

      expect(cubit.state.pending, isEmpty);
      expect(gateway.submissions, hasLength(2));
      expect(gateway.submissions.first.id, submissionId);
      expect(gateway.submissions.last.id, submissionId);
      expect(cubit.state.status, 'Feedback berhasil terkirim. Terima kasih.');
    },
  );
}

class _MemorySecureVault implements SecureVault {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class _FakeFeedbackGateway implements FeedbackGateway {
  bool shouldFail = false;
  final List<FeedbackSubmission> submissions = [];

  @override
  bool get isConfigured => true;

  @override
  Future<void> submit(FeedbackSubmission submission) async {
    submissions.add(submission);
    if (shouldFail) throw StateError('simulated offline');
  }
}
