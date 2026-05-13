import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

Future<String> downloadCsvFile(String csvContent, String fileName) async {
  // ── طلب صلاحية التخزين على Android ─────────────────────────────────────
  if (Platform.isAndroid) {
    await _requestStoragePermission();
  }

  final savePath = _resolveSavePath();
  final dir = Directory(savePath);

  if (!dir.existsSync()) {
    try {
      dir.createSync(recursive: true);
    } catch (_) {
      // Fallback إلى مجلد مؤقت
      return await _writeFile(Directory.systemTemp.path, fileName, csvContent);
    }
  }

  return await _writeFile(savePath, fileName, csvContent);
}

/// طلب الصلاحيات اللازمة على Android
Future<void> _requestStoragePermission() async {
  try {
    final sdkInt = int.tryParse(
            Platform.environment['ro.build.version.sdk'] ?? '0') ??
        0;

    if (sdkInt >= 30) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    } else {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        if (!result.isGranted) {
          throw Exception('storage_permission_denied');
        }
      }
    }
  } catch (e) {
    // Catch MissingPluginException or other errors
    // If the plugin is missing, we'll just try to write the file anyway.
    print('Permission request error: $e');
  }
}

/// يحدد المسار الصحيح حسب نظام التشغيل
String _resolveSavePath() {
  if (Platform.isAndroid) {
    const androidDownloads = '/storage/emulated/0/Download';
    if (Directory(androidDownloads).existsSync()) {
      return androidDownloads;
    }
    final ext = Platform.environment['EXTERNAL_STORAGE'];
    if (ext != null && ext.isNotEmpty) return '$ext/Download';
    return Directory.systemTemp.path;
  }

  if (Platform.isWindows) {
    final home = Platform.environment['USERPROFILE'] ?? '';
    if (home.isNotEmpty) return '$home\\Downloads';
  }

  if (Platform.isLinux || Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty && home != '/') return '$home/Downloads';
  }

  return Directory.systemTemp.path;
}

Future<String> _writeFile(
    String dirPath, String fileName, String content) async {
  final sep = Platform.pathSeparator;
  final filePath = '$dirPath$sep$fileName';
  final file = File(filePath);
  file.writeAsStringSync('\uFEFF$content', flush: true);
  return filePath;
}
