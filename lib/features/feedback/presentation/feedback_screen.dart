import 'package:flutter/material.dart';

import '../../../app/theme/senapath_design.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      Text(
        'Masukan untuk Senapath',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 20),
      SenapathCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Formulir untuk mengirim masukan belum tersedia.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    ],
  );
}
