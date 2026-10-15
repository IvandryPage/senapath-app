import 'package:flutter/material.dart';

import '../../../app/theme/senapath_design.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      Text(
        'Saran dan Kesan',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(
        'Catatan untuk pengembangan Senapath.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      const _FeedbackNoteCard(
        icon: Icons.lightbulb_outline,
        title: 'Saran',
        message:
            'Terus kembangkan fitur navigasi dan informasi rute agar pesepeda '
            'dapat merencanakan perjalanan dengan lebih nyaman.',
      ),
      const SizedBox(height: 12),
      const _FeedbackNoteCard(
        icon: Icons.favorite_outline,
        title: 'Kesan',
        message:
            'Senapath membantu mencatat aktivitas bersepeda dan mendukung '
            'perjalanan menjadi lebih terencana.',
      ),
    ],
  );
}

class _FeedbackNoteCard extends StatelessWidget {
  const _FeedbackNoteCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => SenapathCard(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
