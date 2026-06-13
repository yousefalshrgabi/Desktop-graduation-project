import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:charset_converter/charset_converter.dart';

/// Reads CSV text from [PlatformFile]: prefers non-empty [bytes], else native [path].
/// Detects between UTF-8 and Windows-1256 (for FET Arabic exports).
Future<String?> loadPickedCsvText(PlatformFile file) async {
  Uint8List? bytes;

  if (file.bytes != null && file.bytes!.isNotEmpty) {
    bytes = file.bytes;
  } else if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
    bytes = await File(file.path!).readAsBytes();
  }

  if (bytes == null) return null;

  try {
    // Try strict UTF-8 decoding first.
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    // If it fails, it's likely Windows-1256 (ANSI Arabic) from FET.
    try {
      return await CharsetConverter.decode("windows-1256", bytes);
    } catch (e) {
      // Fallback if the platform doesn't support charset_converter or it fails.
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}
