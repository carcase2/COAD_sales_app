import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _rememberId = true;
  bool _autoLogin = false;
  bool _autoLoginTried = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _restoreLoginOptions();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreLoginOptions() async {
    final secure = ref.read(appDependenciesProvider).secure;
    final remember = await secure.read(key: StorageKeys.rememberLoginId);
    final auto = await secure.read(key: StorageKeys.autoLoginEnabled);
    final savedId = await secure.read(key: StorageKeys.savedLoginId);
    final savedPw = await secure.read(key: StorageKeys.savedLoginPassword);

    if (!mounted) return;
    setState(() {
      _rememberId = remember != 'false';
      _autoLogin = auto == 'true';
      _idCtrl.text = savedId ?? '';
      if (_autoLogin) {
        _pwCtrl.text = savedPw ?? '';
      }
    });

    if (_autoLogin && !_autoLoginTried && _idCtrl.text.trim().isNotEmpty && _pwCtrl.text.isNotEmpty) {
      _autoLoginTried = true;
      await _submit();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final secure = ref.read(appDependenciesProvider).secure;
      await ref.read(authControllerProvider.notifier).login(
            id: _idCtrl.text.trim(),
            password: _pwCtrl.text,
          );
      await secure.write(key: StorageKeys.rememberLoginId, value: _rememberId.toString());
      await secure.write(key: StorageKeys.autoLoginEnabled, value: _autoLogin.toString());
      if (_rememberId) {
        await secure.write(key: StorageKeys.savedLoginId, value: _idCtrl.text.trim());
      } else {
        await secure.delete(key: StorageKeys.savedLoginId);
      }
      if (_autoLogin) {
        await secure.write(key: StorageKeys.savedLoginPassword, value: _pwCtrl.text);
      } else {
        await secure.delete(key: StorageKeys.savedLoginPassword);
      }
    } catch (e) {
      setState(() => _error = koreanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topPad = MediaQuery.paddingOf(context).top;
    final showAutoLoginOverlay = _loading && _autoLoginTried;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    Container(
                      height: 240 + topPad,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.primary,
                            Color.lerp(scheme.primary, scheme.primaryContainer, 0.35)!,
                          ],
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(24, topPad + 28, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.onPrimary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.phone_in_talk_rounded, color: scheme.onPrimary, size: 28),
                              ),
                              const Spacer(),
                              Text(
                                'v$kAppVersion',
                                style: TextStyle(
                                  color: scheme.onPrimary.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'COAD 영업',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '고객전화 · 견적 업무를 한곳에서',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onPrimary.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 168 + topPad),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Card(
                          elevation: 4,
                          shadowColor: scheme.shadow.withValues(alpha: 0.2),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '로그인',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '인트라넷 계정으로 접속합니다.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _idCtrl,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.none,
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                    labelText: '사번 / 아이디',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8), width: 1.2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: scheme.primary, width: 1.8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _pwCtrl,
                                  obscureText: _obscurePassword,
                                  onSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: '비밀번호',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8), width: 1.2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: scheme.primary, width: 1.8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: const Text('아이디 저장', style: TextStyle(fontSize: 14)),
                                  value: _rememberId,
                                  onChanged: (v) async {
                                    final next = v ?? false;
                                    setState(() => _rememberId = next);
                                    if (!next) {
                                      final secure = ref.read(appDependenciesProvider).secure;
                                      await secure.delete(key: StorageKeys.savedLoginId);
                                    }
                                  },
                                ),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: const Text('자동 로그인', style: TextStyle(fontSize: 14)),
                                  value: _autoLogin,
                                  onChanged: (v) async {
                                    final next = v ?? false;
                                    setState(() => _autoLogin = next);
                                    if (!next) {
                                      final secure = ref.read(appDependenciesProvider).secure;
                                      await secure.delete(key: StorageKeys.savedLoginPassword);
                                    }
                                  },
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: scheme.errorContainer.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.error_outline, size: 20, color: scheme.error),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(color: scheme.onErrorContainer, fontSize: 13, height: 1.35),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: _loading
                                      ? SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: scheme.onPrimary,
                                          ),
                                        )
                                      : const Text('로그인'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 320 + topPad),
                  ],
                ),
              ),
            ],
          ),
          if (showAutoLoginOverlay)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.25),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 14),
                          Text(
                            '자동 로그인 중…',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
