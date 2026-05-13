// Web-only: uses dart:js to trigger browser file download
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:convert';

void downloadCsvFile(String csvContent, String fileName) {
  final bom = '\uFEFF$csvContent';
  final base64Str = base64Encode(utf8.encode(bom));
  final dataUrl = 'data:text/csv;charset=utf-8;base64,$base64Str';
  // Escape quotes in fileName to avoid breaking the JS string
  final safeFileName = fileName.replaceAll("'", "\\'");

  js.context.callMethod('eval', [
    '''
    (function() {
      var a = document.createElement('a');
      a.href = '$dataUrl';
      a.download = '$safeFileName';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    })();
    '''
  ]);
}
