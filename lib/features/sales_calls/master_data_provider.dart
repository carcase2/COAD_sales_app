import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final masterDataProvider = FutureProvider<MasterDataBundle>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchMasterData();
});
