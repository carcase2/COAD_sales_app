import 'package:coad_customer_calls/features/general_schedule/general_schedule_calendar_ui.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_stats.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_week_grid.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  testWidgets('주간 그리드 — 일~토 헤더와 현장명', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const cell = GeneralScheduleCell(
      scheduleId: 'nexen',
      site: '넥센타이',
      start: '2026-07-28',
      endDate: '2026-08-01',
      userColor: '#F59E0B',
    );
    final grid = <String, List<GeneralScheduleCell?>>{
      '2026-07-28': List<GeneralScheduleCell?>.filled(8, null)..[1] = cell,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const GeneralScheduleRangeHeader(
                title: '7월 26일 - 8월 1일',
                onPrevious: _noop,
                onNext: _noop,
              ),
              GeneralScheduleColorModeToggle(
                mode: GeneralScheduleColorMode.assignee,
                onChanged: (_) {},
              ),
              Expanded(
                child: GeneralScheduleWeekGrid(
                  selectedYmd: '2026-07-28',
                  grid: grid,
                  colorMode: GeneralScheduleColorMode.assignee,
                  onDaySelected: (_) {},
                  onSlotTap: (_, _, _) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7월 26일 - 8월 1일'), findsOneWidget);
    expect(find.text('일'), findsOneWidget);
    expect(find.text('월'), findsOneWidget);
    expect(find.text('토'), findsOneWidget);
    expect(find.text('담당자별'), findsOneWidget);
    expect(find.text('도어타입별'), findsOneWidget);
    expect(find.text('넥센타이'), findsOneWidget);
  });
}

void _noop() {}
