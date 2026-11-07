/// 화면에서 급한 순. DB id 순서와 다르다.
const workPriorityOrder = ['특급', '높음', '보통', '낮음', '후순위'];

int workPriorityRank(String? name) {
  final index = workPriorityOrder.indexOf((name ?? '').trim());
  return index < 0 ? workPriorityOrder.length : index;
}

const workAssigneePaletteSize = 8;

int _assigneeHash(String key) {
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 33 + unit) & 0x7fffffff;
  }
  return hash;
}

/// 같은 담당 목록이면 항상 같은 칸. 목록 안에서는 색이 겹치지 않게 민다.
Map<String, int> workAssigneeColorSlots(Iterable<String> keys) {
  final unique = <String>{
    for (final key in keys)
      if (key.trim().isNotEmpty) key.trim(),
  }.toList()..sort();
  final used = <int>{};
  final slots = <String, int>{};
  for (final key in unique) {
    var slot = _assigneeHash(key) % workAssigneePaletteSize;
    var guard = 0;
    while (used.contains(slot) && guard < workAssigneePaletteSize) {
      slot = (slot + 1) % workAssigneePaletteSize;
      guard++;
    }
    used.add(slot);
    slots[key] = slot;
  }
  return slots;
}

/// 연구소 업무 (`tasks`) 한 건. 완료는 목록에 넣지 않는다.
class WorkTask {
  const WorkTask({
    required this.id,
    required this.title,
    required this.detail,
    required this.status,
    this.dueDate,
    this.assigneeNames = const [],
    this.assigneeEmails = const [],
    this.priorityId = '',
    this.priorityName = '',
    this.requester = '',
    this.createdAt = '',
    this.completedDate = '',
  });

  final String id;
  final String title;
  final String detail;
  final String status;
  final String? dueDate;
  final List<String> assigneeNames;
  final List<String> assigneeEmails;
  final String priorityId;
  final String priorityName;
  final String requester;
  final String createdAt;

  /// 완료한 날 (YYYY-MM-DD). 완료가 아니면 ''.
  final String completedDate;

  bool get isHeld => status == '보류';

  bool get isDone => status == '완료';

  bool get isOpen => status == '접수' || status == '진행중';

  bool get canStart => status == '접수' || status == '보류';

  bool get canHold => status == '접수' || status == '진행중';

  bool get canComplete => status == '접수' || status == '진행중' || status == '보류';

  /// 연구소 웹 「접수로」 — 시작했거나 보류·완료한 업무를 다시 접수로.
  bool get canReceive => status == '진행중' || status == '보류' || status == '완료';

  WorkTask withRequester(String value) => WorkTask(
    id: id,
    title: title,
    detail: detail,
    status: status,
    dueDate: dueDate,
    assigneeNames: assigneeNames,
    assigneeEmails: assigneeEmails,
    priorityId: priorityId,
    priorityName: priorityName,
    requester: value,
    createdAt: createdAt,
    completedDate: completedDate,
  );

