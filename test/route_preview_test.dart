import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/core/storage/app_database.dart';
import 'package:senapath/core/storage/secure_vault.dart';
import 'package:senapath/features/routes/data/route_file_exchange.dart';
import 'package:senapath/features/routes/data/saved_route_repository.dart';
import 'package:senapath/features/routes/presentation/routes_cubit.dart';
import 'package:senapath/features/routes/presentation/routes_screen.dart';
import 'package:senapath/features/session/data/encrypted_telemetry_codec.dart';
import 'package:senapath/features/session/data/session_file_service.dart';

void main() {
  testWidgets('opens an imported route as an offline path preview', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = SavedRouteRepository(
      database,
      geometryCodec: EncryptedTelemetryCodec(secureVault: _MemorySecureVault()),
    );
    await repository.saveImportedRoute(
      name: 'Loop Utara',
      points: const [
        (latitude: -6.2, longitude: 106.8, elevation: 10),
        (latitude: -6.202, longitude: 106.804, elevation: 24),
        (latitude: -6.205, longitude: 106.801, elevation: 18),
      ],
    );
    final cubit = RoutesCubit(
      repository,
      const RouteFileExchange(SessionFileService()),
    );
    await cubit.load();
    addTearDown(cubit.close);
    addTearDown(database.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: Scaffold(body: RoutesScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loop Utara'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Jejak GPX lokal'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Jejak rute offline dengan 3 titik'),
      findsOneWidget,
    );
    expect(find.text('Ikuti rute'), findsOneWidget);
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
