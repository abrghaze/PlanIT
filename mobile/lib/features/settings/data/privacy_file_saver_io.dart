import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String> savePrivacyFileImpl(String filename, List<int> bytes) async {
  final directory = await getApplicationDocumentsDirectory();
  final exportDirectory = Directory(
    path.join(directory.path, 'PlanIT Exports'),
  );
  await exportDirectory.create(recursive: true);
  final file = File(path.join(exportDirectory.path, filename));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
