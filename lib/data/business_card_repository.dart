import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/business_card_permissions.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:coad_customer_calls/models/business_card.dart'
    show BusinessCardListFilter, BusinessCardSort;

/// 이름 입력으로 명함을 고를 때: 완전 일치 → 앞글자 일치 → (3글자 이상) 포함.
List<BusinessCard> matchingBusinessCardsByName(
  String query,
  List<BusinessCard> cards,
) {
  final q = query.trim().toLowerCase();
  if (q.length < 2 || cards.isEmpty) return const [];
  final exact = cards
      .where((c) => c.name.trim().toLowerCase() == q)
      .toList(growable: false);
  if (exact.isNotEmpty) return exact;
  final prefix = cards
      .where((c) => c.name.trim().toLowerCase().startsWith(q))
      .toList(growable: false);
  if (prefix.isNotEmpty) return prefix;
  if (q.length < 3) return const [];
  return cards
      .where((c) => c.name.trim().toLowerCase().contains(q))
      .toList(growable: false);
}

BusinessCard? bestBusinessCardNameMatch(
  String query,
  List<BusinessCard> cards,
) {
  final matches = matchingBusinessCardsByName(query, cards);
  return matches.isEmpty ? null : matches.first;
}

bool businessCardHasEmail(BusinessCard card) {
  final e = card.email.trim();
  if (e.isEmpty || !e.contains('@')) return false;
  final at = e.indexOf('@');
  return at > 0 && e.indexOf('.', at) > at + 1;
}

/// 메일 받는 사람용 — 이메일이 있는 명함만, 이름·회사·메일 일치 우선.
List<BusinessCard> businessCardsForMailRecipient(
  String query,
  List<BusinessCard> cards, {
  int limit = 20,
}) {
  final withMail = cards.where(businessCardHasEmail).toList();
  if (withMail.isEmpty) return const [];
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return withMail.take(limit).toList(growable: false);

  int score(BusinessCard c) {
    final name = c.name.trim().toLowerCase();
    final company = c.company.trim().toLowerCase();
    final email = c.email.trim().toLowerCase();
    if (name == q || email == q) return 0;
    if (name.startsWith(q) || email.startsWith(q)) return 1;
    if (company == q || company.startsWith(q)) return 2;
    if (name.contains(q) || email.contains(q) || company.contains(q)) return 3;
    return 9;
  }

  final ranked = withMail.where((c) => score(c) < 9).toList()
    ..sort((a, b) => score(a).compareTo(score(b)));
  if (ranked.length <= limit) return ranked;
  return ranked.take(limit).toList(growable: false);
}

class BusinessCardPhoneOption {
  const BusinessCardPhoneOption({required this.label, required this.phone});

  final String label;
  final String phone;
}

List<BusinessCardPhoneOption> businessCardPhoneOptions(BusinessCard card) {
  final out = <BusinessCardPhoneOption>[];
  final seen = <String>{};
  void add(String label, String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    final digits = normalizePhoneDigits(t);
    if (digits.length < 8 || !seen.add(digits)) return;
    out.add(
      BusinessCardPhoneOption(
        label: label,
        phone: formatKoreanPhoneHyphenated(t),
      ),
    );
  }

  add('휴대폰', card.mobilePhone);
  add('사무실', card.officePhone);
  add('팩스', card.faxPhone);
  return out;
}

class BusinessCardFill {
  const BusinessCardFill({
    required this.card,
    required this.phone,
    required this.phoneLabel,
  });

  final BusinessCard card;
  final String phone;
  final String phoneLabel;
}

List<BusinessCardFill> businessCardFillsOf(Iterable<BusinessCard> cards) {
  final out = <BusinessCardFill>[];
  for (final card in cards) {
    final phones = businessCardPhoneOptions(card);
    if (phones.isEmpty) {
      out.add(BusinessCardFill(card: card, phone: '', phoneLabel: ''));
      continue;
    }
    for (final p in phones) {
      out.add(
        BusinessCardFill(card: card, phone: p.phone, phoneLabel: p.label),
      );
    }
  }
  return out;
}

List<BusinessCardFill> businessCardFillChoices(
  String query,
  List<BusinessCard> cards,
) {
  return businessCardFillsOf(matchingBusinessCardsByName(query, cards));
}

