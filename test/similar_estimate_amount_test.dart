import 'package:coad_customer_calls/core/network/sales_api_transport.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/data/auth_controller.dart';
import 'package:coad_customer_calls/data/auth_repository.dart';
import 'package:coad_customer_calls/features/quoter/quoter_providers.dart';
import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
import 'package:coad_customer_calls/features/quoter/similar_estimates_notifier.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:coad_customer_calls/models/similar_shutter_model.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('철제방화 이전 견적 금액은 잘리지 않고 전부 보인다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final deps = AppDependencies(
      prefs: prefs,
      secure: const FlutterSecureStorage(),
      transport: SalesApiTransport(),
    );

    const amount = 147890000.0;
    final formatted = NumberFormat.currency(
      locale: 'ko_KR',
      symbol: '₩',
      decimalDigits: 0,
    ).format(amount);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDependenciesProvider.overrideWithValue(deps),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              AuthRepository(ref.read(appDependenciesProvider)),
            ),
          ),
          shutterPricesFutureProvider.overrideWith(
            (ref) async => {
              'grid': <Map<String, dynamic>>[],
              'unit': <Map<String, dynamic>>[],
              'company': <Map<String, dynamic>>[],
            },
          ),
          similarEstimatesProvider.overrideWith((ref, input) async {
            return [
              ScoredEstimate(
                estimate: const SimilarShutterEstimate(
                  id: 'past-1',
                  width: 2500,
                  height: 3500,
                  modelId: 'fire',
                  modelName: '철제방화',
                  amount: amount,
                  hasMotor: false,
                ),
                score: 2400,
              ),
            ];
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QuoterScreen(
              showQuickActions: false,
              initialType: ShutterType.fireSteel,
              initialWidthMm: 2500,
              initialHeightMm: 3500,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(formatted), findsOneWidget);
    final text = tester.widget<Text>(find.text(formatted));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(text.softWrap, isFalse);

    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(formatted),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      paragraph.size.width,
      greaterThan(paragraph.getMaxIntrinsicWidth(double.infinity) - 1),
    );
  });
}
