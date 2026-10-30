import 'package:flutter/material.dart';
import 'package:flutter_learning/services/social_api.dart';

/// The reasons the API accepts (`reason`), with the labels people see.
const reportReasons = {
  'spam': 'Spam hoặc quảng cáo',
  'harassment': 'Quấy rối hoặc bắt nạt',
  'hate': 'Ngôn từ thù ghét',
  'violence': 'Bạo lực',
  'nudity': 'Nội dung nhạy cảm',
  'false_info': 'Thông tin sai sự thật',
  'other': 'Lý do khác',
};

/// Asks why, then sends the report with [send] and tells the person how it
/// went. [what] completes "Báo cáo ..." (for example "bài viết").
Future<void> showReportSheet(
  BuildContext context, {
  required String what,
  required Future<void> Function(String reason, String? details) send,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<({String reason, String? details})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportForm(what: what),
  );
  if (choice == null) return;

  try {
    await send(choice.reason, choice.details);
    messenger.showSnackBar(
      const SnackBar(content: Text('Đã gửi báo cáo, cảm ơn bạn')),
    );
  } on ApiException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.displayMessage)));
  }
}

class _ReportForm extends StatefulWidget {
  final String what;

  const _ReportForm({required this.what});

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _details = TextEditingController();
  String? _reason;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Báo cáo ${widget.what}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Chọn lý do phù hợp nhất:'),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (value) => setState(() => _reason = value),
                child: Column(
                  children: [
                    for (final entry in reportReasons.entries)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: entry.key,
                        title: Text(entry.value),
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _details,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Chi tiết (không bắt buộc)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _reason == null
                      ? null
                      : () => Navigator.pop(context, (
                          reason: _reason!,
                          details: _details.text.trim().isEmpty
                              ? null
                              : _details.text.trim(),
                        )),
                  child: const Text('Gửi báo cáo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
