import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'Perjalanan dimulai dari persiapan yang baik.',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
        ),
        const SizedBox(height: 8),
        Text(
          'Ringkasan latihan dan balapanmu akan muncul di sini.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        Text(
          'Aktivitas terbaru',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.route_outlined, color: colorScheme.primary),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Belum ada sesi',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text('Sesi yang selesai akan tersimpan di sini.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Lanjutkan',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.map_outlined, color: colorScheme.primary),
          title: const Text('Rute'),
          subtitle: const Text('Rute tersimpan dan pencarian'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/routes'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.directions_bike_outlined,
            color: colorScheme.primary,
          ),
          title: const Text('Sesi'),
          subtitle: const Text('Status dan perekaman perjalanan'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/session'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.flash_on_outlined, color: colorScheme.primary),
          title: const Text('Tes reaksi'),
          subtitle: const Text('Latihan respons visual dua menit'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/reaction'),
        ),
      ],
    );
  }
}
