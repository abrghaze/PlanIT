Future<String?> savePrivacyFileImpl(String filename, List<int> bytes) {
  throw UnsupportedError(
    'File export is not available on this platform yet. Use PlanIT on Android or iOS.',
  );
}

Future<List<int>?> pickPrivacyFileImpl() {
  throw UnsupportedError(
    'Portable-data restore is currently available on Android.',
  );
}