/// 입력한 번호와 같은 명함 번호만 남긴다. 없으면 카드의 전체 번호다.
List<BusinessCardFill> businessCardFillsForPhone(
  String phone,
  List<BusinessCard> cards,
) {
  final digits = normalizePhoneDigits(phone);
  final fills = businessCardFillsOf(cards);
  if (digits.length < 8) return fills;
  final exact = fills
      .where((f) => normalizePhoneDigits(f.phone) == digits)
      .toList(growable: false);
  return exact.isEmpty ? fills : exact;
}

class BusinessCardDuplicate {
  const BusinessCardDuplicate({required this.card, required this.reasons});

  final BusinessCard card;

  /// 같은 항목 — 휴대폰 · 사무실 번호 · 메일.
  final List<String> reasons;

  /// 「김철수 (휴대폰·메일 같음)」
  String get label => '${card.displayName} (${reasons.join('·')} 같음)';
}

class BusinessCardRepository {
  BusinessCardRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const int pageSize = 30;

  String _sanitizeOrValue(String raw) {
    return raw.replaceAll(RegExp(r'[,.()%]'), ' ').trim();
  }

  /// 검색어용 — or 필터를 깨는 `, ( )`와 와일드카드 `%`만 뺀다.
  /// 점은 남긴다 (값 안의 점은 PostgREST가 그대로 둔다). `kim.lee@` 같은 메일 검색용.
  String _sanitizeSearch(String raw) {
    return raw.replaceAll(RegExp(r'[,()%]'), ' ').trim();
  }

