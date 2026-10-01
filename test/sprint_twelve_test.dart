import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/assistant/data/ai_chat_gateway.dart';
import 'package:senapath/features/assistant/domain/ai_chat_message.dart';
import 'package:senapath/features/assistant/presentation/ai_chat_cubit.dart';

void main() {
  test('logout clearing discards an in-flight chat response', () async {
    final gateway = _PendingAiChatGateway();
    final cubit = AiChatCubit(gateway);
    addTearDown(cubit.close);

    final send = cubit.sendMessage(content: 'Rute latihan saya', consent: true);
    await gateway.started.future;
    expect(cubit.state.messages, hasLength(1));

    cubit.clearConversation();
    gateway.reply.complete('Jawaban privat');
    await send;

    expect(cubit.state.messages, isEmpty);
    expect(cubit.state.isSending, isFalse);
  });
}

class _PendingAiChatGateway implements AiChatGateway {
  final started = Completer<void>();
  final reply = Completer<String>();

  @override
  bool get isConfigured => true;

  @override
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  }) {
    started.complete();
    return reply.future;
  }
}
