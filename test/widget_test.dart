import 'package:coad_customer_calls/features/quoter/quoter_type_style.dart';
import 'package:coad_customer_calls/features/quoter/widgets/quoter_out_of_table_warning.dart';
import 'package:coad_customer_calls/features/quoter/widgets/quoter_type_selector.dart';
import 'package:coad_customer_calls/features/quoter/widgets/quoter_wizard_header.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('QuoterOutOfTableWarning 안내 문구', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: QuoterOutOfTableWarning()),
      ),
    );
    expect(find.textContaining('테이블 사이즈'), findsOneWidget);
  });

  testWidgets('QuoterWizardHeader 단계 탭', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoterWizardHeader(
            currentStep: 2,
            hasResult: false,
            onStepTap: (step) => tapped = step,
          ),
        ),
      ),
    );
    expect(find.text('종류'), findsOneWidget);
    expect(find.text('규격'), findsOneWidget);
    await tester.tap(find.text('비용'));
    await tester.pump();
    expect(tapped, 3);
  });

  testWidgets('QuoterTypeSelector 종류 선택', (tester) async {
    ShutterType? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuoterTypeSelector(
              selectedType: ShutterType.doubleExtrusion,
              onSelected: (t) => selected = t,
            ),
          ),
        ),
      ),
    );
    expect(find.text(QuoterTypeStyle.label(ShutterType.windproof)), findsOneWidget);
    await tester.tap(find.text(QuoterTypeStyle.label(ShutterType.windproof)));
    await tester.pump();
    expect(selected, ShutterType.windproof);
  });
}
