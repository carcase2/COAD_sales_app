import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ConsultationDraft {
  const ConsultationDraft({
    this.content = '',
    this.statusId,
    this.nextDateYmd,
    this.unsuccessfulReason,
  });

  final String content;
  final int? statusId;
  final String? nextDateYmd;
  final String? unsuccessfulReason;

  bool get isEmpty =>
      content.trim().isEmpty &&
      (nextDateYmd == null || nextDateYmd!.trim().isEmpty) &&
      (unsuccessfulReason == null || unsuccessfulReason!.trim().isEmpty);

  Map<String, dynamic> toJson() => {
    'content': content,
    'statusId': statusId,
    'nextDateYmd': nextDateYmd,
    'unsuccessfulReason': unsuccessfulReason,
  };

  factory ConsultationDraft.fromJson(Map<String, dynamic> json) {
    return ConsultationDraft(
      content: (json['content'] ?? '').toString(),
      statusId: json['statusId'] is int
          ? json['statusId'] as int
          : int.tryParse('${json['statusId'] ?? ''}'),
      nextDateYmd: (json['nextDateYmd'] as String?)?.trim(),
      unsuccessfulReason: (json['unsuccessfulReason'] as String?)?.trim(),
    );
  }
}

class ConsultationDraftStore {
  ConsultationDraftStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String callId) => 'consultation_draft_v1_$callId';

  ConsultationDraft? load(String callId) {
    final raw = _prefs.getString(_key(callId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final draft = ConsultationDraft.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return draft.isEmpty ? null : draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String callId, ConsultationDraft draft) async {
    if (draft.isEmpty) {
      await clear(callId);
      return;
    }
    await _prefs.setString(_key(callId), jsonEncode(draft.toJson()));
  }

  Future<void> clear(String callId) async {
    await _prefs.remove(_key(callId));
  }
}
