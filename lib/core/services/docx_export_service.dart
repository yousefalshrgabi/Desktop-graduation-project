import 'dart:convert';
import 'package:archive/archive.dart';

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
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    // 2. ملف _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

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
    final String cleanMinutes = minutes.trim();
    final bool isFullMinutes =
        cleanMinutes.startsWith('بسم الله الرحمن الرحيم') ||
            cleanMinutes.contains('محضر الاجتماع الدوري');

    if (isFullMinutes) {
      final lines = cleanMinutes.split('\n');
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) {
          // Empty paragraph for spacing
          bodyContent.write('<w:p><w:r><w:t></w:t></w:r></w:p>');
          continue;
        }

        // Determine styling based on content
        bool isCentered = false;
        bool isBold = false;
        int fontSize = 24; // 12pt in Word

        if (trimmedLine == 'بسم الله الرحمن الرحيم') {
          isCentered = true;
          isBold = true;
          fontSize = 28;
        } else if (trimmedLine.startsWith('محضر الاجتماع الدوري')) {
          isCentered = true;
          isBold = true;
          fontSize = 32;
        } else if (trimmedLine.startsWith('كلية') &&
            (trimmedLine.contains('للعام') || trimmedLine.contains('قسم'))) {
          isCentered = true;
          isBold = true;
          fontSize = 28;
        } else if (trimmedLine.endsWith(':') ||
            trimmedLine == 'الحاضرون' ||
            trimmedLine == 'نقاط الاجتماع' ||
            trimmedLine == 'سير الاجتماع' ||
            trimmedLine == 'المستجدات' ||
            trimmedLine == 'ختام الاجتماع' ||
            trimmedLine == 'التوقيع') {
          isBold = true;
          fontSize = 26;
        } else if (trimmedLine.startsWith('قرار المجلس رقم')) {
          isBold = true;
          fontSize = 24;
        }

        if (isCentered) {
          bodyContent.write(
              '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:bCs/><w:sz w:val="$fontSize"/><w:szCs w:val="$fontSize"/><w:rtl w:val="1"/><w:lang w:bidi="ar-SA"/></w:rPr><w:t>${sanitize(trimmedLine)}</w:t></w:r></w:p>');
        } else {
          bodyContent.write(
              '<w:p><w:r><w:rPr>${isBold ? '<w:b/><w:bCs/>' : ''}<w:sz w:val="$fontSize"/><w:szCs w:val="$fontSize"/><w:rtl w:val="1"/><w:lang w:bidi="ar-SA"/></w:rPr><w:t>${sanitize(trimmedLine)}</w:t></w:r></w:p>');
        }
      }
    } else {
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

    const docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';

    final contentTypesBytes = utf8.encode(contentTypesXml);
    final relsBytes = utf8.encode(relsXml);
    final documentBytes = utf8.encode(documentXml);
    final docRelsBytes = utf8.encode(docRelsXml);

    // إضافة الملفات إلى ملف ZIP المضغوط للوورد
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesBytes.length, contentTypesBytes));
    archive.addFile(ArchiveFile('_rels/.rels', relsBytes.length, relsBytes));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', docRelsBytes.length, docRelsBytes));
    archive.addFile(ArchiveFile('word/document.xml', documentBytes.length, documentBytes));

    final encoder = ZipEncoder();
    return encoder.encode(archive)!;
  }
}
