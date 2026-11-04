import 'dart:convert';

import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSizeQuoteDraftPrefs = 'standard_unit_price_quote_drafts_v1';

/// 저장 전에 닫은 견적서. 이 기기에만 두고, 저장하면 지운다.
class SizeQuoteDraft {
  const SizeQuoteDraft({
    required this.doc,
    required this.savedAt,
    this.isNew = true,
  });

  final SizeQuoteDocument doc;
  final String savedAt;

  /// 서버에 아직 없는 새 견적서인지. false면 기존 견적서를 고치던 중이다.
  final bool isNew;

  Map<String, dynamic> toJson() => {
    'doc': doc.toJson(),
    'savedAt': savedAt,
    'isNew': isNew,
  };

  static SizeQuoteDraft? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final docRaw = raw['doc'];
    if (docRaw is! Map) return null;
    final doc = SizeQuoteDocument.fromJson(Map<String, dynamic>.from(docRaw));
    if (doc.id.isEmpty) return null;
    return SizeQuoteDraft(
      doc: doc,
      savedAt: '${raw['savedAt'] ?? ''}',
      isNew: raw['isNew'] != false,
    );
  }
}

class SizeQuoteDraftStore {
  SizeQuoteDraftStore(this._prefs);

  static const limit = 20;

  final SharedPreferences _prefs;

  static Future<SizeQuoteDraftStore> open() async =>
      SizeQuoteDraftStore(await SharedPreferences.getInstance());

  /// 최근에 둔 것부터.
  List<SizeQuoteDraft> load() {
    final raw = _prefs.getString(_kSizeQuoteDraftPrefs);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(SizeQuoteDraft.fromJson)
          .whereType<SizeQuoteDraft>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> put(SizeQuoteDraft draft) async {
    final next = [
      draft,
      ...load().where((e) => e.doc.id != draft.doc.id),
    ].take(limit).toList();
    await _save(next);
  }

  Future<void> remove(String id) async {
    final current = load();
    if (!current.any((e) => e.doc.id == id)) return;
    await _save(current.where((e) => e.doc.id != id).toList());
  }

  Future<void> _save(List<SizeQuoteDraft> items) async {
    await _prefs.setString(
      _kSizeQuoteDraftPrefs,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
