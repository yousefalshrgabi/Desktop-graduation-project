import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';

import '../models/incentive_entry.dart';
import '../utils/app_file_saver.dart';
import '../utils/docx_template_helper.dart';

/// Fills «كليشة استمارة نصاب عضو هيئة تدريس» Word template for one teacher.
class IncentiveWordExportService {
  static const _templateAsset =
      'assets/templates/faculty_workload_template.docx';

  Future<void> exportTeacherNasab({
    required String teacherName,
    required List<IncentiveEntry> entries,
  }) async {
    final filtered = entries
        .where((e) => e.teacherName.trim() == teacherName.trim())
        .toList();
    if (filtered.isEmpty) {
      throw Exception('لا توجد بيانات نصاب لهذا المدرس');
    }

    final loaded = await DocxTemplateHelper.loadTemplate(_templateAsset);
    var documentXml = loaded.documentXml;

    final primaryDept = _primaryDepartment(filtered);

    documentXml = DocxTemplateHelper.replacePlaceholders(documentXml, {
      '<اسم المدرس>': teacherName,
      '<المهمة الإدارية>': '—',
    });
    if (primaryDept.isNotEmpty) {
      documentXml = documentXml.replaceAll('تقنية معلومات', primaryDept);
    }

    final tables = DocxTemplateHelper.extractTopLevelTables(documentXml);
    if (tables.isEmpty) {
      throw Exception('جدول النصاب غير موجود في القالب');
    }

    final filledTable = _fillTeachingTable(tables[0].xml, filtered);
    documentXml = documentXml.replaceRange(
      tables[0].start,
      tables[0].end,
      filledTable,
    );

    final outBytes = DocxTemplateHelper.repackDocx(
      loaded.archive,
      utf8.encode(documentXml),
    );

    final safeName = teacherName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    await AppFileSaver.saveExportedFile(
      name: 'نصاب_$safeName',
      bytes: Uint8List.fromList(outBytes),
      ext: 'docx',
      mimeType: MimeType.microsoftWord,
    );
  }

  static String _primaryDepartment(List<IncentiveEntry> entries) {
    final counts = <String, int>{};
    for (final e in entries) {
      final d = e.sourceDepartment.trim();
      if (d.isEmpty) continue;
      counts[d] = (counts[d] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String _fillTeachingTable(
    String tableXml,
    List<IncentiveEntry> entries,
  ) {
    final rows = DocxTemplateHelper.splitRows(tableXml);
    if (rows.length < 3) {
      throw Exception('بنية جدول النصاب في القالب غير متوقعة');
    }

    final header = rows.sublist(0, 2);
    final dataTemplate = rows[2];
    final footer = rows.last;

    final dataRows = <String>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      var row = dataTemplate;
      row = DocxTemplateHelper.setCellText(row, 0, '${i + 1}');
      row = DocxTemplateHelper.setCellText(row, 1, e.subject);
      row = DocxTemplateHelper.setCellText(
        row,
        2,
        DocxTemplateHelper.formatNum(e.theoryHours),
      );
      row = DocxTemplateHelper.setCellText(
        row,
        3,
        DocxTemplateHelper.formatNum(e.practicalHours),
      );
      row = DocxTemplateHelper.setCellText(
        row,
        4,
        DocxTemplateHelper.formatNum(e.supervisionHours),
      );
      row = DocxTemplateHelper.setCellText(row, 5, e.courseDepartment);
      row = DocxTemplateHelper.setCellText(row, 6, e.level);
      row = DocxTemplateHelper.setCellText(row, 7, e.sourceDepartment);
      dataRows.add(row);
    }

    final sumTheory =
        entries.fold<double>(0, (s, e) => s + e.theoryHours);
    final sumPractical =
        entries.fold<double>(0, (s, e) => s + e.practicalHours);
    final sumSupervision =
        entries.fold<double>(0, (s, e) => s + e.supervisionHours);

    var footerRow = footer;
    if (DocxTemplateHelper.splitCells(footerRow).length > 1) {
      footerRow = DocxTemplateHelper.setCellText(
        footerRow,
        1,
        'نظري: ${DocxTemplateHelper.formatNum(sumTheory)} | '
        'عملي: ${DocxTemplateHelper.formatNum(sumPractical)} | '
        'إشراف: ${DocxTemplateHelper.formatNum(sumSupervision)} | '
        'الإجمالي: ${DocxTemplateHelper.formatNum(sumTheory + sumPractical + sumSupervision)}',
      );
    }

    return DocxTemplateHelper.joinRows(
      tableXml,
      [...header, ...dataRows, footerRow],
    );
  }
}
