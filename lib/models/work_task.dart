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

/// 연구소 업무 (`tasks`) 한 건. 완료도 완료한 날과 기한에 남긴다.
class WorkTask {
  const WorkTask({
    required this.id,
    required this.title,
    required this.detail,
    required this.status,
    this.dueDate,
    this.completedDate,
    this.assigneeNames = const [],
    this.assigneeEmails = const [],
    this.priorityId = '',
    this.priorityName = '',
    this.requester = '',
    this.createdAt = '',
  });

  final String id;
  final String title;
  final String detail;
  final String status;
  final String? dueDate;
  final String? completedDate;
  final List<String> assigneeNames;
  final List<String> assigneeEmails;
  final String priorityId;
  final String priorityName;
  final String requester;
  final String createdAt;

  bool get isHeld => status == '보류';

  bool get isDone => status == '완료';

  bool get isOpen => status == '접수' || status == '진행중';

  bool get canStart => status == '접수' || status == '보류';

  bool get canHold => status == '접수' || status == '진행중';

  bool get canComplete => status == '접수' || status == '진행중' || status == '보류';

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
    final completed = (json['completedDate'] ?? '').toString().trim();
    return WorkTask(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      dueDate: due.length >= 10 ? due.substring(0, 10) : null,
      completedDate: completed.length >= 10 ? completed.substring(0, 10) : null,
      assigneeNames: names,
      assigneeEmails: _stringList(json['assigneeEmails']),
      priorityId: (json['priorityId'] ?? '').toString().trim(),
      priorityName: (json['priority'] ?? '').toString().trim(),
      requester: (json['requester'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString().trim(),
    );
  }
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

String? _workYmd(String? raw) {
  final text = (raw ?? '').trim();
  if (text.length < 10) return null;
  return text.substring(0, 10);
}

/// 달력에 찍을 날. 완료 건은 기한과 완료한 날을 모두 포함한다.
Iterable<String> workTaskMarkDays(WorkTask task) sync* {
  final due = _workYmd(task.dueDate);
  if (due != null) yield due;
  if (!task.isDone) return;
  final done = _workYmd(task.completedDate);
  if (done != null && done != due) yield done;
}

/// 그 날 목록에 넣을지. 기한이 그 날이거나, 그 날 완료한 업무다.
bool workTaskOnDay(WorkTask task, String ymd) {
  final day = _workYmd(ymd);
  if (day == null) return false;
  for (final marked in workTaskMarkDays(task)) {
    if (marked == day) return true;
  }
  return false;
}

/// 그 날의 예정 또는 완료 목록. 급한 순, 같은 순위는 제목 순.
List<WorkTask> workTasksForDay(
  Iterable<WorkTask> tasks,
  String ymd, {
  required bool completed,
}) {
  final rows = [
    for (final task in tasks)
      if (task.isDone == completed && workTaskOnDay(task, ymd)) task,
  ];
  rows.sort((a, b) {
    final byPriority = workPriorityRank(
      a.priorityName,
    ).compareTo(workPriorityRank(b.priorityName));
    if (byPriority != 0) return byPriority;
    return a.title.compareTo(b.title);
  });
  return rows;
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
  });

  final String today;
  final List<WorkTask> tasks;
  final List<WorkAssignee> assignees;
  final List<WorkPriority> priorities;
  final String? myEmail;

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

  /// 완료 건. 남은 업무 수에는 넣지 않고, 달력과 그날 목록에서만 보여 준다.
  List<WorkTask> get completed {
    final rows = tasks.where((task) => task.isDone).toList();
    rows.sort((a, b) {
      final byDone = (b.completedDate ?? '').compareTo(a.completedDate ?? '');
      if (byDone != 0) return byDone;
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
          WorkTask(
            id: task.id,
            title: task.title,
            detail: task.detail,
            status: task.status,
            dueDate: task.dueDate,
            completedDate: task.completedDate,
            assigneeNames: task.assigneeNames,
            assigneeEmails: task.assigneeEmails,
            priorityId: task.priorityId,
            priorityName: task.priorityName,
            requester: workDisplayName(task.requester, assignees),
            createdAt: task.createdAt,
          ),
    ];
    return WorkTaskBoard(
      today: (json['today'] ?? '').toString(),
      tasks: namedTasks,
      assignees: assignees,
      priorities: priorities,
      myEmail: email.isEmpty ? null : email,
    );
  }
}
