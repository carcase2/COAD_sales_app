import 'package:flutter/material.dart';

class MailCategory {
  const MailCategory({
    required this.id,
    required this.name,
    this.colorHex = '#3b82f6',
  });

  final String id;
  final String name;
  final String colorHex;

  Color get color {
    var h = colorHex.trim().replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? const Color(0xFF3B82F6) : Color(v);
  }

  factory MailCategory.fromJson(Map<String, dynamic> json) {
    return MailCategory(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}'.trim(),
      colorHex: '${json['color'] ?? '#3b82f6'}'.trim().isEmpty
          ? '#3b82f6'
          : '${json['color']}'.trim(),
    );
  }
}

class MailFile {
  const MailFile({
    required this.id,
    required this.name,
    required this.originalName,
    required this.url,
    this.categoryId,
    this.createdAt,
  });

  final String id;
  final String name;
  final String originalName;
  final String url;
  final String? categoryId;
  final DateTime? createdAt;

  String get displayName => name.trim().isNotEmpty ? name : originalName;

  factory MailFile.fromJson(Map<String, dynamic> json) {
    return MailFile(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      originalName: '${json['original_name'] ?? json['name'] ?? ''}',
      url: '${json['url'] ?? ''}',
      categoryId: json['category_id']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}

class MailAssignee {
  const MailAssignee({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.groupName,
    this.groupColorHex,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? groupName;
  final String? groupColorHex;
}

class MailAttachment {
  const MailAttachment({required this.name, required this.url});

  final String name;
  final String url;

  Map<String, dynamic> toJson() => {'name': name, 'url': url};

  factory MailAttachment.fromJson(Map<String, dynamic> json) {
    return MailAttachment(
      name: '${json['name'] ?? ''}',
      url: '${json['url'] ?? ''}',
    );
  }
}

class MailSendRecord {
  const MailSendRecord({
    required this.id,
    required this.toEmail,
    required this.subject,
    this.body,
    this.senderUserId,
    this.senderUserName,
    this.attachments = const [],
    this.status,
    this.errorMessage,
    this.sentAt,
    this.createdAt,
  });

  final String id;
  final String toEmail;
  final String subject;
  final String? body;
  final String? senderUserId;
  final String? senderUserName;
  final List<MailAttachment> attachments;
  final String? status;
  final String? errorMessage;
  final DateTime? sentAt;
  final DateTime? createdAt;

  bool get isFailed => status == 'failed';
  bool get isSuccess => status == 'success';

  DateTime get sortAt =>
      sentAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory MailSendRecord.fromJson(Map<String, dynamic> json) {
    final raw = json['attachments'];
    final atts = <MailAttachment>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          atts.add(MailAttachment.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return MailSendRecord(
      id: '${json['id'] ?? ''}',
      toEmail: '${json['to_email'] ?? ''}',
      subject: '${json['subject'] ?? ''}',
      body: json['body']?.toString(),
      senderUserId: json['sender_user_id']?.toString(),
      senderUserName: json['sender_user_name']?.toString(),
      attachments: atts,
      status: json['status']?.toString(),
      errorMessage: json['error_message']?.toString(),
      sentAt: DateTime.tryParse('${json['sent_at'] ?? ''}'),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}

class MailFileGroup {
  const MailFileGroup({
    required this.id,
    required this.name,
    required this.color,
    required this.items,
  });

  final String id;
  final String name;
  final Color color;
  final List<MailFile> items;

  static const uncategorizedId = '__none__';

  static List<MailFileGroup> from({
    required List<MailFile> files,
    required List<MailCategory> categories,
  }) {
    final byId = <String, List<MailFile>>{};
    for (final f in files) {
      final key = (f.categoryId == null || f.categoryId!.isEmpty)
          ? uncategorizedId
          : f.categoryId!;
      byId.putIfAbsent(key, () => []).add(f);
    }
    final catById = {for (final c in categories) c.id: c};
    final result = byId.entries.map((e) {
      if (e.key == uncategorizedId) {
        return MailFileGroup(
          id: uncategorizedId,
          name: '미분류',
          color: const Color(0xFF6B7280),
          items: e.value,
        );
      }
      final cat = catById[e.key];
      return MailFileGroup(
        id: e.key,
        name: cat?.name ?? '기타',
        color: cat?.color ?? const Color(0xFF6B7280),
        items: e.value,
      );
    }).toList();
    result.sort((a, b) {
      if (a.id == uncategorizedId) return 1;
      if (b.id == uncategorizedId) return -1;
      return a.name.compareTo(b.name);
    });
    return result;
  }
}

class MailCatalog {
  const MailCatalog({
    required this.assignees,
    required this.files,
    required this.categories,
  });

  final List<MailAssignee> assignees;
  final List<MailFile> files;
  final List<MailCategory> categories;

  List<MailFileGroup> get groups =>
      MailFileGroup.from(files: files, categories: categories);
}
