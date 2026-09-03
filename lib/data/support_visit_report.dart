const kSupportVisitReportMarker = '[방문기록]';

bool isSupportVisitReportText(String raw) =>
    raw.trimLeft().startsWith(kSupportVisitReportMarker);

/// 방문 기록 저장 전 검증. 완료+유상이면 금액·입금예정일이 필요하다.
String? supportVisitReportIssue(SupportVisitReport report) {
  if (report.visitYmd.trim().isEmpty) return '방문일을 선택해 주세요.';
  if ((report.visitTime ?? '').trim().isEmpty) {
    return '방문 시간을 선택해 주세요.';
  }
  if (report.notes.trim().isEmpty) return '방문 내용을 입력해 주세요.';
  if (!report.completed) {
    if ((report.nextVisitYmd ?? '').trim().isEmpty) {
      return '미완료이면 다음 방문일을 선택해 주세요.';
    }
    if ((report.nextVisitTeamId ?? '').trim().isEmpty) {
      return '미완료이면 다음 방문 팀을 선택해 주세요.';
    }
    if ((report.nextVisitTime ?? '').trim().isEmpty) {
      return '미완료이면 다음 방문 시간을 선택해 주세요.';
    }
    return null;
  }
  if (report.paid) {
    if ((report.amount ?? 0) <= 0) return '유상이면 금액을 입력해 주세요.';
    if ((report.depositYmd ?? '').trim().isEmpty) {
      return '유상이면 입금예정일을 선택해 주세요.';
    }
  }
  return null;
}

class SupportVisitReport {
  const SupportVisitReport({
    this.id,
    required this.visitYmd,
    this.visitTime,
    required this.completed,
    required this.paid,
    this.amount,
    this.depositYmd,
    this.depositPaid = false,
    this.parts = const [],
    this.photoUrls = const [],
    this.nextVisitYmd,
    this.nextVisitTeamId,
    this.nextVisitTime,
    this.notes = '',
    this.createdBy,
    this.createdAt,
  });

  final String? id;
  final String visitYmd;
  final String? visitTime;
  final bool completed;
  final bool paid;
  final int? amount;
  final String? depositYmd;
  final bool depositPaid;
  final List<String> parts;
  final List<String> photoUrls;
  final String? nextVisitYmd;
  final String? nextVisitTeamId;
  final String? nextVisitTime;
  final String notes;
  final String? createdBy;
  final DateTime? createdAt;

  bool get isPaid => paid && (amount ?? 0) > 0;

  SupportVisitReport copyWith({bool? depositPaid}) {
    return SupportVisitReport(
      id: id,
      visitYmd: visitYmd,
      visitTime: visitTime,
      completed: completed,
      paid: paid,
      amount: amount,
      depositYmd: depositYmd,
      depositPaid: depositPaid ?? this.depositPaid,
      parts: parts,
      photoUrls: photoUrls,
      nextVisitYmd: nextVisitYmd,
      nextVisitTeamId: nextVisitTeamId,
      nextVisitTime: nextVisitTime,
      notes: notes,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

String serializeSupportVisitReport(SupportVisitReport report) {
  final paid = report.isPaid;
  final time = (report.visitTime ?? '').trim();
  final timeLabel = time.length >= 5 ? time.substring(0, 5) : time;
  final nextTime = (report.nextVisitTime ?? '').trim();
  final nextTimeLabel =
      nextTime.length >= 5 ? nextTime.substring(0, 5) : nextTime;
  return [
    kSupportVisitReportMarker,
    '방문일: ${report.visitYmd}',
    if (timeLabel.isNotEmpty) '방문시간: $timeLabel',
    '완료: ${report.completed ? '완료' : '미완료'}',
    '유상: ${paid ? '유상' : '무상'}',
    if (paid && report.amount != null) '금액: ${report.amount}',
    if (paid && (report.depositYmd ?? '').trim().isNotEmpty)
      '입금예정: ${report.depositYmd!.trim()}',
    if (paid) '입금완료: ${report.depositPaid ? '완료' : '미입금'}',
    if (report.parts.isNotEmpty) '부품: ${report.parts.join(', ')}',
    if (report.photoUrls.isNotEmpty) '사진: ${report.photoUrls.join(' | ')}',
    if (!report.completed && (report.nextVisitYmd ?? '').trim().isNotEmpty)
      '다음방문: ${report.nextVisitYmd!.trim()}',
    if (!report.completed && nextTimeLabel.isNotEmpty)
      '다음방문시간: $nextTimeLabel',
    '내용:',
    report.notes.trim(),
  ].join('\n');
}

SupportVisitReport? parseSupportVisitReport(
  String raw, {
  String? id,
  String? createdBy,
  DateTime? createdAt,
}) {
  final text = raw.replaceAll('\r\n', '\n').trim();
  if (!isSupportVisitReportText(text)) return null;
  final lines = text.split('\n');
  final fields = <String, String>{};
  final body = <String>[];
  var inBody = false;
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (inBody) {
      body.add(line);
      continue;
    }
    if (line.trim() == '내용:') {
      inBody = true;
      continue;
    }
    final idx = line.indexOf(':');
    if (idx <= 0) {
      inBody = true;
      body.add(line);
      continue;
    }
    final key = line.substring(0, idx).trim();
    final value = line.substring(idx + 1).trim();
    fields[key] = value;
  }

  final paidLabel = fields['유상'] ?? '';
  final amount = int.tryParse((fields['금액'] ?? '').replaceAll(',', ''));
  final paid = paidLabel == '유상' && (amount ?? 0) > 0;
  final parts = (fields['부품'] ?? '')
      .split(RegExp(r'[,|，]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final photos = (fields['사진'] ?? '')
      .split(RegExp(r'\s*\|\s*|,'))
      .map((e) => e.trim())
      .where((e) => e.startsWith('http'))
      .toList();

  return SupportVisitReport(
    id: id,
    visitYmd: fields['방문일'] ?? '',
    visitTime: _timeOrNull(fields['방문시간']),
    completed: (fields['완료'] ?? '') == '완료',
    paid: paid,
    amount: paid ? amount : null,
    depositYmd: paid ? _ymdOrNull(fields['입금예정']) : null,
    depositPaid: paid && (fields['입금완료'] ?? '') == '완료',
    parts: parts,
    photoUrls: photos,
    nextVisitYmd: _ymdOrNull(fields['다음방문']),
    nextVisitTime: _timeOrNull(fields['다음방문시간']),
    notes: body.join('\n').trim(),
    createdBy: createdBy,
    createdAt: createdAt,
  );
}

String? _ymdOrNull(String? raw) {
  final v = (raw ?? '').trim();
  if (v.length < 10) return null;
  return v.substring(0, 10);
}

String? _timeOrNull(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return null;
  return v.length >= 5 ? v.substring(0, 5) : v;
}
