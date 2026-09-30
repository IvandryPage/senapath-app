import 'package:flutter/material.dart';

import '../../../core/widgets/feature_state_view.dart';

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureStateView.empty(
      title: 'Belum ada rute tersimpan',
      message: 'Rute yang tersedia akan ditampilkan di sini.',
      icon: Icons.map_outlined,
    );
  }
}
