import 'package:flutter/material.dart';

import '../../../app/theme/senapath_design.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      Text(
        'Mata Kuliah Pemrograman Aplikasi Mobile',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 20),
      SenapathCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
            'Integer vitae justo sed sapien consequat feugiat. '
            'Curabitur non magna at erat facilisis tincidunt. '
            'Vestibulum ante ipsum primis in faucibus orci luctus et '
            'ultrices posuere cubilia curae; praesent eget lectus at '
            'nibh blandit consequat.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    ],
  );
}
