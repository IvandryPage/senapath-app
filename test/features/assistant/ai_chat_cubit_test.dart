import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/assistant/data/ai_chat_gateway.dart';
import 'package:senapath/features/assistant/domain/ai_chat_message.dart';
import 'package:senapath/features/assistant/presentation/ai_chat_cubit.dart';
import 'package:senapath/core/validation/validators.dart';

class FakeAiChatGateway implements AiChatGateway {
  FakeAiChatGateway({this.isConfigured = true, this.reply = 'Halo! 🚴'});

  @override
  final bool isConfigured;

  String reply;
  Object? error;
  final List<List<AiChatMessage>> sentMessages = [];

  @override
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  }) async {
    sentMessages.add(List.of(messages));
    final failure = error;
    if (failure != null) throw failure;
    return reply;
  }
}

void main() {
  group('AiChatCubit.sendMessage', () {
    test('appends the user message and the assistant reply', () async {
      final gateway = FakeAiChatGateway();
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      await cubit.sendMessage(content: 'Halo!');
      expect(cubit.state.messages, hasLength(2));
      expect(cubit.state.messages.first.role, 'user');
      expect(cubit.state.messages.first.content, 'Halo!');
      expect(cubit.state.messages.last.role, 'assistant');
      expect(cubit.state.messages.last.content, 'Halo! 🚴');
      expect(cubit.state.isSending, isFalse);
      expect(cubit.state.error, isNull);
      expect(gateway.sentMessages.single, hasLength(1));
    });

    test('ignores blank or whitespace-only messages', () async {
      final gateway = FakeAiChatGateway();
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      await cubit.sendMessage(content: '   ');
      expect(cubit.state.messages, isEmpty);
      expect(gateway.sentMessages, isEmpty);
    });

    test('rejects messages that exceed the length limit', () async {
      final gateway = FakeAiChatGateway();
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      await cubit.sendMessage(
        content: 'a' * (InputLimits.chatMessageMaxLength + 1),
      );
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.error, contains('karakter'));
    });

    test('reports an unconfigured assistant', () async {
      final gateway = FakeAiChatGateway(isConfigured: false);
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      expect(cubit.state.isConfigured, isFalse);
      await cubit.sendMessage(content: 'Halo!');
      expect(cubit.state.error, contains('belum dikonfigurasi'));
      expect(cubit.state.messages, isEmpty);
    });

    test('strips forbidden characters before sending', () async {
      final gateway = FakeAiChatGateway();
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      await cubit.sendMessage(content: 'Halo\u0000!');
      expect(cubit.state.messages.first.content, isNot(contains('\u0000')));
    });

    test('surfaces a friendly error for unknown failures', () async {
      final gateway = FakeAiChatGateway()..error = StateError('boom');
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      await cubit.sendMessage(content: 'Halo');
      expect(cubit.state.error, 'boom');
      expect(cubit.state.messages, hasLength(1), reason: 'the user message stays');
      expect(cubit.state.isSending, isFalse);
    });

    test('maps timeouts, format errors and network errors', () async {
      Future<void> expectError(Object error, Object expected) async {
        final gateway = FakeAiChatGateway()..error = error;
        final cubit = AiChatCubit(gateway);
        addTearDown(cubit.close);
        await cubit.sendMessage(content: 'Halo');
        expect(cubit.state.error, expected);
      }

      await expectError(
        TimeoutException('slow'),
        'Asisten belum menjawab. Coba lagi.',
      );
      await expectError(
        const FormatException('bad json'),
        'Jawaban tidak dapat dibaca. Coba kirim ulang.',
      );
      await expectError(
        Exception('network'),
        contains('Periksa koneksi internet'),
      );
    });
  });

  group('AiChatCubit.clearConversation', () {
    test('drops the history and cancels pending replies', () async {
      final completer = Completer<String>();
      final gateway = _BlockingGateway(completer);
      final cubit = AiChatCubit(gateway);
      addTearDown(cubit.close);

      final pending = cubit.sendMessage(content: 'Halo');
      expect(cubit.state.isSending, isTrue);

      cubit.clearConversation();
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.isSending, isFalse);

      completer.complete('late');
      await pending;
      expect(cubit.state.messages, isEmpty, reason: 'stale replies are ignored');
    });
  });
}

class _BlockingGateway implements AiChatGateway {
  _BlockingGateway(this.completer);

  final Completer<String> completer;

  @override
  bool get isConfigured => true;

  @override
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  }) => completer.future;
}
