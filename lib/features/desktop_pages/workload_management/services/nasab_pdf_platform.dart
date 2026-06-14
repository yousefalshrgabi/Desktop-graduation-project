import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

import '../utils/app_file_saver.dart';

/// Saves PDF locally (desktop/mobile/web).
class NasabPdfPlatform {
  static Future<void> openForPrint({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await AppFileSaver.saveExportedFile(
      name: fileName,
      bytes: bytes,
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }
}
