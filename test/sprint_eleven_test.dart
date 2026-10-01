import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/feedback/data/feedback_gateway.dart';
import 'package:senapath/features/feedback/data/feedback_repository.dart';
import 'package:senapath/features/feedback/domain/feedback_submission.dart';
import 'package:senapath/features/feedback/presentation/feedback_cubit.dart';

void main() {
  test('requires consent before saving or sending feedback', () async {
    final vault = _MemorySecureVault();
    final gateway = _FakeFeedbackGateway();
    final cubit = FeedbackCubit(FeedbackRepository(vault), gateway);
    addTearDown(cubit.close);

    await cubit.load();
    final accepted = await cubit.submit('Rute bagus', consent: false);

    expect(accepted, isFalse);
    expect(gateway.submittedIds, isEmpty);
    expect(await FeedbackRepository(vault).loadPending(), isEmpty);
  });

  test(
    'keeps an encrypted outbox entry and retries with the same id',
    () async {
      final vault = _MemorySecureVault();
      final repository = FeedbackRepository(vault);
      final gateway = _FakeFeedbackGateway()..shouldFail = true;
      final firstCubit = FeedbackCubit(repository, gateway);
      await firstCubit.load();

      final accepted = await firstCubit.submit(
        'Mohon tambah petunjuk elevasi.',
        consent: true,
      );
      final pendingId = firstCubit.state.pending.single.id;
      expect(accepted, isTrue);
      expect(firstCubit.state.error, contains('belum terkirim'));
      await firstCubit.close();

      gateway.shouldFail = false;
      final retryCubit = FeedbackCubit(repository, gateway);
      await retryCubit.load();
      await retryCubit.retry(pendingId);

      expect(gateway.submittedIds, [pendingId, pendingId]);
      expect(retryCubit.state.pending, isEmpty);
      expect(retryCubit.state.status, contains('berhasil terkirim'));
      expect(await repository.loadPending(), isEmpty);
      await retryCubit.close();
    },
  );

  test('queues feedback locally when Supabase is not configured', () async {
    final repository = FeedbackRepository(_MemorySecureVault());
    final gateway = _FakeFeedbackGateway(isConfigured: false);
    final cubit = FeedbackCubit(repository, gateway);
    await cubit.load();

    await cubit.submit('Tambah opsi ekspor.', consent: true);

    expect(gateway.submittedIds, isEmpty);
    expect(cubit.state.pending, hasLength(1));
    expect(cubit.state.status, contains('Belum terkirim'));
    await cubit.close();
  });
}

class _MemorySecureVault implements SecureVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _FakeFeedbackGateway implements FeedbackGateway {
  _FakeFeedbackGateway({this.isConfigured = true});

  @override
  final bool isConfigured;
  bool shouldFail = false;
  final submittedIds = <String>[];

  @override
  Future<void> submit(FeedbackSubmission submission) async {
    submittedIds.add(submission.id);
    if (shouldFail) throw StateError('Offline');
  }
}
