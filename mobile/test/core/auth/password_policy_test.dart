import 'package:flutter_test/flutter_test.dart';
import 'package:planit_mobile/core/auth/domain/password_policy.dart';

void main() {
  test('strong password satisfies every registration requirement', () {
    expect(PasswordPolicy.validate('A trustworthy password 9!'), isNull);
  });

  test('password policy reports every missing character class', () {
    expect(PasswordPolicy.missingRequirements('lowercase password'), <String>[
      'an uppercase letter',
      'a number',
      'a symbol',
    ]);
  });

  test('whitespace does not count as a symbol', () {
    expect(PasswordPolicy.hasSymbol('Password value 9'), isFalse);
  });

  test('password length matches the backend storage boundary', () {
    final tooLong = List<String>.filled(33, 'Aa9!').join();
    expect(PasswordPolicy.validate(tooLong), contains('128'));
  });
}
