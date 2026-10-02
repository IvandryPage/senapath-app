import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class EventTimeZone {
  const EventTimeZone(this.label, this.ianaName);

  static const london = EventTimeZone('London', 'Europe/London');
  static const centralEurope = EventTimeZone(
    'Central Europe (CET/CEST)',
    'Europe/Berlin',
  );
  static const wib = EventTimeZone('WIB', 'Asia/Jakarta');
  static const wita = EventTimeZone('WITA', 'Asia/Makassar');
  static const wit = EventTimeZone('WIT', 'Asia/Jayapura');
  static const destinations = [london, wib, wita, wit];

  final String label;
  final String ianaName;

  static List<EventTimeZone> get all {
    _initializeTimezoneDatabase();
    return [
      for (final name in timezone.timeZoneDatabase.locations.keys)
        if (name == 'UTC' || name.contains('/'))
          EventTimeZone(name.replaceAll('_', ' '), name),
    ];
  }

  static EventTimeZone? fromIanaName(String name) {
    _initializeTimezoneDatabase();
    if (!timezone.timeZoneDatabase.locations.containsKey(name)) return null;
    return EventTimeZone(name.replaceAll('_', ' '), name);
  }

  @override
  bool operator ==(Object other) =>
      other is EventTimeZone && other.ianaName == ianaName;

  @override
  int get hashCode => ianaName.hashCode;
}

class LocalTimeResolution {
  const LocalTimeResolution(this.instants);

  final List<timezone.TZDateTime> instants;

  bool get isNonexistent => instants.isEmpty;
  bool get isAmbiguous => instants.length > 1;
}

class EventTimeConverter {
  EventTimeConverter() {
    _initializeTimezoneDatabase();
  }

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

bool _isTimezoneDatabaseInitialized = false;

void _initializeTimezoneDatabase() {
  if (_isTimezoneDatabaseInitialized) return;
  timezone_data.initializeTimeZones();
  _isTimezoneDatabaseInitialized = true;
}
