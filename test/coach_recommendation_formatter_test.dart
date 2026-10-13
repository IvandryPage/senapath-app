import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/ride_coach/domain/coach_recommendation_formatter.dart';

void main() {
  test('formats a markdown recommendation as one clean sentence', () {
    expect(
      formatCoachRecommendation(
        '**Jaga pace tetap stabil.**\n- Minum sekarang.',
      ),
      'Jaga pace tetap stabil.',
    );
  });

  test('keeps only the first concise recommendation', () {
    expect(
      formatCoachRecommendation(
        '1. Jaga pace tetap stabil. Minum setiap dua puluh menit.',
      ),
      'Jaga pace tetap stabil.',
    );
  });

  test('limits long recommendations to fourteen words', () {
    final formatted = formatCoachRecommendation(
      'Atur pace tetap stabil dan simpan tenaga untuk tanjakan panjang '
      'yang akan kamu hadapi nanti di perjalanan ini.',
    );

    expect(formatted.split(' '), hasLength(14));
    expect(formatted, endsWith('…'));
  });
}
