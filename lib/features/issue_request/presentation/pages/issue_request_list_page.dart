import 'package:coad_customer_calls/features/issue_request/data/models/issue_request_dto.dart';
import 'package:coad_customer_calls/features/issue_request/data/repositories/issue_request_repository.dart';
import 'package:coad_customer_calls/features/issue_request/issue_request_labels.dart';
import 'package:coad_customer_calls/features/issue_request/presentation/pages/issue_request_form_page.dart';
import 'package:coad_customer_calls/features/issue_request/presentation/viewmodels/issue_request_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class IssueRequestListPage extends ConsumerStatefulWidget {
  const IssueRequestListPage({required this.userId, super.key});

  final int userId;

  @override
  ConsumerState<IssueRequestListPage> createState() =>
      _IssueRequestListPageState();
}

class _IssueRequestListPageState extends ConsumerState<IssueRequestListPage> {
  String? _status;

  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(issueRequestViewModelProvider(widget.userId).notifier)
          .load(),
    );
  }

  Future<void> _changeStatusFilter(String? status) async {
    setState(() => _status = status);
    await ref
        .read(issueRequestViewModelProvider(widget.userId).notifier)
        .load(status: status);
  }

  Future<void> _openCreatePage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => IssueRequestFormPage(userId: widget.userId),
      ),
    );
    if (created == true && mounted) {
      await ref
          .read(issueRequestViewModelProvider(widget.userId).notifier)
          .refresh();
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return _dateFormat.format(value.toLocal());
  }

  Future<void> _showDetail(IssueRequestDto item) async {
    final vm = ref.read(issueRequestViewModelProvider(widget.userId).notifier);
    try {
      final detail = await vm.getDetail(id: item.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '발급요청 #${detail.id}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: '요청 유형',
                    value: IssueRequestLabels.requestTypeLabel(
                      detail.requestType,
                    ),
                  ),
                  _DetailRow(label: '대상명', value: detail.targetName),
                  _DetailRow(label: '사유', value: detail.reason?.trim() ?? '-'),
                  _DetailRow(
                    label: '상태',
                    value: IssueRequestLabels.statusLabel(detail.status),
                  ),
                  _DetailRow(
                    label: '요청일',
                    value: _formatDate(detail.createdAt),
                  ),
                  _DetailRow(
                    label: '수정일',
                    value: _formatDate(detail.updatedAt),
                  ),
                  const SizedBox(height: 16),
                  Text('상태 변경', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () =>
                            _updateStatus(id: detail.id, status: 'approved'),
                        child: const Text('승인'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            _updateStatus(id: detail.id, status: 'rejected'),
                        child: const Text('반려'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } on IssueRequestApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _updateStatus({required int id, required String status}) async {
    final vm = ref.read(issueRequestViewModelProvider(widget.userId).notifier);
    try {
      await vm.updateStatus(id: id, status: status);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '상태가 ${IssueRequestLabels.statusLabel(status)}(으)로 변경되었습니다.',
          ),
        ),
      );
    } on IssueRequestApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(issueRequestViewModelProvider(widget.userId));
    final filterLabel = _status == null
        ? '전체'
        : IssueRequestLabels.statusLabel(_status!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('REST 발급요청'),
        actions: [
          PopupMenuButton<String?>(
            initialValue: _status,
            onSelected: _changeStatusFilter,
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('전체')),
              PopupMenuItem(value: 'pending', child: Text('대기')),
              PopupMenuItem(value: 'approved', child: Text('승인')),
              PopupMenuItem(value: 'rejected', child: Text('반려')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(filterLabel, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.filter_alt_outlined, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePage,
        icon: const Icon(Icons.add),
        label: const Text('발급요청'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is IssueRequestApiException
                  ? error.message
                  : error.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('발급요청이 없습니다.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref
                .read(issueRequestViewModelProvider(widget.userId).notifier)
                .refresh(),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.targetName),
                  subtitle: Text(
                    '${IssueRequestLabels.requestTypeLabel(item.requestType)} · '
                    '${IssueRequestLabels.statusLabel(item.status)}',
                  ),
                  trailing: Text('#${item.id}'),
                  onTap: () => _showDetail(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
