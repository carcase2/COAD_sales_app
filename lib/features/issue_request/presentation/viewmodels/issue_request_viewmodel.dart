import 'package:coad_customer_calls/features/issue_request/data/models/issue_request_dto.dart';
import 'package:coad_customer_calls/features/issue_request/data/repositories/issue_request_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final issueRequestViewModelProvider = StateNotifierProvider.autoDispose
    .family<IssueRequestViewModel, AsyncValue<List<IssueRequestDto>>, int>((
      ref,
      userId,
    ) {
      return IssueRequestViewModel(
        repository: ref.watch(issueRequestRepositoryProvider),
        userId: userId,
      );
    });

class IssueRequestViewModel
    extends StateNotifier<AsyncValue<List<IssueRequestDto>>> {
  IssueRequestViewModel({
    required IssueRequestRepository repository,
    required int userId,
  }) : _repository = repository,
       _userId = userId,
       super(const AsyncValue.loading());

  final IssueRequestRepository _repository;
  final int _userId;

  String? _statusFilter;
  String? get statusFilter => _statusFilter;

  Future<void> load({String? status}) async {
    state = const AsyncValue.loading();
    _statusFilter = status;
    state = await AsyncValue.guard(
      () => _repository.getIssueRequestList(userId: _userId, status: status),
    );
  }

  Future<CreateIssueRequestResponseDto> create({
    required String requestType,
    required String targetName,
    required String? reason,
  }) async {
    final response = await _repository.createIssueRequest(
      userId: _userId,
      requestType: requestType,
      targetName: targetName,
      reason: reason,
    );
    await refresh();
    return response;
  }

  Future<IssueRequestDto> getDetail({required int id}) {
    return _repository.getIssueRequestDetail(id: id);
  }

  Future<void> updateStatus({required int id, required String status}) async {
    await _repository.updateIssueRequestStatus(id: id, status: status);
    await refresh();
  }

  Future<void> refresh() async {
    await load(status: _statusFilter);
  }
}