  factory WorkTask.fromJson(Map<String, dynamic> json) {
    final names = <String>[];
    final rawNames = json['assigneeNames'];
    if (rawNames is List) {
      for (final name in rawNames) {
        final text = name.toString().trim();
        if (text.isNotEmpty) names.add(text);
      }
    }
    final due = (json['dueDate'] ?? '').toString().trim();
    return WorkTask(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      dueDate: due.length >= 10 ? due.substring(0, 10) : null,
      assigneeNames: names,
      assigneeEmails: _stringList(json['assigneeEmails']),
      priorityId: (json['priorityId'] ?? '').toString().trim(),
      priorityName: (json['priority'] ?? '').toString().trim(),
      requester: (json['requester'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString().trim(),
      completedDate: _ymd(json['completedDate']),
    );
  }
}

String _ymd(dynamic raw) {
  final text = (raw ?? '').toString().trim();
  return text.length >= 10 ? text.substring(0, 10) : '';
}

/// 목록 범위 — 전체, 내가 담당, 내가 요청.
enum WorkTaskScope { all, mine, requested }

/// 제목·내용·요청인·담당 이름에 [query] 가 들어간 업무. 띄어쓰기·대소문자 무시.
List<WorkTask> searchWorkTasks(List<WorkTask> tasks, String query) {
  final needle = _searchKey(query);
  if (needle.isEmpty) return tasks;
  return [
    for (final task in tasks)
      if (_searchKey(
        [
          task.title,
          task.detail,
          task.requester,
          ...task.assigneeNames,
        ].join(' '),
      ).contains(needle))
        task,
  ];
}

String _searchKey(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// 범위에 맞는 업무. 「내 업무」는 담당에 내 메일, 「내가 요청」은 요청인이 내 이름.
List<WorkTask> scopeWorkTasks(
  List<WorkTask> tasks,
  WorkTaskScope scope, {
  String? myEmail,
  String? myName,
}) {
  switch (scope) {
    case WorkTaskScope.all:
      return tasks;
    case WorkTaskScope.mine:
      final email = (myEmail ?? '').trim();
      if (email.isEmpty) return const [];
      return [
        for (final task in tasks)
          if (task.assigneeEmails.contains(email)) task,
      ];
    case WorkTaskScope.requested:
      final name = (myName ?? '').trim();
      final email = (myEmail ?? '').trim().toLowerCase();
      if (name.isEmpty && email.isEmpty) return const [];
      return [
        for (final task in tasks)
          if ((name.isNotEmpty && task.requester.trim() == name) ||
              (email.isNotEmpty &&
                  task.requester.trim().toLowerCase() == email))
            task,
      ];
  }
}

class WorkTaskSection {
  const WorkTaskSection({required this.kind, required this.tasks});

  final WorkDueKind kind;
  final List<WorkTask> tasks;

  String get label => switch (kind) {
    WorkDueKind.overdue => '기한 지남',
    WorkDueKind.today => '오늘 마감',
    WorkDueKind.upcoming => '다가오는 업무',
    WorkDueKind.undated => '기한 없음',
  };
}

/// 남은 업무를 기한 지남·오늘·이후·기한 없음 묶음으로. 빈 묶음은 뺀다.
/// 묶음 안에서는 중요도 → 기한 → 제목 순.
List<WorkTaskSection> workTaskSections(List<WorkTask> tasks, String today) {
  final buckets = <WorkDueKind, List<WorkTask>>{};
  for (final task in tasks) {
    (buckets[workDueKind(task.dueDate, today)] ??= []).add(task);
  }
  return [
    for (final kind in WorkDueKind.values)
      if ((buckets[kind] ?? const []).isNotEmpty)
        WorkTaskSection(
          kind: kind,
          tasks: buckets[kind]!
            ..sort((a, b) {
              final byPriority = workPriorityRank(
                a.priorityName,
              ).compareTo(workPriorityRank(b.priorityName));
              if (byPriority != 0) return byPriority;
              final byDue = (a.dueDate ?? '').compareTo(b.dueDate ?? '');
              if (byDue != 0) return byDue;
              return a.title.compareTo(b.title);
            }),
        ),
  ];
}

/// 영업 앱의 담당 선택에서 빼는 시험 계정. 계정과 웹 보드는 바꾸지 않는다.
const hiddenWorkAssigneeName = '김경덕test';
const hiddenWorkAssigneeEmail = 'carcase2@gmail.com';

bool workAssigneeHidden({String name = '', String email = ''}) {
  if (name.trim() == hiddenWorkAssigneeName) return true;
  return email.trim().toLowerCase() == hiddenWorkAssigneeEmail;
}

List<WorkAssignee> visibleWorkAssignees(Iterable<WorkAssignee> people) {
  return [
    for (final person in people)
      if (person.email.trim().isNotEmpty &&
          !workAssigneeHidden(name: person.name, email: person.email))
        person,
  ];
}

class WorkAssigneeLabel {
  const WorkAssigneeLabel({required this.name, required this.email});

  final String name;
  final String email;
}

/// 카드와 상세에 보일 담당. 시험 계정 이름은 뺀다.
List<WorkAssigneeLabel> visibleTaskAssignees(WorkTask task) {
  final names = task.assigneeNames;
  final emails = task.assigneeEmails;
  final count = names.length > emails.length ? names.length : emails.length;
  final rows = <WorkAssigneeLabel>[];
  for (var i = 0; i < count; i++) {
    final name = i < names.length ? names[i].trim() : '';
    final email = i < emails.length ? emails[i].trim() : '';
    if (workAssigneeHidden(name: name, email: email)) continue;
    final label = name.isNotEmpty ? name : email;
    if (label.isEmpty) continue;
    rows.add(WorkAssigneeLabel(name: label, email: email));
  }
  return rows;
}

/// 요청·댓글 작성자에 메일이 들어 있으면 담당 목록의 이름으로 바꾼다.
String workDisplayName(String raw, Iterable<WorkAssignee> people) {
  final text = raw.trim();
  if (text.isEmpty || !text.contains('@')) return text;
  final lower = text.toLowerCase();
  for (final person in people) {
    if (person.email.toLowerCase() != lower) continue;
    final name = person.name.trim();
    if (name.isNotEmpty && !name.contains('@')) return name;
  }
  return text;
}

class WorkComment {
  const WorkComment({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String author;
  final String content;
  final String createdAt;

  factory WorkComment.fromJson(Map<String, dynamic> json) {
    return WorkComment(
      id: (json['id'] ?? '').toString(),
      author: (json['author'] ?? '').toString().trim(),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString().trim(),
    );
  }
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  final values = <String>[];
  for (final item in raw) {
    final text = item.toString().trim();
    if (text.isNotEmpty) values.add(text);
  }
  return values;
}

class WorkPriority {
  const WorkPriority({required this.id, required this.name});

  final String id;
  final String name;

  factory WorkPriority.fromJson(Map<String, dynamic> json) {
    return WorkPriority(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
    );
  }
}

/// 담당·중요도가 비어 있으면 그 조건은 전체를 의미한다.
List<WorkTask> filterWorkTasks(
  List<WorkTask> tasks, {
  String? assigneeEmail,
  String? priorityName,
}) {
  final email = (assigneeEmail ?? '').trim();
  final priority = (priorityName ?? '').trim();
  return [
    for (final task in tasks)
      if ((email.isEmpty || task.assigneeEmails.contains(email)) &&
          (priority.isEmpty || task.priorityName == priority))
        task,
  ];
}

class WorkAssigneeGroup {
  const WorkAssigneeGroup({
    required this.email,
    required this.name,
    required this.tasks,
  });

  final String email;
  final String name;
  final List<WorkTask> tasks;
}

class WorkPersonBoard {
  const WorkPersonBoard({
    required this.email,
    required this.name,
    required this.tasks,
  });

  final String email;
  final String name;
  final List<WorkTask> tasks;

  int get urgentCount =>
      tasks.where((task) => task.priorityName == '특급').length;
}

/// 담당 목록에 있는 사람은 업무가 없어도 칸을 만든다.
List<WorkPersonBoard> workPersonBoards(
  List<WorkTask> tasks,
  List<WorkAssignee> people,
) {
  final seen = <String>{};
  final boards = <WorkPersonBoard>[];
  for (final person in people) {
    if (person.email.isEmpty || !seen.add(person.email)) continue;
    boards.add(
      WorkPersonBoard(
        email: person.email,
        name: person.name,
        tasks: [
          for (final task in tasks)
            if (task.assigneeEmails.contains(person.email)) task,
        ],
      ),
    );
  }
  final loose = [
    for (final task in tasks)
      if (task.assigneeEmails.isEmpty ||
          task.assigneeEmails.every((email) => !seen.contains(email)))
        task,
  ];
  if (loose.isNotEmpty) {
    boards.add(WorkPersonBoard(email: '', name: '담당 없음', tasks: loose));
  }
  return boards;
}

/// 한 업무에 담당이 여러 명이면 각 담당 묶음에 넣는다.
List<WorkAssigneeGroup> groupWorkTasksByAssignee(
  List<WorkTask> tasks,
  List<WorkAssignee> people,
) {
  final nameOf = <String, String>{
    for (final person in people) person.email: person.name,
  };
  final buckets = <String, List<WorkTask>>{};
  for (final task in tasks) {
    final keys = task.assigneeEmails.isEmpty ? const [''] : task.assigneeEmails;
    for (final key in keys) {
      (buckets[key] ??= []).add(task);
    }
  }
  final groups = [
    for (final entry in buckets.entries)
      WorkAssigneeGroup(
        email: entry.key,
        name: entry.key.isEmpty
            ? '담당 없음'
            : (nameOf[entry.key] ?? entry.key.split('@').first),
        tasks: entry.value,
      ),
  ];
  groups.sort((a, b) {
    if (a.email.isEmpty) return 1;
    if (b.email.isEmpty) return -1;
    return a.name.compareTo(b.name);
  });
  return groups;
}

/// 일요일부터 시작하는 월 칸. 빈 칸은 null.
List<String?> workMonthCells(String anyYmdInMonth) {
  final parts = anyYmdInMonth.split('-');
  if (parts.length != 3) return const [];
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return const [];
  final first = DateTime(year, month, 1);
  final days = DateTime(year, month + 1, 0).day;
  final cells = <String?>[for (var i = 0; i < first.weekday % 7; i++) null];
  for (var day = 1; day <= days; day++) {
    cells.add(
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
    );
  }
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}

String shiftWorkMonth(String ymd, int deltaMonths) {
  final parts = ymd.split('-');
  if (parts.length != 3) return ymd;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return ymd;
  final shifted = DateTime(year, month + deltaMonths, 1);
  final last = DateTime(shifted.year, shifted.month + 1, 0).day;
  final kept = day.clamp(1, last);
  return '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${kept.toString().padLeft(2, '0')}';
}

class WorkAssignee {
  const WorkAssignee({required this.email, required this.name});

  final String email;
  final String name;

  factory WorkAssignee.fromJson(Map<String, dynamic> json) {
    final email = (json['email'] ?? '').toString().trim();
    final name = (json['name'] ?? '').toString().trim();
    return WorkAssignee(email: email, name: name.isEmpty ? email : name);
  }
}

enum WorkDueKind { overdue, today, upcoming, undated }

WorkDueKind workDueKind(String? dueDate, String today) {
  final due = (dueDate ?? '').trim();
  if (due.length < 10 || today.length < 10) return WorkDueKind.undated;
  final ymd = due.substring(0, 10);
  final day = today.substring(0, 10);
  final compared = ymd.compareTo(day);
  if (compared < 0) return WorkDueKind.overdue;
  if (compared == 0) return WorkDueKind.today;
  return WorkDueKind.upcoming;
}

/// 기한 지난 업무, 오늘 마감, 이후, 기한 없음 순.
int compareWorkTasks(WorkTask a, WorkTask b, String today) {
  const order = {
    WorkDueKind.overdue: 0,
    WorkDueKind.today: 1,
    WorkDueKind.upcoming: 2,
    WorkDueKind.undated: 3,
  };
  final byKind = (order[workDueKind(a.dueDate, today)] ?? 9).compareTo(
    order[workDueKind(b.dueDate, today)] ?? 9,
  );
  if (byKind != 0) return byKind;
  final aDue = a.dueDate ?? '';
  final bDue = b.dueDate ?? '';
  final byDue = aDue.compareTo(bDue);
  if (byDue != 0) return byDue;
  return a.title.compareTo(b.title);
}

class WorkTaskBoard {
  const WorkTaskBoard({
    required this.today,
    required this.tasks,
    required this.assignees,
    this.priorities = const [],
    this.myEmail,
    this.myName,
    this.undo,
  });

  final String today;
  final List<WorkTask> tasks;
  final List<WorkAssignee> assignees;
  final List<WorkPriority> priorities;
  final String? myEmail;

  /// 업무 요청인과 같은 표기의 내 이름.
  final String? myName;

  /// 방금 바꾼 상태를 되돌릴 값 — 시작·완료·보류·접수로 응답에만 있다.
  final WorkTaskUndo? undo;

  List<WorkTask> get remaining {
    final rows = tasks.where((task) => task.isOpen).toList();
    rows.sort((a, b) => compareWorkTasks(a, b, today));
    return rows;
  }

  List<WorkTask> get held {
    final rows = tasks.where((task) => task.isHeld).toList();
    rows.sort((a, b) => compareWorkTasks(a, b, today));
    return rows;
  }

  /// 최근 2주 완료 — 늦게 끝낸 것부터.
  List<WorkTask> get recentDone {
    final rows = tasks.where((task) => task.isDone).toList();
    rows.sort((a, b) {
      final byDay = b.completedDate.compareTo(a.completedDate);
      if (byDay != 0) return byDay;
      return a.title.compareTo(b.title);
    });
    return rows;
  }

  int get dueTodayCount => remaining
      .where((task) => workDueKind(task.dueDate, today) == WorkDueKind.today)
      .length;

  int get overdueCount => remaining
      .where((task) => workDueKind(task.dueDate, today) == WorkDueKind.overdue)
      .length;

  factory WorkTaskBoard.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'];
    final tasks = <WorkTask>[];
    if (rawTasks is List) {
      for (final row in rawTasks) {
        if (row is Map) {
          tasks.add(WorkTask.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }
    final rawAssignees = json['assignees'];
    final assignees = <WorkAssignee>[];
    if (rawAssignees is List) {
      for (final row in rawAssignees) {
        if (row is Map) {
          final person = WorkAssignee.fromJson(Map<String, dynamic>.from(row));
          if (person.email.isNotEmpty) assignees.add(person);
        }
      }
    }
    final rawPriorities = json['priorities'];
    final priorities = <WorkPriority>[];
    if (rawPriorities is List) {
      for (final row in rawPriorities) {
        if (row is Map) {
          final priority = WorkPriority.fromJson(
            Map<String, dynamic>.from(row),
          );
          if (priority.id.isNotEmpty && priority.name.isNotEmpty) {
            priorities.add(priority);
          }
        }
      }
    }
    priorities.sort(
      (a, b) => workPriorityRank(a.name).compareTo(workPriorityRank(b.name)),
    );
    final email = (json['myEmail'] ?? '').toString().trim();
    final namedTasks = [
      for (final task in tasks)
        if (workDisplayName(task.requester, assignees) == task.requester)
          task
        else
          task.withRequester(workDisplayName(task.requester, assignees)),
    ];
    final name = (json['myName'] ?? '').toString().trim();
    return WorkTaskBoard(
      today: (json['today'] ?? '').toString(),
      tasks: namedTasks,
      assignees: assignees,
      priorities: priorities,
      myEmail: email.isEmpty ? null : email,
      myName: name.isEmpty ? null : name,
      undo: json['undo'] is Map
          ? WorkTaskUndo.fromJson(
              Map<String, dynamic>.from(json['undo'] as Map),
            )
          : null,
    );
  }
}

/// 상태를 바꾸기 전 값 — 「실행 취소」가 그대로 되돌린다 (연구소 웹 undoLifecycle 과 같음).
class WorkTaskUndo {
  const WorkTaskUndo({
    required this.taskId,
    required this.status,
    this.startDate = '',
    this.completedDate = '',
  });

  final String taskId;
  final String status;
  final String startDate;
  final String completedDate;

  bool get isValid => taskId.isNotEmpty && status.isNotEmpty;

  factory WorkTaskUndo.fromJson(Map<String, dynamic> json) => WorkTaskUndo(
    taskId: (json['taskId'] ?? '').toString(),
    status: (json['status'] ?? '').toString(),
    startDate: (json['startDate'] ?? '').toString(),
    completedDate: (json['completedDate'] ?? '').toString(),
  );
}
