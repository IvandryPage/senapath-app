import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/session/data/readiness_checker.dart';

void main() {
  ReadinessReport report({
    bool permission = true,
    bool services = true,
    bool fix = false,
    bool checked = false,
  }) => ReadinessReport(
    locationPermissionGranted: permission,
    locationPermanentlyDenied: false,
    locationServicesEnabled: services,
    gpsFixAvailable: fix,
    gpsFixChecked: checked,
    accelerometerAvailable: true,
    gyroscopeAvailable: true,
    notificationsGranted: true,
    notificationsPermanentlyDenied: false,
  );

  test('allows a recording attempt only when permission and location are on', () {
    expect(report().canStartRecording, isTrue);
    expect(report(permission: false).canStartRecording, isFalse);
    expect(report(services: false).canStartRecording, isFalse);
  });

  test('distinguishes an unchecked GPS from a checked missing fix', () {
    expect(report().gpsFixChecked, isFalse);
    expect(report(checked: true).gpsFixChecked, isTrue);
    expect(report(fix: true, checked: true).gpsFixAvailable, isTrue);
  });
}
