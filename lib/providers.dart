import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/data/auth_repository.dart';
import 'package:coad_customer_calls/data/sales_calls_repository.dart';
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
