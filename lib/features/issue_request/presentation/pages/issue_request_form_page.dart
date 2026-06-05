import 'package:coad_customer_calls/features/issue_request/data/repositories/issue_request_repository.dart';
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
  final _requestTypeController = TextEditingController();
  final _targetNameController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _requestTypeController.dispose();
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
        requestType: _requestTypeController.text.trim(),
        targetName: _targetNameController.text.trim(),
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('발급요청이 생성되었습니다. ID: ${result.id}')),
      );
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
      appBar: AppBar(title: const Text('발급요청 생성')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _requestTypeController,
              decoration: const InputDecoration(
                labelText: '요청 타입',
                hintText: '예: tax_invoice',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'request_type은 필수입니다.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetNameController,
              decoration: const InputDecoration(
                labelText: '대상명',
                hintText: '예: 코아드상사',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'target_name은 필수입니다.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: '사유 (선택)'),
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
                  : const Text('생성'),
            ),
          ],
        ),
      ),
    );
  }
}
