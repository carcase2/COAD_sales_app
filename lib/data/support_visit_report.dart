const kSupportVisitReportMarker = '[방문기록]';

bool isSupportVisitReportText(String raw) =>
    raw.trimLeft().startsWith(kSupportVisitReportMarker);

class SupportVisitReport {
  const SupportVisitReport({
    this.id,
    required this.visitYmd,
    required this.completed,
    required this.paid,
    this.amount,
    this.depositYmd,
    this.depositPaid = false,
    this.parts = const [],
    this.photoUrls = const [],
    this.nextVisitYmd,
    this.notes = '',
    this.createdBy,
    this.createdAt,
  });

  final String? id;
  final String visitYmd;
  final bool completed;
  final bool paid;
  final int? amount;
  final String? depositYmd;
  final bool depositPaid;
  final List<String> parts;
  final List<String> photoUrls;
  final String? nextVisitYmd;
  final String notes;
  final String? createdBy;
  final DateTime? createdAt;

  bool get isPaid => paid && (amount ?? 0) > 0;

  SupportVisitReport copyWith({bool? depositPaid}) {
    return SupportVisitReport(
      id: id,
      visitYmd: visitYmd,
      completed: completed,
      paid: paid,
      amount: amount,
      depositYmd: depositYmd,
      depositPaid: depositPaid ?? this.depositPaid,
      parts: parts,
      photoUrls: photoUrls,
      nextVisitYmd: nextVisitYmd,
      notes: notes,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

String serializeSupportVisitReport(SupportVisitReport report) {
  final paid = report.isPaid;
  return [
    kSupportVisitReportMarker,
    '방문일: ${report.visitYmd}',
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
    completed: (fields['완료'] ?? '') == '완료',
    paid: paid,
    amount: paid ? amount : null,
    depositYmd: paid ? _ymdOrNull(fields['입금예정']) : null,
    depositPaid: paid && (fields['입금완료'] ?? '') == '완료',
    parts: parts,
    photoUrls: photos,
    nextVisitYmd: _ymdOrNull(fields['다음방문']),
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
