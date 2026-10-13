import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/session/data/ambient_light_source.dart';

void main() {
  test('ambient contrast uses hysteresis around the bright threshold', () {
    expect(shouldUseHighAmbientContrast(isBright: false, lux: 9999), isFalse);
    expect(shouldUseHighAmbientContrast(isBright: false, lux: 10000), isTrue);
    expect(shouldUseHighAmbientContrast(isBright: true, lux: 7000), isTrue);
    expect(shouldUseHighAmbientContrast(isBright: true, lux: 6999), isFalse);
  });

  test('invalid lux values preserve the current contrast state', () {
    expect(shouldUseHighAmbientContrast(isBright: true, lux: -1), isTrue);
    expect(shouldUseHighAmbientContrast(isBright: false, lux: -1), isFalse);
  });
}
