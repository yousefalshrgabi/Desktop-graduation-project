import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Reads CSV text from [PlatformFile]: prefers non-empty [bytes], else native [path].
Future<String?> loadPickedCsvText(PlatformFile file) async {
  if (file.bytes != null && file.bytes!.isNotEmpty) {
    return utf8.decode(file.bytes!, allowMalformed: true);
  }
  if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
    return File(file.path!).readAsString(encoding: utf8);
  }
  return null;
}
