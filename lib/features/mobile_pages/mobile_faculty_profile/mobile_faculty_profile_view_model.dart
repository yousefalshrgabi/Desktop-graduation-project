import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class MobileFacultyProfileViewModel extends ChangeNotifier {
  final Map<String, dynamic> facultyData;
  final Map<String, bool> downloadingStates = {};

  MobileFacultyProfileViewModel({required this.facultyData});

  bool isDownloading(String url) => downloadingStates[url] ?? false;

  String getString(String key, {String? fallbackKey}) {
    String val = facultyData[key]?.toString() ?? '';
    if ((val.isEmpty || val == 'غير حدد') && fallbackKey != null) {
      val = facultyData[fallbackKey]?.toString() ?? '';
    }
    return val;
  }

  Future<bool> downloadAndOpenFile(BuildContext context, String url, String title) async {
    downloadingStates[url] = true;
    notifyListeners();

    try {
      final directory = await getApplicationDocumentsDirectory();

      String ext = '.pdf'; // default
      try {
        String rawPath = Uri.parse(url).path;
        String possibleExt = rawPath.split('.').last.split('?').first.toLowerCase();
        if (possibleExt.length <= 5) ext = '.$possibleExt';
      } catch (_) {}

      final fileName = 'temp_file_${DateTime.now().millisecondsSinceEpoch}$ext';
      final savePath = '${directory.path}/$fileName';
      final file = File(savePath);

      // تحميل الملف من Firebase Storage
      await FirebaseStorage.instance.refFromURL(url).writeToFile(file);

      // فتح الملف محلياً
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يوجد تطبيق متاح لفتح هذا الملف (${result.message})')),
        );
        return false;
      }
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحميل الملف: $e')),
      );
      return false;
    } finally {
      downloadingStates[url] = false;
      notifyListeners();
    }
  }
}