  Future<BusinessCardListResult> list({
    required AppUser user,
    String query = '',
    BusinessCardListFilter filter = BusinessCardListFilter.all,
    BusinessCardSort sort = BusinessCardSort.recent,
    int offset = 0,
    int limit = pageSize,
  }) async {
    if (!canAccessBusinessCards(user)) {
      throw ApiException('명함 수첩 권한이 없습니다.');
    }

    var request = _client
        .from('business_cards')
        .select('*, business_card_comments(id, deleted_at)')
        .isFilter('deleted_at', null);

    final admin = isAppAdmin(user);
    final safeId = _sanitizeOrValue(user.id);

    switch (filter) {
      case BusinessCardListFilter.mine:
        request = request.eq('created_by', user.id);
      case BusinessCardListFilter.privateOnly:
        request = request.eq('visibility', 'private');
        if (!admin) request = request.eq('created_by', user.id);
      case BusinessCardListFilter.blacklisted:
        request = request.eq('is_blacklisted', true);
        if (!admin && safeId.isNotEmpty) {
          request = request.or('visibility.eq.team,created_by.eq.$safeId');
        }
      case BusinessCardListFilter.all:
        if (!admin && safeId.isNotEmpty) {
          request = request.or('visibility.eq.team,created_by.eq.$safeId');
        }
    }

    final q = query.trim();
    if (q.isNotEmpty) {
      final like = '%${_sanitizeSearch(q)}%';
      final digits = normalizePhoneDigits(q);
      if (digits.length >= 4) {
        request = request.or(
          'search_text.ilike.$like,'
          'mobile_phone.ilike.%$digits%,'
          'office_phone.ilike.%$digits%,'
          'fax_phone.ilike.%$digits%,'
          'address.ilike.$like',
        );
      } else {
        request = request.ilike('search_text', like);
      }
    }

    // name·company는 빈 문자열 기본값이라, 비어 있는 명함이 가나다 앞에 온다.
    final ordered = switch (sort) {
      BusinessCardSort.recent => request.order('updated_at', ascending: false),
      BusinessCardSort.name =>
        request.order('name', ascending: true).order('company', ascending: true),
      BusinessCardSort.company =>
        request.order('company', ascending: true).order('name', ascending: true),
    };
    final rows = await ordered.range(offset, offset + limit - 1);

    final items = <BusinessCard>[];
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final card = BusinessCard.fromJson(row);
      if (canViewBusinessCard(user, card)) items.add(card);
    }
    return BusinessCardListResult(
      items: items,
      hasMore: List<dynamic>.from(rows).length >= limit,
    );
  }

  Future<BusinessCard> getById({
    required AppUser user,
    required String id,
  }) async {
    final row = await _client
        .from('business_cards')
        .select()
        .eq('id', id)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) {
      throw ApiException('명함을 찾을 수 없습니다.');
    }
    final card = BusinessCard.fromJson(row);
    if (!canViewBusinessCard(user, card)) {
      throw ApiException('이 명함을 볼 권한이 없습니다.');
    }
    return card;
  }

  Future<List<BusinessCard>> findByName({
    required AppUser user,
    required String name,
  }) async {
    if (!canAccessBusinessCards(user)) return const [];
    final q = _sanitizeOrValue(name);
    if (q.length < 2) return const [];
    final rows = await _client
        .from('business_cards')
        .select()
        .isFilter('deleted_at', null)
        .ilike('name', '%$q%')
        .order('updated_at', ascending: false)
        .limit(12);
    return List<Map<String, dynamic>>.from(rows)
        .map(BusinessCard.fromJson)
        .where((c) => canViewBusinessCard(user, c))
        .toList();
  }

  Future<List<BusinessCard>> findByPhone({
    required AppUser user,
    required String phone,
    String? excludeId,
  }) async {
    if (!canAccessBusinessCards(user)) return const [];
    final digits = normalizePhoneDigits(phone);
    if (digits.length < 8) return const [];
    final hyphen = formatKoreanPhoneHyphenated(digits);
    var request = _client
        .from('business_cards')
        .select()
        .isFilter('deleted_at', null)
        .or(
          'mobile_phone.eq.$hyphen,mobile_phone.eq.$digits,'
          'office_phone.eq.$hyphen,office_phone.eq.$digits,'
          'fax_phone.eq.$hyphen,fax_phone.eq.$digits,'
          'mobile_phone.ilike.%$digits%,'
          'office_phone.ilike.%$digits%,'
          'fax_phone.ilike.%$digits%',
        );
    if (excludeId != null && excludeId.isNotEmpty) {
      request = request.neq('id', excludeId);
    }
    final rows = await request.limit(12);
    return List<Map<String, dynamic>>.from(rows)
        .map(BusinessCard.fromJson)
        .where((c) => canViewBusinessCard(user, c))
        .where(
          (c) =>
              normalizePhoneDigits(c.mobilePhone) == digits ||
              normalizePhoneDigits(c.officePhone) == digits ||
              normalizePhoneDigits(c.faxPhone) == digits,
        )
        .toList();
  }

  Future<List<BusinessCard>> findByEmail({
    required AppUser user,
    required String email,
  }) async {
    if (!canAccessBusinessCards(user)) return const [];
    final q = email.trim().toLowerCase();
    if (!q.contains('@') || q.length < 5) return const [];
    // 점(.)은 메일의 일부다. or 필터를 깨는 문자만 뺀다.
    final safe = q.replaceAll(RegExp(r'[,()%]'), '').trim();
    if (safe.isEmpty || !safe.contains('@')) return const [];
    final rows = await _client
        .from('business_cards')
        .select()
        .isFilter('deleted_at', null)
        .ilike('email', safe)
        .order('updated_at', ascending: false)
        .limit(12);
    return List<Map<String, dynamic>>.from(rows)
        .map(BusinessCard.fromJson)
        .where((c) => canViewBusinessCard(user, c))
        .where((c) => c.email.trim().toLowerCase() == q)
        .toList();
  }

  /// 저장 전 중복 확인 — 휴대폰·사무실 번호·메일 중 하나라도 같은 명함과, 무엇이 같은지.
  Future<List<BusinessCardDuplicate>> findDuplicates({
    required AppUser user,
    required BusinessCard card,
    String? excludeId,
  }) async {
    final reasons = <String, Set<String>>{};
    final byId = <String, BusinessCard>{};
    void add(Iterable<BusinessCard> found, String reason) {
      for (final c in found) {
        if (excludeId != null && c.id == excludeId) continue;
        byId[c.id] = c;
        reasons.putIfAbsent(c.id, () => <String>{}).add(reason);
      }
    }

    final checks = <(String, Future<List<BusinessCard>>)>[
      if (card.mobilePhone.trim().isNotEmpty)
        (
          '휴대폰',
          findByPhone(
            user: user,
            phone: card.mobilePhone,
            excludeId: excludeId,
          ),
        ),
      if (card.officePhone.trim().isNotEmpty)
        (
          '사무실 번호',
          findByPhone(
            user: user,
            phone: card.officePhone,
            excludeId: excludeId,
          ),
        ),
      if (card.email.trim().isNotEmpty)
        ('메일', findByEmail(user: user, email: card.email)),
    ];
    final results = await Future.wait(checks.map((c) => c.$2));
    for (var i = 0; i < checks.length; i++) {
      add(results[i], checks[i].$1);
    }
    return [
      for (final id in byId.keys)
        BusinessCardDuplicate(card: byId[id]!, reasons: reasons[id]!.toList()),
    ];
  }

  Future<BusinessCard> create({
    required AppUser user,
    required BusinessCard draft,
  }) async {
    if (!canAccessBusinessCards(user)) {
      throw ApiException('명함 수첩 권한이 없습니다.');
    }
    _assertHasIdentity(draft);
    final row = await _client
        .from('business_cards')
        .insert(draft.toInsertJson(userId: user.id, userName: user.name))
        .select()
        .single();
    return BusinessCard.fromJson(row);
  }

  Future<BusinessCard> update({
    required AppUser user,
    required BusinessCard card,
  }) async {
    final current = await getById(user: user, id: card.id);
    if (!canEditBusinessCard(user, current)) {
      throw ApiException('이 명함을 수정할 권한이 없습니다.');
    }
    _assertHasIdentity(card);
    final row = await _client
        .from('business_cards')
        .update(card.toUpdateJson(userId: user.id, userName: user.name))
        .eq('id', card.id)
        .isFilter('deleted_at', null)
        .select()
        .single();
    return BusinessCard.fromJson(row);
  }

  Future<void> softDelete({
    required AppUser user,
    required BusinessCard card,
  }) async {
    final current = await getById(user: user, id: card.id);
    if (!canEditBusinessCard(user, current)) {
      throw ApiException('이 명함을 삭제할 권한이 없습니다.');
    }
    await _client
        .from('business_cards')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'updated_by': user.id,
          'updated_by_name': user.name,
        })
        .eq('id', card.id);
  }

  Future<List<BusinessCardComment>> listComments({
    required AppUser user,
    required String cardId,
  }) async {
    await getById(user: user, id: cardId);
    final rows = await _client
        .from('business_card_comments')
        .select()
        .eq('card_id', cardId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(BusinessCardComment.fromJson).toList();
  }

  Future<BusinessCardComment> addComment({
    required AppUser user,
    required String cardId,
    required String body,
  }) async {
    await getById(user: user, id: cardId);
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ApiException('메모 내용을 입력해 주세요.');
    }
    final row = await _client
        .from('business_card_comments')
        .insert({
          'card_id': cardId,
          'body': trimmed,
          'created_by': user.id,
          'created_by_name': user.name,
        })
        .select()
        .single();
    return BusinessCardComment.fromJson(row);
  }

  Future<BusinessCardComment> updateComment({
    required AppUser user,
    required BusinessCardComment comment,
    required String body,
  }) async {
    if (!canEditBusinessCardComment(user: user, comment: comment)) {
      throw ApiException('이 메모를 수정할 권한이 없습니다.');
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ApiException('메모 내용을 입력해 주세요.');
    }
    final row = await _client
        .from('business_card_comments')
        .update({'body': trimmed})
        .eq('id', comment.id)
        .isFilter('deleted_at', null)
        .select()
        .single();
    return BusinessCardComment.fromJson(row);
  }

  Future<void> deleteComment({
    required AppUser user,
    required BusinessCardComment comment,
  }) async {
    if (!canDeleteBusinessCardComment(user: user, comment: comment)) {
      throw ApiException('이 메모를 삭제할 권한이 없습니다.');
    }
    await _client
        .from('business_card_comments')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', comment.id);
  }

  void _assertHasIdentity(BusinessCard card) {
    if (card.name.trim().isEmpty && card.company.trim().isEmpty) {
      throw ApiException('이름 또는 회사명을 입력해 주세요.');
    }
  }
}
