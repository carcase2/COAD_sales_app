import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/data/auth_repository.dart';
import 'package:coad_customer_calls/data/b2_upload_repository.dart';
import 'package:coad_customer_calls/data/estimate_document_repository.dart';
import 'package:coad_customer_calls/data/general_schedule_repository.dart';
import 'package:coad_customer_calls/data/gosu_sales_calls_repository.dart';
import 'package:coad_customer_calls/data/sales_calls_repository.dart';
import 'package:coad_customer_calls/data/usage_repository.dart';
import 'package:coad_customer_calls/data/ai_extractor_service.dart';
import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/data/support_as_quote_repository.dart';
import 'package:coad_customer_calls/data/support_as_visit_team_repository.dart';
import 'package:coad_customer_calls/data/support_unit_price_repository.dart';
import 'package:coad_customer_calls/data/mes_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'data/auth_controller.dart';

/// [main]에서 `overrideWithValue`로 주입.
final appDependenciesProvider = Provider<AppDependencies>((ref) {
  throw UnimplementedError('appDependenciesProvider must be overridden');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(appDependenciesProvider));
});

final salesCallsRepositoryProvider = Provider<SalesCallsRepository>((ref) {
  return SalesCallsRepository(ref.watch(appDependenciesProvider));
});

final gosuSalesCallsRepositoryProvider = Provider<GosuSalesCallsRepository>((
  ref,
) {
  return GosuSalesCallsRepository();
});

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  return UsageRepository();
});

/// 본사일반 일정 저장소. 대구지사는 `scheduleRepositoryProvider(ScheduleBranch.daegu)`.
final generalScheduleRepositoryProvider = Provider<GeneralScheduleRepository>((
  ref,
) {
  return GeneralScheduleRepository(
    ref.watch(appDependenciesProvider),
    // default branch = headOffice
  );
});

final b2UploadRepositoryProvider = Provider<B2UploadRepository>((ref) {
  return B2UploadRepository(ref.watch(appDependenciesProvider));
});

final aiExtractorServiceProvider = Provider<AiExtractorService>((ref) {
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  return AiExtractorService(apiKey: apiKey);
});

final estimateDocumentRepositoryProvider = Provider<EstimateDocumentRepository>(
  (ref) {
    return EstimateDocumentRepository();
  },
);

final businessCardRepositoryProvider = Provider<BusinessCardRepository>((ref) {
  return BusinessCardRepository();
});

final supportCallLogRepositoryProvider = Provider<SupportCallLogRepository>((
  ref,
) {
  return SupportCallLogRepository();
});

final supportUnitPriceRepositoryProvider = Provider<SupportUnitPriceRepository>(
  (ref) {
    return SupportUnitPriceRepository();
  },
);

final supportAsQuoteRepositoryProvider = Provider<SupportAsQuoteRepository>((
  ref,
) {
  return SupportAsQuoteRepository();
});

final supportAsVisitTeamRepositoryProvider =
    Provider<SupportAsVisitTeamRepository>((ref) {
      return SupportAsVisitTeamRepository();
    });

final mesRepositoryProvider = Provider<MesRepository>((ref) {
  return MesRepository(ref.watch(appDependenciesProvider));
});
