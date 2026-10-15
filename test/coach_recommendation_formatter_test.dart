import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/ride_coach/domain/coach_recommendation_formatter.dart';

void main() {
  test('cleans markdown while keeping the full advice', () {
    expect(
      formatCoachRecommendation(
        '**Jaga pace tetap stabil.**\n- Minum sekarang.',
      ),
      'Jaga pace tetap stabil. - Minum sekarang.',
    );
  });

  test('keeps the whole response instead of only the first sentence', () {
    expect(
      formatCoachRecommendation(
        'Jaga pace tetap stabil. Minum setiap dua puluh menit.',
      ),
      'Jaga pace tetap stabil. Minum setiap dua puluh menit.',
    );
  });

  test('drops a leading greeting but keeps the advice intact', () {
    expect(
      formatCoachRecommendation('Halo! Jaga pace tetap stabil. Minum sekarang.'),
      'Jaga pace tetap stabil. Minum sekarang.',
    );
    expect(
      formatCoachRecommendation('Hai, minum sekarang sebelum tanjakan.'),
      'minum sekarang sebelum tanjakan.',
    );
  });

  test('skips a greeting-only line and uses the next line', () {
    expect(
      formatCoachRecommendation('Halo!\nJaga pace tetap stabil.'),
      'Jaga pace tetap stabil.',
    );
  });
}
