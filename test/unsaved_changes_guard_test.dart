import 'package:coad_customer_calls/core/widgets/unsaved_changes_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openPage(WidgetTester tester, bool Function() dirty) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UnsavedChangesGuard(
                    hasChanges: dirty,
                    child: Scaffold(
                      appBar: AppBar(title: const Text('편집')),
                    ),
                  ),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('바뀐 내용이 없으면 바로 나간다', (tester) async {
    await openPage(tester, () => false);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('편집'), findsNothing);
  });

  testWidgets('바뀐 내용이 있으면 묻고, 계속 작성하면 남는다', (tester) async {
    await openPage(tester, () => true);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('작성 취소'), findsOneWidget);
    await tester.tap(find.text('계속 작성'));
    await tester.pumpAndSettle();
    expect(find.text('편집'), findsOneWidget);
  });

  testWidgets('나가기를 누르면 닫힌다', (tester) async {
    await openPage(tester, () => true);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('편집'), findsNothing);
  });
}
