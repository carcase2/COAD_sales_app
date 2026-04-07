import 'package:coad_customer_calls/models/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

class AuthController extends StateNotifier<AppUser?> {
  AuthController(this._repo) : super(_repo.user);

  final AuthRepository _repo;

  Future<void> login({required String id, required String password}) async {
    final u = await _repo.login(id: id, password: password);
    state = u;
  }

  Future<void> logout() async {
    await _repo.logout();
    state = null;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AppUser?>((ref) {
  throw UnimplementedError('authControllerProvider must be overridden in main');
});
