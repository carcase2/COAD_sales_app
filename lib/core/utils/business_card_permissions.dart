import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/models/business_card.dart';

/// 명함 수첩 메뉴 접근. 고객전화와 동일하게 레거시(권한 배열 비어 있음)는 허용.
bool canAccessBusinessCards(AppUser? user) {
  if (user == null) return false;
  if (isAppAdmin(user)) return true;
  final p = user.permissions;
  if (p.isEmpty) return true;
  return p.contains('all') ||
      p.contains('sales_calls') ||
      p.contains('business_cards');
}

bool canViewBusinessCard(AppUser? user, BusinessCard card) {
  if (user == null) return false;
  if (isAppAdmin(user)) return true;
  if (card.createdBy == user.id) return true;
  return card.visibility == BusinessCardVisibility.team;
}

bool canEditBusinessCard(AppUser? user, BusinessCard card) {
  if (user == null) return false;
  if (isAppAdmin(user)) return true;
  return card.createdBy == user.id;
}

bool canDeleteBusinessCardComment({
  required AppUser? user,
  required BusinessCardComment comment,
}) {
  if (user == null) return false;
  if (isAppAdmin(user)) return true;
  return comment.createdBy == user.id;
}

bool canEditBusinessCardComment({
  required AppUser? user,
  required BusinessCardComment comment,
}) {
  if (user == null) return false;
  return comment.createdBy == user.id;
}
