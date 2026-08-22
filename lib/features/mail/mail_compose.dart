/// COAD_home `MailSender` 제목·본문·검증과 동일한 규칙.
class MailCompose {
  MailCompose._();

  static const List<String> ccRecipients = [
    'sales@coaddoor.com',
    'sales2@coaddoor.com',
  ];

  static final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isValidEmail(String raw) {
    final e = raw.trim();
    if (e.isEmpty) return false;
    return _emailRe.hasMatch(e);
  }

  static String subject({required String senderName}) {
    final sender = senderName.trim().isEmpty ? '관리자' : senderName.trim();
    return '[COAD] $sender - 선택된 파일 발송';
  }

  static String body({
    required String senderName,
    String phone = '',
    String email = '',
    List<String> attachmentNames = const [],
  }) {
    final name = senderName.trim().isEmpty ? '관리자' : senderName.trim();
    final buf = StringBuffer()
      ..writeln('안녕하세요!')
      ..writeln()
      ..writeln('코아드의 $name입니다. 😊 마음이 따뜻해지는 하루 보내고 계시죠?')
      ..writeln()
      ..writeln('궁금한 점 있으시면 언제든 편하게 연락 주세요!')
      ..writeln();

    final p = phone.trim();
    final e = email.trim();
    if (p.isNotEmpty || e.isNotEmpty) {
      if (p.isNotEmpty) buf.writeln('📞 $p');
      if (e.isNotEmpty) buf.writeln('📧 $e');
      buf.writeln();
    }

    final names = attachmentNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.isNotEmpty) {
      buf.writeln('첨부해 드린 파일:');
      buf.writeln();
      for (final n in names) {
        buf.writeln(n);
      }
      buf.writeln();
    }

    buf.write('늘 고맙습니다! 오늘도 행복 가득한 시간 보내세요! 🌈');
    return buf.toString();
  }

  static String resolveTelegramAgentName(
    String? userName,
    Iterable<String> agentNames,
  ) {
    final n = userName?.trim() ?? '';
    if (n.isEmpty) return '';
    final low = n.toLowerCase();
    for (final raw in agentNames) {
      final an = raw.trim();
      if (an.isEmpty) continue;
      if (an == n || an.toLowerCase() == low) return an;
    }
    return '';
  }
}
