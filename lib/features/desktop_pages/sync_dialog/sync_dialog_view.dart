import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sync_dialog_view_model.dart';

class SyncDialog extends StatelessWidget {
  const SyncDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SyncDialogViewModel(),
      child: Consumer<SyncDialogViewModel>(
        builder: (context, viewModel, child) {
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
                      const Text(
                        'مزامنة البيانات',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: viewModel.isSyncing ? null : () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 20),

                  // أيقونة الحالة
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      viewModel.syncIcon,
                      key: ValueKey(viewModel.syncIcon),
                      size: 64,
                      color: viewModel.iconColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        viewModel.syncMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: viewModel.iconColor == Colors.red
                              ? Colors.red[700]
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // شريط التقدم أو زر المزامنة
                  if (viewModel.isSyncing || viewModel.progressValue == 1.0)
                    LinearProgressIndicator(
                      value: viewModel.progressValue,
                      backgroundColor: Colors.grey[200],
                      color: viewModel.iconColor,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final success = await viewModel.handleFullSync(context);
                          if (success && context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                        icon: const Icon(Icons.sync, color: Colors.white),
                        label: const Text('بدء المزامنة الآن'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
