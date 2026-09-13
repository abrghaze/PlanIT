import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

const _privacyFiles = MethodChannel('com.abrghaze.planit/privacy_files');

Future<String?> savePrivacyFileImpl(String filename, List<int> bytes) async {
  if (Platform.isAndroid) {
    return _privacyFiles.invokeMethod<String>('saveFile', <String, Object>{
      'filename': filename,
      'bytes': Uint8List.fromList(bytes),
      'mimeType': filename.toLowerCase().endsWith('.csv')
          ? 'text/csv'
          : 'application/json',
    });
  }
  final directory = await getApplicationDocumentsDirectory();
  final exportDirectory = Directory(
    path.join(directory.path, 'PlanIT Exports'),
  );
  await exportDirectory.create(recursive: true);
  final file = File(path.join(exportDirectory.path, filename));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<List<int>?> pickPrivacyFileImpl() async {
  if (!Platform.isAndroid) {
    throw UnsupportedError(
      'Portable-data restore is currently available on Android.',
    );
  }
  return _privacyFiles.invokeMethod<Uint8List>('openFile');
}
