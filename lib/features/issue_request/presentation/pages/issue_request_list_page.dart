import 'package:coad_customer_calls/features/issue_request/data/models/issue_request_dto.dart';
import 'package:coad_customer_calls/features/issue_request/data/repositories/issue_request_repository.dart';
import 'package:coad_customer_calls/features/issue_request/presentation/pages/issue_request_form_page.dart';
import 'package:coad_customer_calls/features/issue_request/presentation/viewmodels/issue_request_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IssueRequestListPage extends ConsumerStatefulWidget {
  const IssueRequestListPage({required this.userId, super.key});

  final int userId;

  @override
  ConsumerState<IssueRequestListPage> createState() =>
      _IssueRequestListPageState();
}

class _IssueRequestListPageState extends ConsumerState<IssueRequestListPage> {
  String? _status;

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

  Future<void> _showDetail(IssueRequestDto item) async {
    final vm = ref.read(issueRequestViewModelProvider(widget.userId).notifier);
    try {
      final detail = await vm.getDetail(id: item.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '발급요청 상세 #${detail.id}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('user_id: ${detail.userId}'),
                  Text('request_type: ${detail.requestType}'),
                  Text('target_name: ${detail.targetName}'),
                  Text('reason: ${detail.reason ?? '-'}'),
                  Text('status: ${detail.status}'),
                  Text(
                    'created_at: ${detail.createdAt?.toIso8601String() ?? '-'}',
                  ),
                  Text(
                    'updated_at: ${detail.updatedAt?.toIso8601String() ?? '-'}',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            _updateStatus(id: detail.id, status: 'approved'),
                        child: const Text('approved'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            _updateStatus(id: detail.id, status: 'rejected'),
                        child: const Text('rejected'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('상태가 $status 로 변경되었습니다.')));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('발급요청 목록'),
        actions: [
          PopupMenuButton<String?>(
            initialValue: _status,
            onSelected: _changeStatusFilter,
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('전체')),
              PopupMenuItem(value: 'pending', child: Text('pending')),
              PopupMenuItem(value: 'approved', child: Text('approved')),
              PopupMenuItem(value: 'rejected', child: Text('rejected')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.filter_alt_outlined),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePage,
        icon: const Icon(Icons.add),
        label: const Text('생성'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('발급요청 데이터가 없습니다.'));
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
                    'request_type=${item.requestType} / status=${item.status}',
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
