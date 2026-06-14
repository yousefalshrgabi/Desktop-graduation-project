import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

/// Saves exported files on all platforms.
///
/// On web, [FileSaver.saveAs] is not implemented — the browser triggers a direct
/// download via [FileSaver.saveFile] instead.
class AppFileSaver {
  AppFileSaver._();

  static Future<void> saveExportedFile({
    required String name,
    required Uint8List bytes,
    required String ext,
    required MimeType mimeType,
  }) async {
    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        fileExtension: ext,
        mimeType: mimeType,
      );
      return;
    }

    // استخدام file_picker لفتح نافذة حفظ آمنة تدعم اللغة العربية على ويندوز
    final String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'حفظ الملف',
      fileName: '$name.$ext',
      type: FileType.custom,
      allowedExtensions: [ext],
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsBytes(bytes);
    }
  }
}
