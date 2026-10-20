import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/ride_coach/data/ride_coach_gateway.dart';
import 'package:senapath/features/ride_coach/domain/coach_recommendation_formatter.dart';
import 'package:senapath/features/ride_coach/presentation/ride_coach_cubit.dart';

class FakeRideCoachGateway implements RideCoachGateway {
  FakeRideCoachGateway({this.isConfigured = true, this.isSignedIn = true});

  @override
  final bool isConfigured;
  @override
  final bool isSignedIn;

  String recommendation = 'Pelan-pelan saja hari ini.';
  String briefing = 'Briefing untuk rute besok.';
  String diagnoseMessage = 'Konfigurasi lengkap.';
  Object? recommendError;
  Object? briefingError;
  Object? diagnoseError;

  @override
  Future<String> diagnoseConfiguration() async {
    final failure = diagnoseError;
    if (failure != null) throw failure;
    return diagnoseMessage;
  }

  @override
  Future<String> recommend({
    required Map<String, Object?> rideContext,
    required bool consent,
  }) async {
    final failure = recommendError;
    if (failure != null) throw failure;
    return recommendation;
  }

  @override
  Future<String> prepareRide({
    required Map<String, Object?> routeAndWeather,
    required bool consent,
  }) async {
    final failure = briefingError;
    if (failure != null) throw failure;
    return briefing;
  }
}

void main() {
  group('formatCoachRecommendation', () {
    test('strips markdown markers and collapses whitespace', () {
      expect(
        formatCoachRecommendation(
          '**Pelan-pelan** _saja_, ini *saran* `singkat`.',
        ),
        'Pelan-pelan saja, ini saran singkat.',
      );
      expect(
        formatCoachRecommendation('# Judul\nBaris kedua.'),
        'Judul Baris kedua.',
      );
    });

    test('removes code fences and their contents', () {
      expect(
        formatCoachRecommendation(
          'Saran.\n```dart\nfinal x = 1;\n```\nSelesai.',
        ),
        'Saran. Selesai.',
      );
    });

    test('removes leading list markers', () {
      expect(
        formatCoachRecommendation('- Minum air yang cukup.'),
        'Minum air yang cukup.',
      );
      expect(
        formatCoachRecommendation('1. Pemanasan dulu.'),
        'Pemanasan dulu.',
      );
      expect(
        formatCoachRecommendation('• Istirahat yang cukup'),
        'Istirahat yang cukup',
      );
    });

    test('removes greetings in Indonesian and Arabic openers', () {
      expect(
        formatCoachRecommendation('Halo! Hari ini kamu harus pulih.'),
        'Hari ini kamu harus pulih.',
      );
      expect(
        formatCoachRecommendation('Selamat pagi, jangan lupa pemanasan.'),
        'jangan lupa pemanasan.',
      );
      expect(
        formatCoachRecommendation('Assalamualaikum, tetap jaga ritme.'),
        'tetap jaga ritme.',
      );
      expect(
        formatCoachRecommendation('Hai, sprint 30 detik ya.'),
        'sprint 30 detik ya.',
      );
    });

    test('removes the marker again when it follows the greeting', () {
      expect(
        formatCoachRecommendation('- Halo!\n  - Fokus ke napas.'),
        'Fokus ke napas.',
      );
    });

    test('handles empty and marker-only input', () {
      expect(formatCoachRecommendation(''), '');
      expect(formatCoachRecommendation('```'), '');
      expect(formatCoachRecommendation('-'), '');
    });
  });

  group('RideCoachCubit session consent', () {
    test('granting consent requires the active session', () {
      final cubit = RideCoachCubit(FakeRideCoachGateway());
      addTearDown(cubit.close);

      expect(cubit.grantConsentForSession('s1'), isFalse);
      cubit.setActiveSession('s1');
      expect(cubit.grantConsentForSession('s2'), isFalse);
      expect(cubit.grantConsentForSession('s1'), isTrue);
      expect(cubit.hasConsentForSession('s1'), isTrue);
    });

    test('changing the active session clears consent and recommendation', () async {
      final cubit = RideCoachCubit(FakeRideCoachGateway());
      addTearDown(cubit.close);

      cubit.setActiveSession('s1');
      await cubit.recommend(rideContext: const {}, consent: true);
      expect(cubit.state.recommendation, isNotNull);

      cubit.setActiveSession('s2');
      expect(cubit.state.recommendation, isNull);
      expect(cubit.hasConsentForSession('s1'), isFalse);
      expect(cubit.lastRequestAt, isNull);
    });
  });

  group('RideCoachCubit.recommend', () {
    test('emits the recommendation', () async {
      final cubit = RideCoachCubit(FakeRideCoachGateway());
      addTearDown(cubit.close);

      await cubit.recommend(rideContext: const {'speed': 20}, consent: true);
      expect(cubit.state.recommendation, 'Pelan-pelan saja hari ini.');
      expect(cubit.state.error, isNull);
      expect(cubit.state.isLoading, isFalse);
    });

    test('shows the StateError message on failure', () async {
      final gateway = FakeRideCoachGateway()
        ..recommendError = StateError('Butuh koneksi');
      final cubit = RideCoachCubit(gateway);
      addTearDown(cubit.close);

      await cubit.recommend(rideContext: const {}, consent: true);
      expect(cubit.state.error, 'Butuh koneksi');
      expect(cubit.state.recommendation, isNull);
    });

    test('shows a friendly message for other failures', () async {
      final gateway = FakeRideCoachGateway()..recommendError = Exception('x');
      final cubit = RideCoachCubit(gateway);
      addTearDown(cubit.close);

      await cubit.recommend(rideContext: const {}, consent: true);
      expect(cubit.state.error, contains('Saran belum tersedia'));
    });
  });

  group('RideCoachCubit.prepareRide', () {
    test('emits the briefing with the route id', () async {
      final cubit = RideCoachCubit(FakeRideCoachGateway());
      addTearDown(cubit.close);

      await cubit.prepareRide(
        routeId: 'r1',
        routeAndWeather: const {'distance': 40},
        consent: true,
      );
      expect(cubit.state.preRideBriefing, 'Briefing untuk rute besok.');
      expect(cubit.state.preRideRouteId, 'r1');
      expect(cubit.state.preRideError, isNull);
    });

    test('reports briefing failures', () async {
      final gateway = FakeRideCoachGateway()
        ..briefingError = StateError('Prakiraan cuaca tidak tersedia');
      final cubit = RideCoachCubit(gateway);
      addTearDown(cubit.close);

      await cubit.prepareRide(
        routeId: 'r1',
        routeAndWeather: const {},
        consent: true,
      );
      expect(cubit.state.preRideError, 'Prakiraan cuaca tidak tersedia');
    });
  });

  group('RideCoachCubit.diagnoseConfiguration', () {
    test('emits the diagnosis notice', () async {
      final cubit = RideCoachCubit(FakeRideCoachGateway());
      addTearDown(cubit.close);

      await cubit.diagnoseConfiguration();
      expect(cubit.state.notice, 'Konfigurasi lengkap.');
      expect(cubit.state.error, isNull);
    });

    test('reports diagnosis failures', () async {
      final gateway = FakeRideCoachGateway()
        ..diagnoseError = StateError('Kunci API hilang');
      final cubit = RideCoachCubit(gateway);
      addTearDown(cubit.close);

      await cubit.diagnoseConfiguration();
      expect(cubit.state.error, 'Kunci API hilang');
    });
  });
}
