import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

enum EventTimeZone {
  london('London', 'Europe/London'),
  centralEurope('Central Europe (CET/CEST)', 'Europe/Berlin'),
  wib('WIB', 'Asia/Jakarta'),
  wita('WITA', 'Asia/Makassar'),
  wit('WIT', 'Asia/Jayapura');

  const EventTimeZone(this.label, this.ianaName);

  final String label;
  final String ianaName;

  static const destinations = [london, wib, wita, wit];
}

class LocalTimeResolution {
  const LocalTimeResolution(this.instants);

  final List<timezone.TZDateTime> instants;

  bool get isNonexistent => instants.isEmpty;
  bool get isAmbiguous => instants.length > 1;
}

class EventTimeConverter {
  EventTimeConverter() {
    if (!_isTimezoneDatabaseInitialized) {
      timezone_data.initializeTimeZones();
      _isTimezoneDatabaseInitialized = true;
    }
  }

  static bool _isTimezoneDatabaseInitialized = false;

  LocalTimeResolution resolveLocalTime(DateTime localTime, EventTimeZone zone) {
    final location = timezone.getLocation(zone.ianaName);
    final wallTime = DateTime.utc(
      localTime.year,
      localTime.month,
      localTime.day,
      localTime.hour,
      localTime.minute,
      localTime.second,
      localTime.millisecond,
      localTime.microsecond,
    );
    final candidates = <int>{};

    // Accept only offsets that round-trip to the same local wall time.
    for (final timeZone in location.zones) {
      final instant =
          wallTime.millisecondsSinceEpoch - timeZone.offset.inMilliseconds;
      if (location.timeZone(instant).offset != timeZone.offset) continue;
      final converted = timezone.TZDateTime.fromMillisecondsSinceEpoch(
        location,
        instant,
      );
      if (_sameComponents(converted, localTime)) candidates.add(instant);
    }

    final instants = candidates.toList()..sort();
    return LocalTimeResolution([
      for (final instant in instants)
        timezone.TZDateTime.fromMillisecondsSinceEpoch(location, instant),
    ]);
  }

  timezone.TZDateTime convertInstant(
    DateTime instant,
    EventTimeZone destination,
  ) => timezone.TZDateTime.from(
    instant.toUtc(),
    timezone.getLocation(destination.ianaName),
  );

  bool _sameComponents(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute &&
      a.second == b.second &&
      a.millisecond == b.millisecond &&
      a.microsecond == b.microsecond;
}
