import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/saved_route_repository.dart';
import '../domain/saved_route.dart';

class RoutesState {
  const RoutesState({
    this.query = '',
    this.routes = const [],
    this.isLoading = false,
    this.message,
  });

  final String query;
  final List<RouteRecord> routes;
  final bool isLoading;
  final String? message;

  RoutesState copyWith({
    String? query,
    List<RouteRecord>? routes,
    bool? isLoading,
    String? message,
    bool clearMessage = false,
  }) => RoutesState(
    query: query ?? this.query,
    routes: routes ?? this.routes,
    isLoading: isLoading ?? this.isLoading,
    message: clearMessage ? null : message ?? this.message,
  );
}

class RoutesCubit extends Cubit<RoutesState> {
  RoutesCubit(this.repository) : super(const RoutesState());

  final SavedRouteRepository repository;

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

  void clearMessage() => emit(state.copyWith(clearMessage: true));
}
