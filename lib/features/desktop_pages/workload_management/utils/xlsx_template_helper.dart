import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

/// Minimal Open XML (.xlsx) editor that preserves styles and merges.
class XlsxTemplateHelper {
  XlsxTemplateHelper._();

  static const _sheetPath = 'xl/worksheets/sheet1.xml';
  static const _sharedStringsPath = 'xl/sharedStrings.xml';
  static const _mainNs =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  static Future<({Archive archive, XlsxSheetEditor sheet})> loadTemplate(
    String assetPath,
  ) async {
    final templateBytes = await rootBundle.load(assetPath);
    final archive = ZipDecoder().decodeBytes(
      templateBytes.buffer.asUint8List(),
    );

    final sheetFile = archive.files.firstWhere(
      (f) => f.name == _sheetPath,
      orElse: () => throw Exception('ملف القالب غير صالح (لا يوجد sheet1)'),
    );
    final sheetXml = utf8.decode(sheetFile.content as List<int>);

    final shared = archive.files
        .where((f) => f.name == _sharedStringsPath)
        .toList();
    final sharedStrings = shared.isEmpty
        ? <String>[]
        : _parseSharedStrings(
            utf8.decode(shared.first.content as List<int>),
          );

    return (
      archive: archive,
      sheet: XlsxSheetEditor(sheetXml: sheetXml, sharedStrings: sharedStrings),
    );
  }

  static List<String> _parseSharedStrings(String xml) {
    final out = <String>[];
    final siPattern = RegExp(r'<si[^>]*>(.*?)</si>', dotAll: true);
    final tPattern = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);
    for (final si in siPattern.allMatches(xml)) {
      final chunk = si.group(1) ?? '';
      final texts = tPattern
          .allMatches(chunk)
          .map((m) => _unescapeXml(m.group(1) ?? ''))
          .join();
      out.add(texts);
    }
    return out;
  }

  static String _unescapeXml(String text) {
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static List<int> repackXlsx(Archive archive, XlsxSheetEditor sheet) {
    final sheetBytes = utf8.encode(sheet.sheetXml);
    final sharedBytes = utf8.encode(sheet.buildSharedStringsXml());

    final output = Archive();
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name == _sheetPath) {
        output.addFile(ArchiveFile(file.name, sheetBytes.length, sheetBytes));
      } else if (file.name == _sharedStringsPath) {
        output.addFile(
          ArchiveFile(file.name, sharedBytes.length, sharedBytes),
        );
      } else {
        output.addFile(file);
      }
    }

    if (!archive.files.any((f) => f.name == _sharedStringsPath)) {
      output.addFile(
        ArchiveFile(_sharedStringsPath, sharedBytes.length, sharedBytes),
      );
    }

    final encoded = ZipEncoder().encode(output);
    if (encoded == null) {
      throw Exception('فشل في توليد ملف Excel');
    }
    return encoded;
  }

  // Expose escape helper for external use
  static String escapeXml(String text) => _escapeXml(text);
}

class XlsxSheetEditor {
  XlsxSheetEditor({
    required this.sheetXml,
    required List<String> sharedStrings,
  }) : sharedStrings = List<String>.from(sharedStrings);

  String sheetXml;
  final List<String> sharedStrings;

  void setText(String cellRef, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _setCellValue(cellRef, innerXml: '');
      return;
    }
    final index = _indexForString(trimmed);
    _setCellValue(
      cellRef,
      innerXml: '<v>$index</v>',
      typeAttr: ' t="s"',
    );
  }

  void setNumber(String cellRef, num value) {
    final text = value is int ? '$value' : value.toString();
    _setCellValue(cellRef, innerXml: '<v>$text</v>');
  }

  int _indexForString(String value) {
    final existing = sharedStrings.indexOf(value);
    if (existing >= 0) return existing;
    sharedStrings.add(value);
    return sharedStrings.length - 1;
  }

  void _setCellValue(
    String cellRef, {
    required String innerXml,
    String typeAttr = '',
  }) {
    final rowNum = RegExp(r'\d+').firstMatch(cellRef)?.group(0);
    if (rowNum == null) return;

    final rowPattern = RegExp(
      '<row r="$rowNum"[^>]*>.*?</row>',
      dotAll: true,
    );
    final rowMatch = rowPattern.firstMatch(sheetXml);
    if (rowMatch == null) {
      throw Exception('صف $rowNum غير موجود في القالب');
    }

    var rowXml = rowMatch.group(0)!;
    final cellPattern = RegExp(
      '<c r="$cellRef"[^>]*/>|<c r="$cellRef"[^>]*>.*?</c>',
      dotAll: true,
    );
    final cellMatch = cellPattern.firstMatch(rowXml);

    if (cellMatch == null) {
      final insert = '<c r="$cellRef"$typeAttr>$innerXml</c>';
      rowXml = rowXml.replaceFirst('</row>', '$insert</row>');
    } else {
      final old = cellMatch.group(0)!;
      final styleMatch = RegExp(r's="(\d+)"').firstMatch(old);
      final style = styleMatch != null ? ' s="${styleMatch.group(1)}"' : '';
      final replacement = innerXml.isEmpty
          ? '<c r="$cellRef"$style$typeAttr/>'
          : '<c r="$cellRef"$style$typeAttr>$innerXml</c>';
      rowXml = rowXml.replaceFirst(old, replacement);
    }

    sheetXml = sheetXml.replaceRange(rowMatch.start, rowMatch.end, rowXml);
  }

  String buildSharedStringsXml() {
    final buffer = StringBuffer();
    buffer.write(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<sst xmlns="${XlsxTemplateHelper._mainNs}" count="${sharedStrings.length}" '
      'uniqueCount="${sharedStrings.length}">',
    );
    for (final text in sharedStrings) {
      final escaped = XlsxTemplateHelper.escapeXml(text);
      buffer.write('<si><t>$escaped</t></si>');
    }
    buffer.write('</sst>');
    return buffer.toString();
  }
}
