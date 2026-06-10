import 'package:coad_customer_calls/features/issue_request/data/repositories/issue_request_repository.dart';
import 'package:coad_customer_calls/features/issue_request/issue_request_labels.dart';
import 'package:coad_customer_calls/features/issue_request/presentation/viewmodels/issue_request_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IssueRequestFormPage extends ConsumerStatefulWidget {
  const IssueRequestFormPage({required this.userId, super.key});

  final int userId;

  @override
  ConsumerState<IssueRequestFormPage> createState() =>
      _IssueRequestFormPageState();
}

class _IssueRequestFormPageState extends ConsumerState<IssueRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _targetNameController = TextEditingController();
  final _reasonController = TextEditingController();
  String _requestType = IssueRequestLabels.requestTypes.keys.first;
  bool _submitting = false;

  @override
  void dispose() {
    _targetNameController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final viewModel = ref.read(
      issueRequestViewModelProvider(widget.userId).notifier,
    );
    try {
      final result = await viewModel.create(
        requestType: _requestType,
        targetName: _targetNameController.text.trim(),
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('발급요청이 등록되었습니다. (#${result.id})')));
      Navigator.of(context).pop(true);
    } on IssueRequestApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('발급요청 등록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _requestType,
              decoration: const InputDecoration(
                labelText: '요청 유형',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final entry in IssueRequestLabels.requestTypes.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _requestType = value);
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetNameController,
              decoration: const InputDecoration(
                labelText: '대상명',
                hintText: '예: 코아드상사',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '대상명을 입력해 주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '사유 (선택)',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('등록'),
            ),
          ],
        ),
      ),
    );
  }
}
