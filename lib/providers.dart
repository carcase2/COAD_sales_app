import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/data/auth_repository.dart';
import 'package:coad_customer_calls/data/b2_upload_repository.dart';
import 'package:coad_customer_calls/data/estimate_document_repository.dart';
import 'package:coad_customer_calls/data/general_schedule_repository.dart';
import 'package:coad_customer_calls/data/sales_calls_repository.dart';
import 'package:coad_customer_calls/data/usage_repository.dart';
import 'package:coad_customer_calls/data/ai_extractor_service.dart';
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
