import 'package:coad_customer_calls/data/mail_repository.dart';
import 'package:coad_customer_calls/features/mail/mail_helpers.dart';
import 'package:coad_customer_calls/features/mail/mail_models.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final mailRepositoryProvider = Provider<MailRepository>((ref) {
  return MailRepository(ref.watch(appDependenciesProvider));
});

final mailCatalogProvider = FutureProvider.autoDispose<MailCatalog>((
  ref,
) async {
  return ref.watch(mailRepositoryProvider).fetchCatalog();
});

final mailSendsProvider = FutureProvider.autoDispose<List<MailSendRecord>>((
  ref,
) async {
  return ref.watch(mailRepositoryProvider).fetchSends();
});

final mailTelegramAgentsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  return ref.watch(mailRepositoryProvider).fetchTelegramAgentNames();
});

/// 이력 → 발송 탭으로 받는 사람·첨부를 넘길 때.
final mailReuseProvider = StateProvider<MailReuseRequest?>((ref) => null);
