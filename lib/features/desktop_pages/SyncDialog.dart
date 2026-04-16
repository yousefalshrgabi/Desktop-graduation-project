import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:academic_affairs_management/core/services/sync_service.dart';

class SyncDialog extends StatefulWidget {
  const SyncDialog({super.key});

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  final SyncService _syncService = SyncService();

  bool _isSyncing = false;
  String _syncMessage = 'اضغط على الزر لبدء المزامنة الشاملة';
  IconData _syncIcon = Icons.cloud_sync_rounded;
  Color _iconColor = Colors.blue;
  double _progressValue = 0.0; // لمتابعة التقدم الوهمي أو الحقيقي

  Future<void> _handleFullSync() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = 'جاري الاتصال بالسحابة...';
      _syncIcon = Icons.cloud_sync;
      _iconColor = Colors.blue;
      _progressValue = 0.1;
    });

    try {
      // 1. إرسال أوامر الحذف أولاً (لضمان نظافة السحابة)
      setState(() {
        _syncMessage = 'جاري تنظيف السحابة... (1/3)';
        _progressValue = 0.3;
      });
      await _syncService.syncDeletionsFirst();

      // 2. التنزيل (Pull)
      setState(() {
        _syncMessage = 'جاري تنزيل أحدث البيانات... (2/3)';
        _syncIcon = Icons.cloud_download;
        _iconColor = Colors.purple;
        _progressValue = 0.6;
      });
      await _syncService.pullFromFirebase();

      // 3. الرفع (Push)
      setState(() {
        _syncMessage = 'جاري رفع التعديلات المحلية... (3/3)';
        _syncIcon = Icons.cloud_upload;
        _iconColor = Colors.orange;
        _progressValue = 0.9;
      });
      await _syncService.pushToFirebase();

      // اكتمال المزامنة بنجاح
      setState(() {
        _syncMessage = 'تمت المزامنة الشاملة بنجاح!';
        _syncIcon = Icons.check_circle_outline;
        _iconColor = Colors.green;
        _progressValue = 1.0;
      });

      // إغلاق النافذة تلقائياً بعد ثانيتين من النجاح
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, true);
      });
    } on FirebaseException catch (e) {
      // التقاط أخطاء فايربيس (مثل انقطاع النت أثناء التنزيل)
      debugPrint('[SYNC ERROR] FirebaseException: $e');
      setState(() {
        _syncMessage = 'تعذر الوصول للسحابة. تأكد من اتصالك بالإنترنت.';
        _syncIcon = Icons.wifi_off;
        _iconColor = Colors.red;
      });
    } on TimeoutException catch (e) {
      // التقاط خطأ الـ Timeout الذي أضفناه في خدمة المزامنة
      debugPrint('[SYNC ERROR] TimeoutException: $e');
      setState(() {
        _syncMessage = e.message ?? 'انقضى وقت الاتصال. الإنترنت ضعيف جداً.';
        _syncIcon = Icons.signal_wifi_bad;
        _iconColor = Colors.orange;
      });
    } catch (e) {
      // التقاط أي خطأ عام آخر
      debugPrint('[SYNC ERROR] General Exception: $e');
      setState(() {
        _syncMessage = 'حدث خطأ: $e';
        _syncIcon = Icons.error_outline;
        _iconColor = Colors.red;
      });
    } finally {
      // هذا الكود يضمن أنه بمجرد حدوث خطأ، يتحول _isSyncing إلى false
      // مما يفعل زر (الإغلاق X) ويسمح للمستخدم بالخروج من النافذة
      if (mounted && _syncIcon != Icons.check_circle_outline) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('مزامنة البيانات',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isSyncing ? null : () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(),
            const SizedBox(height: 24),

            // أيقونة متغيرة حسب الحالة
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(_syncIcon,
                  key: ValueKey(_syncIcon), size: 72, color: _iconColor),
            ),
            const SizedBox(height: 24),

            // رسالة المزامنة
            Text(_syncMessage,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),

            // شريط التقدم أو زر المزامنة
            if (_isSyncing || _progressValue == 1.0)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _progressValue == 1.0
                        ? 1.0
                        : null, // إذا اكتمل يثبت الشريط، وإلا يتحرك
                    backgroundColor: Colors.grey[200],
                    color: _iconColor,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _handleFullSync,
                  icon: const Icon(Icons.sync, color: Colors.white),
                  label: const Text('بدء المزامنة',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              )
          ],
        ),
      ),
    );
  }
}
