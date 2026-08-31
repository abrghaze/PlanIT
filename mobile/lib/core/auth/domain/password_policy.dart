final class PasswordPolicy {
  const PasswordPolicy._();

  static const int minimumLength = 12;
  static const int maximumLength = 128;

  static bool hasMinimumLength(String value) => value.length >= minimumLength;
  static bool hasUppercase(String value) => value.contains(RegExp('[A-Z]'));
  static bool hasLowercase(String value) => value.contains(RegExp('[a-z]'));
  static bool hasNumber(String value) => value.contains(RegExp('[0-9]'));
  static bool hasSymbol(String value) =>
      value.contains(RegExp(r'[^A-Za-z0-9\s]'));

  static List<String> missingRequirements(String value) => <String>[
    if (!hasMinimumLength(value)) '$minimumLength characters',
    if (!hasUppercase(value)) 'an uppercase letter',
    if (!hasLowercase(value)) 'a lowercase letter',
    if (!hasNumber(value)) 'a number',
    if (!hasSymbol(value)) 'a symbol',
  ];

  static String? validate(String? value) {
    final password = value ?? '';
    if (password.length > maximumLength) {
      return 'Use no more than $maximumLength characters.';
    }
    final missing = missingRequirements(password);
    return missing.isEmpty ? null : 'Add ${missing.join(', ')}.';
  }
}
