import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/business_card_permissions.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:coad_customer_calls/models/business_card.dart'
    show BusinessCardListFilter;

class BusinessCardRepository {
  BusinessCardRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const int pageSize = 30;

  String _sanitizeOrValue(String raw) {
    return raw.replaceAll(RegExp(r'[,.()%]'), ' ').trim();
  }

  Future<BusinessCardListResult> list({
    required AppUser user,
    String query = '',
    BusinessCardListFilter filter = BusinessCardListFilter.all,
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
      final like = '%${_sanitizeOrValue(q)}%';
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

    final rows = await request
        .order('updated_at', ascending: false)
        .range(offset, offset + limit - 1);

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

  Future<List<BusinessCard>> findByPhone({
    required AppUser user,
    required String phone,
    String? excludeId,
  }) async {
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
          'fax_phone.eq.$hyphen,fax_phone.eq.$digits',
        );
    if (excludeId != null && excludeId.isNotEmpty) {
      request = request.neq('id', excludeId);
    }
    final rows = await request.limit(8);
    return List<Map<String, dynamic>>.from(rows)
        .map(BusinessCard.fromJson)
        .where((c) => canViewBusinessCard(user, c))
        .toList();
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
    return List<Map<String, dynamic>>.from(rows)
        .map(BusinessCardComment.fromJson)
        .toList();
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
