import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('구독이 끊겨도 보존 시간 동안은 다시 조회하지 않는다', () async {
    var fetches = 0;
    final provider = FutureProvider.autoDispose<int>((ref) async {
      cacheProviderFor(ref, const Duration(milliseconds: 200));
      return ++fetches;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var sub = container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), 1);
    sub.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    sub = container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), 1);
    sub.close();

    await Future<void>.delayed(const Duration(milliseconds: 300));
    sub = container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), 2);
    sub.close();
  });

  test('무효화하면 보존 중이어도 다시 조회한다', () async {
    var fetches = 0;
    final provider = FutureProvider.autoDispose<int>((ref) async {
      cacheProviderFor(ref, const Duration(minutes: 3));
      return ++fetches;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub = container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), 1);
    container.invalidate(provider);
    expect(await container.read(provider.future), 2);
    sub.close();
  });
}
