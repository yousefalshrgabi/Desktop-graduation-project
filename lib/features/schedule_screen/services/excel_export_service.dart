import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';

class ExcelExportService {
  /// Exports a 2D array representing a table to an Excel file and triggers a save dialog.
  Future<void> exportTable({
    required String fileName,
    required String title,
    required List<String> headers,
    required List<List<String>> dataRows,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Title Row
    sheet.appendRow([TextCellValue(title)]);

    // Empty spacer
    sheet.appendRow([TextCellValue('')]);

    // Headers
    List<CellValue> headerCells = headers.map((h) => TextCellValue(h)).toList();
    sheet.appendRow(headerCells);

    // Data rows
    for (final row in dataRows) {
      List<CellValue> cells = row.map((c) => TextCellValue(c)).toList();
      sheet.appendRow(cells);
    }

    // Generate Bytes
    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      throw Exception('فشل في توليد ملف الإكسل (Bytes = null)');
    }

    // Save File
    if (!kIsWeb && Platform.isWindows) {
      String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'حفظ ملف الإكسل',
        fileName: '$fileName.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        if (!outputFile.toLowerCase().endsWith('.xlsx')) {
          outputFile += '.xlsx';
        }
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
      }
    } else {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }
}
