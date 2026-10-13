import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/saved_route_repository.dart';
import '../data/route_file_exchange.dart';
import '../domain/saved_route.dart';

class RoutesState {
  const RoutesState({
    this.query = '',
    this.routes = const [],
    this.isLoading = false,
    this.sessionRoute,
    this.sessionRouteSelected = false,
    this.message,
  });

  final String query;
  final List<RouteRecord> routes;
  final bool isLoading;
  final RouteRecord? sessionRoute;
  final bool sessionRouteSelected;
  final String? message;

  RoutesState copyWith({
    String? query,
    List<RouteRecord>? routes,
    bool? isLoading,
    RouteRecord? sessionRoute,
    bool? sessionRouteSelected,
    String? message,
    bool clearMessage = false,
    bool clearSessionRoute = false,
  }) => RoutesState(
    query: query ?? this.query,
    routes: routes ?? this.routes,
    isLoading: isLoading ?? this.isLoading,
    sessionRoute: clearSessionRoute ? null : sessionRoute ?? this.sessionRoute,
    sessionRouteSelected: sessionRouteSelected ?? this.sessionRouteSelected,
    message: clearMessage ? null : message ?? this.message,
  );
}

class RoutesCubit extends Cubit<RoutesState> {
  RoutesCubit(this.repository, this.fileExchange) : super(const RoutesState());

  final SavedRouteRepository repository;
  final RouteFileExchange fileExchange;

  Future<void> load() async {
    await search('');
    try {
      final route = await repository.loadSelectedSessionRoute();
      if (route != null) {
        emit(state.copyWith(sessionRoute: route, sessionRouteSelected: true));
      }
    } catch (_) {
      emit(
        state.copyWith(
          message: 'Rute terakhir yang dipilih tidak dapat dibuka.',
        ),
      );
    }
  }

  Future<void> search(String query) async {
    emit(state.copyWith(query: query, isLoading: true, clearMessage: true));
    try {
      final routes = await repository.search(query);
      emit(state.copyWith(routes: routes, isLoading: false));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          message: 'Daftar rute di ponsel tidak dapat dibuka.',
        ),
      );
    }
  }

  Future<void> importGpx() async {
    try {
      final imported = await fileExchange.importGpx();
      if (imported == null) return;
      await repository.saveImportedRoute(
        name: imported.name ?? 'Rute dari file',
        description: imported.description ?? '',
        checkpoints: imported.checkpoints,
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
      emit(
        state.copyWith(
          message: 'File rute tidak dapat dibuka. Pastikan file GPX valid.',
        ),
      );
    }
  }

  Future<void> deleteImportedRoute(String routeId) async {
    try {
      await repository.deleteImportedRoute(routeId);
      await search(state.query);
      emit(
        state.copyWith(
          clearSessionRoute: state.sessionRoute?.id == routeId,
          message: 'Rute berhasil dihapus.',
        ),
      );
    } catch (error) {
      emit(state.copyWith(message: 'Rute tidak dapat dihapus. Coba lagi.'));
    }
  }

  void selectSessionRoute(RouteRecord? route) {
    emit(
      state.copyWith(
        sessionRoute: route,
        clearSessionRoute: route == null,
        sessionRouteSelected: true,
        clearMessage: true,
      ),
    );
    unawaited(
      repository.saveSelectedSessionRoute(route?.id).catchError((Object error) {
        emit(
          state.copyWith(message: 'Pilihan rute tidak dapat disimpan: $error'),
        );
      }),
    );
  }

  void clearMessage() => emit(state.copyWith(clearMessage: true));
}
