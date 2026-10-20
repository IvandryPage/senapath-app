import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/logistics/domain/event_time_converter.dart';

void main() {
  group('EventTimeZone', () {
    test('has known destinations', () {
      expect(EventTimeZone.destinations, contains(EventTimeZone.london));
      expect(EventTimeZone.wib.ianaName, 'Asia/Jakarta');
      expect(EventTimeZone.wita.ianaName, 'Asia/Makassar');
      expect(EventTimeZone.wit.ianaName, 'Asia/Jayapura');
    });

    test('looks up zones by IANA name', () {
      expect(EventTimeZone.fromIanaName('Europe/London'), EventTimeZone.london);
      expect(EventTimeZone.fromIanaName('nope/not-a-zone'), isNull);
    });

    test('compares by IANA name only', () {
      expect(
        EventTimeZone('Custom', 'Europe/London'),
        EventTimeZone.london,
      );
      expect(
        EventTimeZone('Custom', 'Europe/London').hashCode,
        EventTimeZone.london.hashCode,
      );
    });

    test('lists many zones and replaces underscores in labels', () {
      final all = EventTimeZone.all;
      expect(all.length, greaterThan(100));
      expect(all.any((zone) => zone.ianaName == 'Europe/Berlin'), isTrue);
      expect(
        all.every((zone) => zone.ianaName.contains('/') || zone.ianaName == 'UTC'),
        isTrue,
      );
      final withUnderscore = all.firstWhere(
        (zone) => zone.ianaName.contains('_'),
        orElse: () => EventTimeZone.london,
      );
      expect(withUnderscore.label, isNot(contains('_')));
    });
  });

  group('EventTimeConverter.resolveLocalTime', () {
    final converter = EventTimeConverter();

    test('resolves an unambiguous local time in summer', () {
      final resolution = converter.resolveLocalTime(
        DateTime(2026, 7, 10, 14, 30),
        EventTimeZone.london,
      );
      expect(resolution.isNonexistent, isFalse);
      expect(resolution.isAmbiguous, isFalse);
      final instant = resolution.instants.single;
      // BST (UTC+1) in July: 14:30 local == 13:30 UTC.
      expect(instant.toUtc(), DateTime.utc(2026, 7, 10, 13, 30));
    });

    test('detects a nonexistent local time during a spring-forward gap', () {
      // London skips 01:00-02:00 local on 2026-03-29.
      final resolution = converter.resolveLocalTime(
        DateTime(2026, 3, 29, 1, 30),
        EventTimeZone.london,
      );
      expect(resolution.isNonexistent, isTrue);
      expect(resolution.instants, isEmpty);
    });

    test('detects an ambiguous local time during a fall-back overlap', () {
      final resolution = converter.resolveLocalTime(
        DateTime(2026, 10, 25, 1, 30),
        EventTimeZone.london,
      );
      expect(resolution.isAmbiguous, isTrue);
      expect(resolution.instants, hasLength(2));
    });
  });

  group('EventTimeConverter.convertInstant', () {
    final converter = EventTimeConverter();

    test('converts an instant into a destination zone', () {
      final converted = converter.convertInstant(
        DateTime.utc(2026, 1, 5, 12),
        EventTimeZone.wib,
      );
      expect(converted.hour, 19);
      expect(converted.timeZoneName, 'WIB');
      expect(
        converted.toUtc(),
        DateTime.utc(2026, 1, 5, 12),
      );
    });
  });
}
