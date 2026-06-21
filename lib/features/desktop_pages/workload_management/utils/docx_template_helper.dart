import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

/// Shared helpers for editing Word DOCX templates (Open XML).
class DocxTemplateHelper {
  DocxTemplateHelper._();

  static Future<({Archive archive, String documentXml})> loadTemplate(
    String assetPath,
  ) async {
    final templateBytes = await rootBundle.load(assetPath);
    final decoded = ZipDecoder().decodeBytes(
      templateBytes.buffer.asUint8List(),
    );
    final docFile = decoded.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('ملف القالب غير صالح'),
    );
    final documentXml = utf8.decode(docFile.content as List<int>);
    return (archive: decoded, documentXml: documentXml);
  }

  static List<int> repackDocx(Archive decoded, List<int> documentXml) {
    return repackDocxFiles(
      decoded,
      {'word/document.xml': documentXml},
    );
  }

  static List<int> repackDocxFiles(
    Archive decoded,
    Map<String, List<int>> replacements,
  ) {
    final outputArchive = Archive();
    for (final file in decoded.files) {
      if (!file.isFile) continue;
      final replacement = replacements[file.name];
      if (replacement != null) {
        outputArchive.addFile(
          ArchiveFile(file.name, replacement.length, replacement),
        );
      } else {
        outputArchive.addFile(file);
      }
    }
    final encoded = ZipEncoder().encode(outputArchive);
    if (encoded == null) {
      throw Exception('فشل في توليد ملف Word');
    }
    return encoded;
  }

  static String? readXmlFile(Archive archive, String path) {
    final file = archive.files.where((f) => f.name == path).firstOrNull;
    if (file == null || !file.isFile) return null;
    return utf8.decode(file.content as List<int>);
  }

  static String setParagraphText(String paragraphXml, String text) {
    final pPr = RegExp(r'<w:pPr[^>]*>.*?</w:pPr>', dotAll: true)
            .firstMatch(paragraphXml)
            ?.group(0) ??
        '';
    final rPr = RegExp(r'<w:rPr[^>]*>.*?</w:rPr>', dotAll: true)
            .firstMatch(paragraphXml)
            ?.group(0) ??
        '';
    return '<w:p>$pPr${buildRunsXml(text, rPr: rPr)}</w:p>';
  }

  static String replaceParagraphsWhere(
    String xml,
    bool Function(String text) test,
    String Function(String text) replacement,
  ) {
    return xml.replaceAllMapped(
      RegExp(r'<w:p[^>]*>.*?</w:p>', dotAll: true),
      (match) {
        final paragraph = match.group(0)!;
        final text = extractText(paragraph);
        if (!test(text)) return paragraph;
        return setParagraphText(paragraph, replacement(text));
      },
    );
  }

  static String extractText(String xml) {
    return RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true)
        .allMatches(xml)
        .map((m) => m.group(1) ?? '')
        .join()
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"');
  }

  static String replacePlaceholders(
    String xml,
    Map<String, String> placeholders,
  ) {
    var result = xml;
    for (final entry in placeholders.entries) {
      final escaped = escapeXml(sanitizeText(entry.value));
      
      // Build a regex that matches the placeholder even if it is split by XML tags.
      // Word often splits text like {{isHajj}} into `<w:t>{{is</w:t></w:r><w:r><w:t>Hajj}}</w:t>`.
      final chars = entry.key.split('').map((c) => RegExp.escape(c));
      final pattern = chars.join(r'(?:<[^>]+>)*');
      
      try {
        final regex = RegExp(pattern);
        result = result.replaceAll(regex, escaped);
      } catch (e) {
        // Fallback to simple replace if regex fails
        result = result.replaceAll(entry.key, escaped);
      }
    }
    return result;
  }

  static List<TableSpan> extractTopLevelTables(String xml) {
    final spans = <TableSpan>[];
    var depth = 0;
    int? start;
    for (var i = 0; i < xml.length; i++) {
      if (xml.startsWith('<w:tbl>', i)) {
        if (depth == 0) start = i;
        depth++;
        i += 6;
      } else if (xml.startsWith('</w:tbl>', i)) {
        depth--;
        if (depth == 0 && start != null) {
          final end = i + 8;
          spans.add(TableSpan(start, end, xml.substring(start, end)));
          start = null;
        }
        i += 7;
      }
    }
    return spans;
  }

  static List<String> splitRows(String tableXml) {
    return RegExp(r'<w:tr[^>]*>.*?</w:tr>', dotAll: true)
        .allMatches(tableXml)
        .map((m) => m.group(0)!)
        .toList();
  }

  static String joinRows(String tableXml, List<String> rows) {
    var index = 0;
    return tableXml.replaceAllMapped(
      RegExp(r'<w:tr[^>]*>.*?</w:tr>', dotAll: true),
      (match) {
        if (index >= rows.length) return '';
        return rows[index++];
      },
    );
  }

  static String replaceTableRows(String tableXml, List<String> rows) {
    final matches =
        RegExp(r'<w:tr[^>]*>.*?</w:tr>', dotAll: true).allMatches(tableXml);
    if (matches.isEmpty) return tableXml;

    final first = matches.first;
    final last = matches.last;
    return tableXml.replaceRange(first.start, last.end, rows.join());
  }

  static List<String> splitCells(String rowXml) {
    return RegExp(r'<w:tc[^>]*>.*?</w:tc>', dotAll: true)
        .allMatches(rowXml)
        .map((m) => m.group(0)!)
        .toList();
  }

  static String setCellText(String rowXml, int cellIndex, String text) {
    final cells = splitCells(rowXml);
    if (cellIndex < 0 || cellIndex >= cells.length) return rowXml;
    cells[cellIndex] = setCellContent(cells[cellIndex], text);
    var cellIndexWalk = 0;
    return rowXml.replaceAllMapped(
      RegExp(r'<w:tc[^>]*>.*?</w:tc>', dotAll: true),
      (match) {
        if (cellIndexWalk >= cells.length) return match.group(0)!;
        return cells[cellIndexWalk++];
      },
    );
  }

  static String setCellContent(String cellXml, String text) {
    final sanitized = sanitizeText(text);
    final paragraphMatch =
        RegExp(r'<w:p[^>]*>.*?</w:p>', dotAll: true).firstMatch(cellXml);

    if (paragraphMatch == null) {
      final runs = buildRunsXml(sanitized);
      return cellXml.replaceFirst(
        '</w:tc>',
        '<w:p>$runs</w:p></w:tc>',
      );
    }

    final paragraph = paragraphMatch.group(0)!;
    final pPr = RegExp(r'<w:pPr[^>]*>.*?</w:pPr>', dotAll: true)
            .firstMatch(paragraph)
            ?.group(0) ??
        '';
    final rPr = RegExp(r'<w:rPr[^>]*>.*?</w:rPr>', dotAll: true)
            .firstMatch(paragraph)
            ?.group(0) ??
        '';

    final runs = buildRunsXml(sanitized, rPr: rPr);
    final newParagraph = '<w:p>$pPr$runs</w:p>';
    return cellXml.replaceFirst(paragraph, newParagraph);
  }

  static String buildRunsXml(String text, {String rPr = ''}) {
    if (text.isEmpty) {
      return '<w:r>$rPr<w:t></w:t></w:r>';
    }

    final lines = text.split('\n');
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final escaped = escapeXml(lines[i]);
      buffer.write('<w:r>$rPr<w:t xml:space="preserve">$escaped</w:t></w:r>');
      if (i < lines.length - 1) {
        buffer.write('<w:r>$rPr<w:br /></w:r>');
      }
    }
    return buffer.toString();
  }

  static String sanitizeText(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune == 0x9 ||
          rune == 0xA ||
          rune == 0xD ||
          (rune >= 0x20 && rune <= 0xD7FF) ||
          (rune >= 0xE000 && rune <= 0xFFFD)) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static String escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String formatNum(double v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class TableSpan {
  const TableSpan(this.start, this.end, this.xml);

  final int start;
  final int end;
  final String xml;
}
