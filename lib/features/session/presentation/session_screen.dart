import 'package:flutter/material.dart';

import '../../../core/widgets/feature_state_view.dart';

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureStateView.empty(
      title: 'Perekaman belum dimulai',
      message:
          'Status kesiapan perangkat dan kontrol sesi akan tersedia di sini.',
      icon: Icons.directions_bike_outlined,
    );
  }
}
