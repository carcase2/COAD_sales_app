/// 부서 사이 업무 요청 (`work_requests`). COAD_home 웹과 같은 표·규칙.
///
/// 흐름: 요청 → 받은 부서가 수락·거절·보류 → 수락하면 접수·진행중·완료.
library;

const workRequestPriorities = ['후순위', '낮음', '보통', '높음', '긴급', '특급'];

class WorkRequest {
  const WorkRequest({
    required this.id,
    required this.title,
    required this.fromGroup,
    required this.toGroup,
    required this.status,
    this.detail = '',
    this.requesterName = '',
    this.requesterUserId = '',
    this.dueDate = '',
    this.priority = '보통',
    this.progress = '',
    this.responseNote = '',
    this.respondedBy = '',
    this.respondedAt = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.canDecide = false,
    this.canCancel = false,
    this.canEdit = false,
  });

  final String id;
  final String title;
  final String detail;
  final String fromGroup;
  final String toGroup;
  final String requesterName;
  final String requesterUserId;

  /// YYYY-MM-DD, 없으면 ''.
  final String dueDate;
  final String priority;

  /// 요청 · 수락 · 거절 · 보류
  final String status;

  /// 수락한 뒤 접수 · 진행중 · 완료. 그 전에는 ''.
  final String progress;
  final String responseNote;
  final String respondedBy;
  final String respondedAt;
  final String createdAt;
  final String updatedAt;

  /// 서버가 이 계정 기준으로 계산한 권한.
  final bool canDecide;
  final bool canCancel;
  final bool canEdit;

  bool get isWaiting => status == '요청';
  bool get isAccepted => status == '수락';
  bool get isDone => isAccepted && progress == '완료';
  bool get isClosed => status == '거절' || isDone;

  /// 진행이 시작되기 전까지만 수락·거절·보류를 바꿀 수 있다.
  bool get decisionOpen => progress != '진행중' && progress != '완료';

  /// 받은 부서가 지금 눌러야 하는 요청.
  bool get needsAnswer => status == '요청';

  /// 카드에 보이는 한 단어 상태.
  String get stateLabel {
    if (status == '수락') {
      return switch (progress) {
        '진행중' => '진행중',
        '완료' => '완료',
        _ => '수락 · 접수',
      };
    }
    return status;
  }

  factory WorkRequest.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] ?? '').toString().trim();
    final due = text('dueDate');
    return WorkRequest(
      id: text('id'),
      title: text('title'),
      detail: (json['detail'] ?? '').toString(),
      fromGroup: text('fromGroup'),
      toGroup: text('toGroup'),
      requesterName: text('requesterName'),
      requesterUserId: text('requesterUserId'),
      dueDate: due.length >= 10 ? due.substring(0, 10) : '',
      priority: text('priority').isEmpty ? '보통' : text('priority'),
      status: text('status'),
      progress: text('progress'),
      responseNote: text('responseNote'),
      respondedBy: text('respondedBy'),
      respondedAt: text('respondedAt'),
      createdAt: text('createdAt'),
      updatedAt: text('updatedAt'),
      canDecide: json['canDecide'] == true,
      canCancel: json['canCancel'] == true,
      canEdit: json['canEdit'] == true,
    );
  }
}

class WorkRequestViewer {
  const WorkRequestViewer({
    required this.id,
    required this.name,
    required this.groupName,
    this.seeAll = false,
  });

  final String id;
  final String name;
  final String groupName;

  /// 관리자 — 모든 부서 요청을 보고 처리한다.
  final bool seeAll;
}

class WorkRequestBoard {
  const WorkRequestBoard({
    required this.today,
    required this.viewer,
    required this.targets,
    required this.requests,
    this.priorities = workRequestPriorities,
  });

  final String today;
  final WorkRequestViewer viewer;

  /// 요청 보낼 수 있는 부서.
  final List<String> targets;
  final List<WorkRequest> requests;
  final List<String> priorities;

  /// 내 부서가 받은 요청 (관리자는 전부). 처리할 것부터.
  List<WorkRequest> get incoming {
    final group = viewer.groupName.trim();
    return sortWorkRequests([
      for (final row in requests)
        if (viewer.seeAll || (group.isNotEmpty && row.toGroup == group)) row,
    ]);
  }

  /// 내 부서가 보낸 요청 (관리자는 내가 보낸 것).
  List<WorkRequest> get outgoing {
    final group = viewer.groupName.trim();
    return sortWorkRequests([
      for (final row in requests)
        if (row.requesterUserId == viewer.id ||
            (group.isNotEmpty && row.fromGroup == group))
          row,
    ]);
  }

  int get waitingCount => incoming.where((row) => row.needsAnswer).length;

  factory WorkRequestBoard.fromJson(Map<String, dynamic> json) {
    final viewer = json['viewer'] is Map
        ? Map<String, dynamic>.from(json['viewer'] as Map)
        : const <String, dynamic>{};
    final rows = <WorkRequest>[];
    final raw = json['requests'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final row = WorkRequest.fromJson(Map<String, dynamic>.from(item));
          if (row.id.isNotEmpty) rows.add(row);
        }
      }
    }
    List<String> strings(dynamic value) => [
      if (value is List)
        for (final item in value)
          if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
    final priorities = strings(json['priorities']);
    return WorkRequestBoard(
      today: (json['today'] ?? '').toString(),
      viewer: WorkRequestViewer(
        id: (viewer['id'] ?? '').toString(),
        name: (viewer['name'] ?? '').toString(),
        groupName: (viewer['groupName'] ?? '').toString().trim(),
        seeAll: viewer['seeAll'] == true,
      ),
      targets: strings(json['targets']),
      requests: rows,
      priorities: priorities.isEmpty ? workRequestPriorities : priorities,
    );
  }
}

int _rank(WorkRequest row) {
  if (row.status == '요청') return 0;
  if (row.status == '보류') return 1;
  if (row.status == '수락' && row.progress != '완료') return 2;
  if (row.status == '수락') return 3;
  return 4;
}

/// 요청 → 보류 → 진행 중 → 완료 → 거절, 같은 칸은 최근 것부터 (COAD_home 과 같음).
List<WorkRequest> sortWorkRequests(List<WorkRequest> rows) {
  final sorted = [...rows];
  sorted.sort((a, b) {
    final byRank = _rank(a).compareTo(_rank(b));
    if (byRank != 0) return byRank;
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}

/// 수락한 요청의 다음 진행 단계. 완료면 null.
String? nextWorkRequestProgress(WorkRequest row) {
  if (!row.isAccepted) return null;
  return switch (row.progress) {
    '진행중' => '완료',
    '완료' => null,
    _ => '진행중',
  };
}
