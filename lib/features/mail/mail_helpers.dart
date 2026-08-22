import 'package:coad_customer_calls/features/mail/mail_models.dart';

class MailRecentRecipient {
  const MailRecentRecipient({
    required this.email,
    this.lastAttachmentCount = 0,
  });

  final String email;
  final int lastAttachmentCount;
}

class MailReuseRequest {
  const MailReuseRequest({required this.toEmail, this.attachments = const []});

  final String toEmail;
  final List<MailAttachment> attachments;
}

/// 성공 발송 기준, 최근 받는 사람(중복 제거).
List<MailRecentRecipient> uniqueRecentRecipients(
  List<MailSendRecord> rows, {
  int limit = 8,
}) {
  final seen = <String>{};
  final out = <MailRecentRecipient>[];
  for (final r in rows) {
    if (r.isFailed) continue;
    final email = r.toEmail.trim();
    if (email.isEmpty) continue;
    final key = email.toLowerCase();
    if (!seen.add(key)) continue;
    out.add(
      MailRecentRecipient(
        email: email,
        lastAttachmentCount: r.attachments.length,
      ),
    );
    if (out.length >= limit) break;
  }
  return out;
}

/// 이력 첨부를 자료실 파일 id로 맞춘다. URL 우선, 없으면 이름.
Set<String> matchAttachmentFileIds(
  List<MailFile> files,
  List<MailAttachment> attachments,
) {
  final ids = <String>{};
  for (final a in attachments) {
    MailFile? hit;
    if (a.url.trim().isNotEmpty) {
      for (final f in files) {
        if (f.url == a.url) {
          hit = f;
          break;
        }
      }
    }
    if (hit == null) {
      final name = a.name.trim();
      if (name.isEmpty) continue;
      for (final f in files) {
        if (f.originalName == name || f.displayName == name || f.name == name) {
          hit = f;
          break;
        }
      }
    }
    if (hit != null) ids.add(hit.id);
  }
  return ids;
}

String mailHistoryDayLabel(DateTime local, DateTime nowLocal) {
  final a = DateTime(local.year, local.month, local.day);
  final b = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  return '${a.month}월 ${a.day}일';
}
