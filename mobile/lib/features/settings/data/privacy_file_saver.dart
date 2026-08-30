import 'privacy_file_saver_stub.dart'
    if (dart.library.io) 'privacy_file_saver_io.dart';

Future<String> savePrivacyFile(String filename, List<int> bytes) =>
    savePrivacyFileImpl(filename, bytes);
