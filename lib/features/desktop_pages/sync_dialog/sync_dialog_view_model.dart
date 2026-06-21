import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/sync_service.dart';

class SyncDialogViewModel extends ChangeNotifier {
  final SyncService _syncService = SyncService();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String _syncMessage = 'اضغط على الزر لبدء المزامنة الشاملة';
  String get syncMessage => _syncMessage;

  IconData _syncIcon = Icons.cloud_sync_rounded;
  IconData get syncIcon => _syncIcon;

  Color _iconColor = Colors.blue;
  Color get iconColor => _iconColor;

  double? _progressValue = 0.0;
  double? get progressValue => _progressValue;

  Future<bool> handleFullSync(BuildContext context) async {
    _isSyncing = true;
    _syncMessage = 'جاري المزامنة الذكية (رفع التعديلات ودمج السحابة)...';
    _syncIcon = Icons.sync;
    _iconColor = Colors.blue;
    _progressValue = null;
    notifyListeners();

    try {
      await _syncService.performSmartSync();

      _syncMessage = 'تمت المزامنة الشاملة بنجاح!';
      _syncIcon = Icons.check_circle_outline;
      _iconColor = Colors.green;
      _progressValue = 1.0;
      notifyListeners();

      await Future.delayed(const Duration(seconds: 2));
      return true;
    } on FirebaseException catch (_) {
      _setErrorState('تعذر الوصول للسحابة. تأكد من اتصالك بالإنترنت.', Icons.wifi_off);
    } on TimeoutException catch (e) {
      _setErrorState(e.message ?? 'انقضى وقت الاتصال. الإنترنت ضعيف جداً.', Icons.signal_wifi_bad);
    } catch (e) {
      _setErrorState('حدث خطأ: $e', Icons.error_outline);
    } finally {
      if (_syncIcon != Icons.check_circle_outline) {
        _isSyncing = false;
        _progressValue = 0.0;
        notifyListeners();
      }
    }
    return false;
  }

  void _setErrorState(String message, IconData icon) {
    _syncMessage = message;
    _syncIcon = icon;
    _iconColor = Colors.red;
    _isSyncing = false;
    _progressValue = 0.0;
    notifyListeners();
  }
}
