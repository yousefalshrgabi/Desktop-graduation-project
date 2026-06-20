import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:academic_affairs_management/features/desktop_pages/workload_management/utils/docx_template_helper.dart';

class DocxExportService {
  /// توليد البايتات الخام لملف مايكروسوفت وورد .docx صالح يحتوي على محضر الاجتماع.
  static List<int> createDocx({
    required String title,
    required String date,
    required String time,
    required List<String> agenda,
    required List<String> attendees,
    required String minutes,
  }) {
    final archive = Archive();

    // 1. ملف [Content_Types].xml
    const contentTypesXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/markup-compatibility/2006">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    // 2. ملف _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    // 3. ملف word/document.xml
    // دالة مساعدة لتعقيم نصوص XML لتفادي مشاكل الرموز الخاصة
    String sanitize(String input) {
      return input
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&apos;');
    }

    final StringBuffer bodyContent = StringBuffer();

    // فقرة العنوان (عريض وبحجم خط كبير)
    bodyContent.write('''
    <w:p>
      <w:pPr>
        <w:jc w:val="center"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:b/>
          <w:sz w:val="36"/>
          <w:szCs w:val="36"/>
        </w:rPr>
        <w:t>${sanitize(title)}</w:t>
      </w:r>
    </w:p>
    ''');

    // تفاصيل التاريخ والوقت
    bodyContent.write('''
    <w:p>
      <w:r>
        <w:rPr><w:b/></w:rPr>
        <w:t>التاريخ: </w:t>
      </w:r>
      <w:r>
        <w:t>${sanitize(date)}</w:t>
      </w:r>
      <w:r>
        <w:t>   |   </w:t>
      </w:r>
      <w:r>
        <w:rPr><w:b/></w:rPr>
        <w:t>الوقت: </w:t>
      </w:r>
      <w:r>
        <w:t>${sanitize(time)}</w:t>
      </w:r>
    </w:p>
    ''');

    // خط فاصل بين الأقسام
    bodyContent.write('''
    <w:p>
      <w:r>
        <w:t>--------------------------------------------------------------------------------</w:t>
      </w:r>
    </w:p>
    ''');

    // قسم الحاضرين
    bodyContent.write('''
    <w:p>
      <w:r>
        <w:rPr>
          <w:b/>
          <w:sz w:val="28"/>
        </w:rPr>
        <w:t>الحاضرون:</w:t>
      </w:r>
    </w:p>
    ''');

    for (final attendee in attendees) {
      bodyContent.write('''
      <w:p>
        <w:r>
          <w:t>• ${sanitize(attendee)}</w:t>
        </w:r>
      </w:p>
      ''');
    }

    bodyContent.write('<w:p><w:r><w:t></w:t></w:r></w:p>'); // مسافة فارغة

    // قسم جدول الأعمال
    bodyContent.write('''
    <w:p>
      <w:r>
        <w:rPr>
          <w:b/>
          <w:sz w:val="28"/>
        </w:rPr>
        <w:t>جدول الأعمال:</w:t>
      </w:r>
    </w:p>
    ''');

    for (int i = 0; i < agenda.length; i++) {
      bodyContent.write('''
      <w:p>
        <w:r>
          <w:t>${i + 1}. ${sanitize(agenda[i])}</w:t>
        </w:r>
      </w:p>
      ''');
    }

    bodyContent.write('<w:p><w:r><w:t></w:t></w:r></w:p>'); // مسافة فارغة

    // نص تفاصيل المحضر والمناقشات
    bodyContent.write('''
    <w:p>
      <w:r>
        <w:rPr>
          <w:b/>
          <w:sz w:val="28"/>
        </w:rPr>
        <w:t>المحضر والمناقشات:</w:t>
      </w:r>
    </w:p>
    ''');

    final minutesLines = minutes.split('\n');
    for (final line in minutesLines) {
      if (line.trim().isEmpty) continue;
      bodyContent.write('''
      <w:p>
        <w:r>
          <w:t>${sanitize(line)}</w:t>
        </w:r>
      </w:p>
      ''');
    }

    final documentXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${bodyContent.toString()}
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''';

    // إضافة الملفات إلى ملف ZIP المضغوط للوورد
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length,
        utf8.encode(contentTypesXml)));
    archive.addFile(
        ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));
    archive.addFile(ArchiveFile(
        'word/document.xml', documentXml.length, utf8.encode(documentXml)));

    final encoder = ZipEncoder();
    return encoder.encode(archive)!;
  }

  /// توليد البايتات الخام لاستمارة طلب الإجازة بناءً على القالب المرفق.
  static Future<List<int>> createLeaveRequestDocx({
    required String applicantName,
    required String college,
    required String department,
    required String leaveType,
    required String duration,
    required String startDate,
    required String requestDate,
    required List<dynamic> approvalHistory,
  }) async {
    final loaded = await DocxTemplateHelper.loadTemplate(
        'assets/templates/leave_template.docx');
    var documentXml = loaded.documentXml;

    String formatDate(dynamic dateVal) {
      if (dateVal == null) return '';
      try {
        final dt = DateTime.parse(dateVal.toString());
        return "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}";
      } catch (_) {
        return dateVal.toString();
      }
    }

    String deptHeadName = '....................';
    String deptHeadDate = '....................';
    String deanName = '....................';
    String deanDate = '....................';
    String vpName = '....................';
    String vpDate = '....................';

    for (final step in approvalHistory) {
      if (step is Map) {
        final stepNum = step['step'];
        final name = step['approver_name'] ?? step['name'] ?? '';
        final date = formatDate(step['date'] ?? step['timestamp']);

        if (stepNum == 1) {
          deptHeadName = name;
          deptHeadDate = date;
        } else if (stepNum == 3) {
          deanName = name;
          deanDate = date;
        } else if (stepNum == 4) {
          vpName = name;
          vpDate = date;
        }
      }
    }

    final bool isHajj = leaveType.contains('حج') || leaveType.contains('الحج');
    final bool isUmrah =
        leaveType.contains('عمرة') || leaveType.contains('العمرة');
    final bool isChildbirth = leaveType.contains('وضع');
    final bool isSick =
        leaveType.contains('مرض') || leaveType.contains('المرض');
    final bool isCompanion =
        leaveType.contains('مرافقة') || leaveType.contains('المرافقة');
    final bool isEmergency =
        leaveType.contains('اضطرار') || leaveType.contains('الاضطرارية');

    documentXml = DocxTemplateHelper.replacePlaceholders(documentXml, {
      '{{applicantName}}': applicantName,
      '{{college}}': college,
      '{{department}}': department,
      '{{duration}}': duration,
      '{{startDate}}': startDate,
      '{{requestDate}}': requestDate,
      '{{deptHeadName}}': deptHeadName,
      '{{deptHeadDate}}': deptHeadDate,
      '{{deanName}}': deanName,
      '{{deanDate}}': deanDate,
      '{{vpName}}': vpName,
      '{{vpDate}}': vpDate,
      '{{isHajj}}': isHajj ? '✔' : '  ',
      '{{isUmrah}}': isUmrah ? '✔' : '  ',
      '{{isChildbirth}}': isChildbirth ? '✔' : '  ',
      '{{isSick}}': isSick ? '✔' : '  ',
      '{{isCompanion}}': isCompanion ? '✔' : '  ',
      '{{isEmergency}}': isEmergency ? '✔' : '  ',
    });

    return DocxTemplateHelper.repackDocx(
        loaded.archive, utf8.encode(documentXml));
  }
}
