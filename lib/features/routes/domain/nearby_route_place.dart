enum NearbyRoutePlaceCategory {
  trainStation('Stasiun kereta', 'railway station'),
  busTerminal('Terminal', 'bus station'),
  clinic('Klinik / fasilitas kesehatan', 'clinic'),
  bicycleRepair('Bengkel sepeda', 'bicycle repair');

  const NearbyRoutePlaceCategory(this.label, this.iconName);

  final String label;
  final String iconName;
}

class NearbyRoutePlace {
  const NearbyRoutePlace({
    required this.osmType,
    required this.osmId,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
  });

  final String osmType;
  final int osmId;
  final String name;
  final NearbyRoutePlaceCategory category;
  final double latitude;
  final double longitude;

  Uri get osmUri => Uri.https('www.openstreetmap.org', '/$osmType/$osmId');
}
