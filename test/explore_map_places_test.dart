import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/routes/domain/nearby_route_place.dart';
import 'package:senapath/features/routes/presentation/explore_map.dart';

void main() {
  testWidgets('shows nearby OSM places as tappable map markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExploreMap(
            nearbyPlaces: [
              NearbyRoutePlace(
                osmType: 'node',
                osmId: 22,
                name: 'Klinik Sehat',
                category: NearbyRoutePlaceCategory.clinic,
                latitude: -6.2,
                longitude: 106.8,
              ),
            ],
            showLocationButton: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final markers = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers;
    expect(markers, hasLength(1));
    final marker = markers.single;
    expect(marker.point.latitude, -6.2);
    expect(marker.point.longitude, 106.8);
    expect(marker.child, isA<Tooltip>());
    expect(
      (marker.child as Tooltip).message,
      'Klinik Sehat · Klinik / fasilitas kesehatan',
    );
  });
}
