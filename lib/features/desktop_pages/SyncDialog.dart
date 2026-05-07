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
  double? _progressValue = 0.0; // جعلناه يقبل Null لعمل حركة مستمرة

  Future<void> _handleFullSync() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = 'جاري المزامنة الذكية (رفع التعديلات ودمج السحابة)...';
      _syncIcon = Icons.sync; // أيقونة الدوران
      _iconColor = Colors.blue;
      _progressValue = null; // القيمة null تجعل شريط التقدم يتحرك باستمرار
    });

    try {
      // 🌟 استدعاء الدالة الذكية الجديدة التي تقوم بكل شيء بأمان
      await _syncService.performSmartSync();

      setState(() {
        _syncMessage = 'تمت المزامنة الشاملة بنجاح!';
        _syncIcon = Icons.check_circle_outline;
        _iconColor = Colors.green;
        _progressValue = 1.0; // اكتمال الشريط
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, true);
      });
    } on FirebaseException catch (e) {
      _setErrorState(
          'تعذر الوصول للسحابة. تأكد من اتصالك بالإنترنت.', Icons.wifi_off);
    } on TimeoutException catch (e) {
      _setErrorState(e.message ?? 'انقضى وقت الاتصال. الإنترنت ضعيف جداً.',
          Icons.signal_wifi_bad);
    } catch (e) {
      _setErrorState('حدث خطأ: $e', Icons.error_outline);
    } finally {
      if (mounted && _syncIcon != Icons.check_circle_outline) {
        setState(() {
          _isSyncing = false;
          _progressValue = 0.0;
        });
      }
    }
  }

  void _setErrorState(String message, IconData icon) {
    setState(() {
      _syncMessage = message;
      _syncIcon = icon;
      _iconColor = Colors.red;
      _isSyncing = false;
      _progressValue = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 500),
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
            const SizedBox(height: 20),

            // أيقونة الحالة
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(_syncIcon,
                  key: ValueKey(_syncIcon), size: 64, color: _iconColor),
            ),
            const SizedBox(height: 20),

            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  _syncMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _iconColor == Colors.red
                        ? Colors.red[700]
                        : Colors.black87,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // شريط التقدم أو زر المزامنة
            if (_isSyncing || _progressValue == 1.0)
              LinearProgressIndicator(
                value:
                    _progressValue, // null = يتحرك يميناً ويساراً (Indeterminate)
                backgroundColor: Colors.grey[200],
                color: _iconColor,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton.icon(
                  onPressed: _handleFullSync,
                  icon: const Icon(Icons.sync, color: Colors.white),
                  label: const Text('بدء المزامنة الآن'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
