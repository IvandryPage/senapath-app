import 'package:flutter/material.dart';

import '../../../core/widgets/feature_state_view.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureStateView.empty(
      title: 'Profil belum tersedia',
      message: 'Informasi akun akan ditampilkan di sini.',
      icon: Icons.person_outline,
    );
  }
}
