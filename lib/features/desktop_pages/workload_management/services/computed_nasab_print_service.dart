import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/incentive_entry.dart';
import 'nasab_pdf_platform.dart';

/// Builds a PDF nasab table and saves it (desktop/mobile) or downloads it (web).
class ComputedNasabPrintService {
  Future<void> printEntries({
    required String title,
    required List<IncentiveEntry> entries,
    String? teacherFilter,
  }) async {
    if (entries.isEmpty) {
      throw Exception('لا توجد بيانات للطباعة');
    }

    final filtered = teacherFilter == null
        ? entries
        : entries
            .where((e) => e.teacherName.trim() == teacherFilter.trim())
            .toList();

    final bytes = await _buildPdf(
      title: title,
      entries: filtered,
      teacherFilter: teacherFilter,
    );

    await NasabPdfPlatform.openForPrint(
      bytes: bytes,
      fileName: teacherFilter != null
          ? 'نصاب_${teacherFilter.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}'
          : 'نصاب_محسوب',
    );
  }

  Future<Uint8List> _buildPdf({
    required String title,
    required List<IncentiveEntry> entries,
    String? teacherFilter,
  }) async {
    // تحميل خط عربي لدعم النص العربي في PDF
    pw.Font? fontRegular;
    pw.Font? fontBold;
    try {
      fontRegular = await _loadArabicFont(
        'https://fonts.gstatic.com/s/notokufikufi/v22/CSRp4ydQnPyaDxEXLFF6LZVLKrodhu8t57o1kDc5Wh5v.ttf',
      );
      fontBold = fontRegular;
    } catch (_) {
      // fallback: سيستخدم PDF الخط الافتراضي
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: fontRegular != null
            ? pw.ThemeData.withFont(base: fontRegular, bold: fontBold)
            : pw.ThemeData.base(),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          if (teacherFilter != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text('المدرس: $teacherFilter'),
            ),
          pw.TableHelper.fromTextArray(
            headers: const [
              'م',
              'المعلم',
              'المادة',
              'نظري',
              'عملي',
              'إشراف',
              'التخصص',
              'المستوى',
              'قسم المدرس',
            ],
            data: [
              for (var i = 0; i < entries.length; i++)
                [
                  '${i + 1}',
                  entries[i].teacherName,
                  entries[i].subject,
                  _cell(entries[i].theoryHours),
                  _cell(entries[i].practicalHours),
                  _cell(entries[i].supervisionHours),
                  entries[i].courseDepartment,
                  entries[i].level,
                  entries[i].sourceDepartment,
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerRight,
            headerAlignment: pw.Alignment.centerRight,
          ),
          pw.SizedBox(height: 12),
          pw.Text(_footerTotals(entries)),
        ],
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  static Future<pw.Font> _loadArabicFont(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('تعذر تحميل خط العربية للطباعة');
    }
    return pw.Font.ttf(response.bodyBytes.buffer.asByteData());
  }

  static String _cell(double v) {
    if (v == 0) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  static String _footerTotals(List<IncentiveEntry> entries) {
    final t = entries.fold<double>(0, (s, e) => s + e.theoryHours);
    final p = entries.fold<double>(0, (s, e) => s + e.practicalHours);
    final sup = entries.fold<double>(0, (s, e) => s + e.supervisionHours);
    return 'إجمالي نظري: ${_cell(t)} | عملي: ${_cell(p)} | إشراف: ${_cell(sup)} | '
        'المجموع: ${_cell(t + p + sup)}';
  }
}
