import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/saved_route_repository.dart';
import '../data/route_file_exchange.dart';
import '../data/route_planner_gateway.dart';
import '../domain/saved_route.dart';

class RoutesState {
  const RoutesState({
    this.query = '',
    this.routes = const [],
    this.isLoading = false,
    this.isPlanning = false,
    this.plannedRoute,
    this.message,
  });

  final String query;
  final List<RouteRecord> routes;
  final bool isLoading;
  final bool isPlanning;
  final RouteRecord? plannedRoute;
  final String? message;

  RoutesState copyWith({
    String? query,
    List<RouteRecord>? routes,
    bool? isLoading,
    bool? isPlanning,
    RouteRecord? plannedRoute,
    String? message,
    bool clearMessage = false,
    bool clearPlannedRoute = false,
  }) => RoutesState(
    query: query ?? this.query,
    routes: routes ?? this.routes,
    isLoading: isLoading ?? this.isLoading,
    isPlanning: isPlanning ?? this.isPlanning,
    plannedRoute: clearPlannedRoute ? null : plannedRoute ?? this.plannedRoute,
    message: clearMessage ? null : message ?? this.message,
  );
}

class RoutesCubit extends Cubit<RoutesState> {
  RoutesCubit(this.repository, this.fileExchange, {this.routePlanner})
    : super(const RoutesState());

  final SavedRouteRepository repository;
  final RouteFileExchange fileExchange;
  final RoutePlannerGateway? routePlanner;

  Future<void> load() => search('');

  Future<void> search(String query) async {
    emit(state.copyWith(query: query, isLoading: true, clearMessage: true));
    try {
      final routes = await repository.search(query);
      emit(state.copyWith(routes: routes, isLoading: false));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          message: 'Rute lokal tidak dapat dibuka.',
        ),
      );
    }
  }

  Future<void> importGpx() async {
    try {
      final imported = await fileExchange.importGpx();
      if (imported == null) return;
      await repository.saveImportedRoute(
        name: imported.name ?? 'Rute GPX impor',
        description: imported.description ?? '',
        points: [
          for (final point in imported.locations)
            (
              latitude: point.latitude,
              longitude: point.longitude,
              elevation: point.altitudeMeters,
            ),
        ],
      );
      await search(state.query);
    } on FormatException catch (error) {
      emit(state.copyWith(message: error.message));
    } catch (_) {
      emit(state.copyWith(message: 'GPX tidak dapat diimpor.'));
    }
  }

  Future<void> deleteImportedRoute(String routeId) async {
    try {
      await repository.deleteImportedRoute(routeId);
      await search(state.query);
      emit(state.copyWith(message: 'Rute GPX berhasil dihapus.'));
    } catch (error) {
      emit(
        state.copyWith(
          message: 'Rute GPX tidak dapat dihapus: $error',
        ),
      );
    }
  }

  Future<void> planCyclingRoute({
    required double originLatitude,
    required double originLongitude,
    required String destination,
  }) async {
    if (state.isPlanning) return;
    final planner = routePlanner;
    if (planner == null || !planner.isConfigured) {
      emit(
        state.copyWith(
          message: 'Pencarian rute Google Maps belum dikonfigurasi di backend.',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        isPlanning: true,
        clearMessage: true,
        clearPlannedRoute: true,
      ),
    );
    try {
      final route = await planner.planCyclingRoute(
        originLatitude: originLatitude,
        originLongitude: originLongitude,
        destination: destination,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          plannedRoute: route,
          isPlanning: false,
          message: 'Rute sepeda Google Maps siap ditampilkan.',
        ),
      );
    } catch (error) {
      if (isClosed) return;
      final message = error is FormatException || error is StateError
          ? error.toString().replaceFirst('FormatException: ', '')
              .replaceFirst('Bad state: ', '')
          : 'Rute tidak dapat dicari. Periksa koneksi dan coba lagi.';
      emit(
        state.copyWith(isPlanning: false, message: message),
      );
    }
  }

  void clearPlannedRoute() =>
      emit(state.copyWith(clearPlannedRoute: true, clearMessage: true));

  void clearMessage() => emit(state.copyWith(clearMessage: true));
}
