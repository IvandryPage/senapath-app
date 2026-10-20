import 'package:flutter_test/flutter_test.dart';
import 'package:senapath/features/authentication/data/biometric_sign_in_settings_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  group('BiometricSignInSettingsRepository', () {
    test('defaults to disabled', () async {
      final repository = BiometricSignInSettingsRepository(createTestDatabase());
      expect(await repository.load(), isFalse);
    });

    test('persists the enabled flag', () async {
      final database = createTestDatabase();
      addTearDown(database.close);

      final repository = BiometricSignInSettingsRepository(database);
      await repository.save(true);
      expect(await repository.load(), isTrue);

      await repository.save(false);
      expect(await BiometricSignInSettingsRepository(database).load(), isFalse);
    });
  });
}
