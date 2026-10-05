import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/assistant/data/ai_chat_gateway.dart';
import 'package:senapath/features/assistant/domain/ai_chat_message.dart';
import 'package:senapath/features/assistant/presentation/ai_chat_cubit.dart';
import 'package:senapath/features/assistant/presentation/ai_chat_screen.dart';
import 'package:senapath/features/routes/data/route_file_exchange.dart';
import 'package:senapath/features/routes/data/saved_route_repository.dart';
import 'package:senapath/features/routes/presentation/routes_cubit.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/session_file_service.dart';

void main() {
  testWidgets('shows a familiar chat composer and appends AI replies', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final routesCubit = RoutesCubit(
      SavedRouteRepository(
        database,
        geometryCodec: EncryptedTelemetryCodec(
          secureVault: _MemorySecureVault(),
        ),
      ),
      const RouteFileExchange(SessionFileService()),
    );
    final chatCubit = AiChatCubit(_FakeAiChatGateway());
    addTearDown(routesCubit.close);
    addTearDown(chatCubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: routesCubit),
          BlocProvider.value(value: chatCubit),
        ],
        child: const MaterialApp(home: Scaffold(body: AiChatScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apa yang ingin kamu rencanakan?'), findsOneWidget);
    expect(find.byKey(const Key('ai-chat-composer')), findsOneWidget);

    await tester.tap(find.text('Bantu susun strategi untuk tanjakan panjang'));
    await tester.pump();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-chat-send')));
    await tester.pumpAndSettle();

    expect(
      find.text('Bantu susun strategi untuk tanjakan panjang'),
      findsOneWidget,
    );
    expect(
      find.text('Mulai dari ritme yang nyaman dan jaga tenaga.'),
      findsOneWidget,
    );
  });
}

class _FakeAiChatGateway implements AiChatGateway {
  @override
  bool get isConfigured => true;

  @override
  Future<String> send({
    required List<AiChatMessage> messages,
    required Map<String, Object?> context,
  }) async => 'Mulai dari ritme yang nyaman dan jaga tenaga.';
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
