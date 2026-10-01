import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/feature_state_view.dart';
import '../domain/saved_route.dart';
import 'routes_cubit.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final _searchController = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(context.read<RoutesCubit>().load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoutesCubit, RoutesState>(
      listenWhen: (previous, current) =>
          previous.message != current.message && current.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
        context.read<RoutesCubit>().clearMessage();
      },
      child: BlocBuilder<RoutesCubit, RoutesState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) =>
                            context.read<RoutesCubit>().search(value),
                        decoration: InputDecoration(
                          hintText: 'Cari rute tersimpan',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              context.read<RoutesCubit>().search('');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Impor GPX',
                      onPressed: state.isLoading
                          ? null
                          : () => context.read<RoutesCubit>().importGpx(),
                      icon: const Icon(Icons.file_upload_outlined),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildResults(state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResults(RoutesState state) {
    if (state.isLoading) return const FeatureStateView.loading();
    if (state.routes.isEmpty) {
      return FeatureStateView.empty(
        title: state.query.isEmpty
            ? 'Belum ada rute tersimpan'
            : 'Rute tidak ditemukan',
        message: state.query.isEmpty
            ? 'Rute offline akan muncul setelah provider peta atau impor rute dikonfigurasi.'
            : 'Coba kata kunci lain atau periksa data rute offline.',
        icon: Icons.map_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: state.routes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _RouteTile(route: state.routes[index]),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({required this.route});

  final RouteRecord route;

  @override
  Widget build(BuildContext context) {
    final distance = route.distanceMeters == null
        ? 'Jarak tidak tersedia'
        : '${(route.distanceMeters! / 1000).toStringAsFixed(1)} km';
    final elevation = route.elevationGainMeters == null
        ? 'Elevasi tidak tersedia'
        : '+${route.elevationGainMeters!.toStringAsFixed(0)} m';
    final poi = route.poiSummary.isEmpty
        ? 'POI belum tersedia'
        : route.poiSummary;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.route_outlined),
        title: Text(route.name),
        subtitle: Text('$distance · $elevation\n$poi\nSumber: ${route.source}'),
        isThreeLine: true,
        trailing: route.availability == 'offline'
            ? const Tooltip(
                message: 'Tersedia offline',
                child: Icon(Icons.cloud_off_outlined),
              )
            : const Icon(Icons.cloud_done_outlined),
      ),
    );
  }
}
