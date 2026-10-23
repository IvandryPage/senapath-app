import 'package:flutter/material.dart';

import '../domain/route_wind.dart';

class RouteWindIndicator extends StatelessWidget {
  /// Membuat indikator arah angin relatif terhadap arah rute.
  const RouteWindIndicator({
    required this.wind,
    required this.routeHeadingDegrees,
    required this.onPressed,
    this.isLoading = false,
    this.hasError = false,
    this.isLocationReady = true,
    super.key,
  });

  final RouteWindObservation? wind;
  final double? routeHeadingDegrees;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool hasError;
  final bool isLocationReady;

  /// Membangun tombol ikon angin yang berputar sesuai arah relatif.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final heading = routeHeadingDegrees;
    final observation = wind;
    final description = observation == null || heading == null
        ? !isLocationReady
              ? 'Arah angin menunggu lokasi GPS yang akurat.'
              : hasError
              ? 'Arah angin tidak tersedia. Ketuk untuk mencoba lagi.'
              : 'Ketuk untuk mengambil arah angin di lokasi saat ini.'
        : '${relativeWindDescription(windFromDegrees: observation.directionFromDegrees, routeHeadingDegrees: heading)} relatif arah rute';
    return Tooltip(
      message: description,
      child: Semantics(
        label: description,
        button: true,
        child: Material(
          color: colors.surface.withValues(alpha: 0.76),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: colors.onSurface.withValues(alpha: 0.55),
                        ),
                      )
                    : Transform.rotate(
                        angle: observation == null || heading == null
                            ? 0
                            : windArrowRotationRadians(
                                windFromDegrees:
                                    observation.directionFromDegrees,
                                routeHeadingDegrees: heading,
                              ),
                        child: Icon(
                          observation == null
                              ? Icons.air
                              : Icons.navigation_outlined,
                          size: 24,
                          color: colors.onSurface.withValues(
                            alpha: observation == null ? 0.42 : 0.68,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
