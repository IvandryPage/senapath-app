import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SenapathApp extends StatelessWidget {
  const SenapathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Senapath',
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
