import 'package:planit_mobile/features/settings/data/privacy_file_saver_stub.dart'
    if (dart.library.io) 'package:planit_mobile/features/settings/data/privacy_file_saver_io.dart';

Future<String> savePrivacyFile(String filename, List<int> bytes) =>
    savePrivacyFileImpl(filename, bytes);
