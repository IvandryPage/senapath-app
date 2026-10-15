import 'package:flutter/material.dart';

import '../domain/rider_progress.dart';

class RiderAvatar extends StatelessWidget {
  const RiderAvatar({
    required this.style,
    required this.appearance,
    this.size = 52,
    super.key,
  });

  final RiderStyle style;
  final RiderAppearance appearance;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accessoryIcon = switch (appearance.accessory) {
      RiderAccessory.helmet => Icons.sports_motorsports,
      RiderAccessory.glasses => Icons.visibility,
      RiderAccessory.none => null,
    };
    return Semantics(
      label:
          '${style.label}, jersey ${appearance.kitColor.label}, '
          '${appearance.accessory.label}',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: size / 2,
              backgroundColor: Color(appearance.kitColor.value),
              child: Icon(_styleIcon, color: Colors.white, size: size * 0.56),
            ),
            if (accessoryIcon != null)
              Positioned(
                right: -size * 0.025,
                bottom: -size * 0.025,
                child: CircleAvatar(
                  radius: size * 0.19,
                  backgroundColor: Colors.white,
                  child: Icon(
                    accessoryIcon,
                    size: size * 0.23,
                    color: Color(appearance.kitColor.value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData get _styleIcon => switch (style) {
    RiderStyle.sprinter => Icons.bolt,
    RiderStyle.climber => Icons.terrain,
    RiderStyle.puncheur => Icons.landscape,
    RiderStyle.rouleur => Icons.directions_bike,
    RiderStyle.timetrialist => Icons.timer,
    RiderStyle.domestique => Icons.groups,
    RiderStyle.leadout => Icons.flag,
    RiderStyle.explorer => Icons.explore,
    RiderStyle.ace => Icons.stars,
  };
}
