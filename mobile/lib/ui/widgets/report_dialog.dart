import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/app_translations.dart';

class ReportDialog extends StatefulWidget {
  final String mosqueId;
  final String mosqueName;
  final String locale;
  final Future<bool> Function(String mosqueId, String reason, String details) onSubmit;

  const ReportDialog({
    super.key,
    required this.mosqueId,
    required this.mosqueName,
    required this.locale,
    required this.onSubmit,
  });

  static void show(
    BuildContext context, {
    required String mosqueId,
    required String mosqueName,
    required String locale,
    required Future<bool> Function(String mosqueId, String reason, String details) onSubmit,
  }) {
    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        mosqueId: mosqueId,
        mosqueName: mosqueName,
        locale: locale,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String _selectedReason = 'closed';
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppTranslations.get('report_issue', widget.locale)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mosqueName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'closed', child: Text('Yopilgan / Faoliyat ko\'rsatmaydi')),
                DropdownMenuItem(value: 'wrong_location', child: Text('Koordinatasi noto\'g\'ri')),
                DropdownMenuItem(value: 'incorrect_info', child: Text('Ma\'lumotlarida xatolik bor')),
                DropdownMenuItem(value: 'other', child: Text('Boshqa sabab')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Qo\'shimcha izoh (ixtiyoriy)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppTranslations.get('cancel', widget.locale)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await widget.onSubmit(
                    widget.mosqueId,
                    _selectedReason,
                    _detailsController.text.trim(),
                  );
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? AppTranslations.get('report_sent', widget.locale)
                            : 'Xatolik yuz berdi. Qaytadan urinib ko\'ring.',
                      ),
                      backgroundColor: success ? AppColors.success : AppColors.danger,
                    ),
                  );
                },
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(AppTranslations.get('submit', widget.locale)),
        ),
      ],
    );
  }
}
