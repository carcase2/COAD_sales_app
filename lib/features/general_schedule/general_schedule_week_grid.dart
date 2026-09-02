import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_calendar_ui.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_stats.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 인트라넷 Calendar.tsx 주간 달력 — 일~토 7열 × 8칸.
class GeneralScheduleWeekGrid extends StatefulWidget {
  const GeneralScheduleWeekGrid({
    super.key,
    required this.selectedYmd,
    required this.grid,
    required this.colorMode,
    required this.onDaySelected,
    required this.onSlotTap,
    this.assigneeFilter = kGeneralScheduleAllAssignees,
    this.searchQuery = '',
    this.onRefresh,
  });

  static const weekPageCount = 105;
  static const centerIndex = 52;

  final String selectedYmd;
  final GeneralScheduleDayGrid grid;
  final GeneralScheduleColorMode colorMode;
  final String assigneeFilter;
  final String searchQuery;
  final ValueChanged<String> onDaySelected;
  final void Function(int slotIndex, String ymd, GeneralScheduleCell? cell)
      onSlotTap;
  final Future<void> Function()? onRefresh;

  @override
  State<GeneralScheduleWeekGrid> createState() =>
      GeneralScheduleWeekGridState();
}

class GeneralScheduleWeekGridState extends State<GeneralScheduleWeekGrid> {
  late final PageController _controller;
  bool _programmaticPage = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: GeneralScheduleWeekGrid.centerIndex);
  }

  @override
  void didUpdateWidget(covariant GeneralScheduleWeekGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedYmd != widget.selectedYmd) {
      final oldSunday = seoulSundayWeekRangeContaining(oldWidget.selectedYmd).$1;
      final newSunday = seoulSundayWeekRangeContaining(widget.selectedYmd).$1;
      if (oldSunday != newSunday) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCenter());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpToCenter() {
    if (!_controller.hasClients) return;
    _programmaticPage = true;
    _controller.jumpToPage(GeneralScheduleWeekGrid.centerIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _programmaticPage = false;
    });
  }

  void jumpToSelectedWeek() => _jumpToCenter();

  List<String> _weekSundays() {
    final sunday = seoulSundayWeekRangeContaining(widget.selectedYmd).$1;
    return List.generate(
      GeneralScheduleWeekGrid.weekPageCount,
      (i) => addDaysToYmd(
        sunday,
        (i - GeneralScheduleWeekGrid.centerIndex) * 7,
      ),
    );
  }

  int _weekdayOffset(String ymd) {
    final sunday = seoulSundayWeekRangeContaining(ymd).$1;
    final partsY = ymd.split('-');
    final partsS = sunday.split('-');
    if (partsY.length != 3 || partsS.length != 3) return 0;
    final a = DateTime(
      int.parse(partsY[0]),
      int.parse(partsY[1]),
      int.parse(partsY[2]),
    );
    final b = DateTime(
      int.parse(partsS[0]),
      int.parse(partsS[1]),
      int.parse(partsS[2]),
    );
    return a.difference(b).inDays.clamp(0, 6);
  }

  void _onPageChanged(int index) {
    if (_programmaticPage) return;
    if (index < 0 || index >= GeneralScheduleWeekGrid.weekPageCount) return;
    final sundays = _weekSundays();
    if (index >= sundays.length) return;
    final target = addDaysToYmd(sundays[index], _weekdayOffset(widget.selectedYmd));
    if (target == widget.selectedYmd) return;
    HapticFeedback.selectionClick();
    widget.onDaySelected(target);
  }

  @override
  Widget build(BuildContext context) {
    final sundays = _weekSundays();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _WeekdayHeaderRow(),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            itemCount: sundays.length,
            itemBuilder: (context, index) {
              final days = List.generate(7, (i) => addDaysToYmd(sundays[index], i));
              final table = _WeekTable(
                days: days,
                selectedYmd: widget.selectedYmd,
                grid: widget.grid,
                colorMode: widget.colorMode,
                assigneeFilter: widget.assigneeFilter,
                searchQuery: widget.searchQuery,
                onDaySelected: widget.onDaySelected,
                onSlotTap: widget.onSlotTap,
              );
              if (widget.onRefresh == null) return table;
              return RefreshIndicator(
                onRefresh: widget.onRefresh!,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: table,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeekdayStyle {
  const _WeekdayStyle({
    required this.headerTop,
    required this.headerBottom,
    required this.headerFg,
    required this.headerBorder,
    required this.columnBg,
    required this.dateFg,
  });

  final Color headerTop;
  final Color headerBottom;
  final Color headerFg;
  final Color headerBorder;
  final Color columnBg;
  final Color dateFg;
}

/// 일~토. COAD_home Calendar.tsx thead 색.
const List<_WeekdayStyle> _kIntranetWeekdayStyles = [
  _WeekdayStyle(
    headerTop: Color(0xFFFCE7F3),
    headerBottom: Color(0xFFFBCFE8),
    headerFg: Color(0xFFEF4444),
    headerBorder: Color(0xFFF9A8D4),
    columnBg: Color(0xFFFDF2F8),
    dateFg: Color(0xFFEF4444),
  ),
  _WeekdayStyle(
    headerTop: Color(0xFFDBEAFE),
    headerBottom: Color(0xFFBFDBFE),
    headerFg: Color(0xFF1D4ED8),
    headerBorder: Color(0xFFBFDBFE),
    columnBg: Color(0xFFEFF6FF),
    dateFg: Color(0xFF1D4ED8),
  ),
  _WeekdayStyle(
    headerTop: Color(0xFFEFF6FF),
    headerBottom: Color(0xFFDBEAFE),
    headerFg: Color(0xFF1D4ED8),
    headerBorder: Color(0xFFDBEAFE),
    columnBg: Color(0xFFDBEAFE),
    dateFg: Color(0xFF1D4ED8),
  ),
  _WeekdayStyle(
    headerTop: Color(0xFFF0FDF4),
    headerBottom: Color(0xFFDCFCE7),
    headerFg: Color(0xFF15803D),
    headerBorder: Color(0xFFDCFCE7),
    columnBg: Color(0xFFF0FDF4),
    dateFg: Color(0xFF15803D),
  ),
  _WeekdayStyle(
    headerTop: Color(0xFFFEFCE8),
    headerBottom: Color(0xFFFEF9C3),
    headerFg: Color(0xFFA16207),
    headerBorder: Color(0xFFFEF9C3),
    columnBg: Color(0xFFFEFCE8),
    dateFg: Color(0xFFA16207),
  ),
  _WeekdayStyle(
    headerTop: Color(0xFFF9FAFB),
    headerBottom: Color(0xFFF3F4F6),
    headerFg: Color(0xFF374151),
    headerBorder: Color(0xFFF3F4F6),
    columnBg: Color(0xFFF9FAFB),
    dateFg: Color(0xFF374151),
  ),
  _WeekdayStyle(
    headerTop: Color(0xFFDBEAFE),
    headerBottom: Color(0xFFBFDBFE),
    headerFg: Color(0xFF2563EB),
    headerBorder: Color(0xFF93C5FD),
    columnBg: Color(0xFFEFF6FF),
    dateFg: Color(0xFF2563EB),
  ),
];

const _kWeekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

class _WeekdayHeaderRow extends StatelessWidget {
  const _WeekdayHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _kIntranetWeekdayStyles[i].headerTop,
                      _kIntranetWeekdayStyles[i].headerBottom,
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(i == 0 || i == 6 ? 10 : 0),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: _kIntranetWeekdayStyles[i].headerBorder,
                      width: 3,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    _kWeekdayLabels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _kIntranetWeekdayStyles[i].headerFg,
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

class _WeekTable extends StatelessWidget {
  const _WeekTable({
    required this.days,
    required this.selectedYmd,
    required this.grid,
    required this.colorMode,
    required this.assigneeFilter,
    required this.searchQuery,
    required this.onDaySelected,
    required this.onSlotTap,
  });

  final List<String> days;
  final String selectedYmd;
  final GeneralScheduleDayGrid grid;
  final GeneralScheduleColorMode colorMode;
  final String assigneeFilter;
  final String searchQuery;
  final ValueChanged<String> onDaySelected;
  final void Function(int slotIndex, String ymd, GeneralScheduleCell? cell)
      onSlotTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF9CA3AF), width: 1.2),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _kIntranetWeekdayStyles[i].columnBg,
                      border: Border(
                        right: i < 6
                            ? const BorderSide(
                                color: Color(0xFF9CA3AF),
                                width: 1.1,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: _WeekDayColumn(
                      ymd: days[i],
                      style: _kIntranetWeekdayStyles[i],
                      selected: days[i] == selectedYmd,
                      grid: grid,
                      colorMode: colorMode,
                      assigneeFilter: assigneeFilter,
                      searchQuery: searchQuery,
                      onDaySelected: onDaySelected,
                      onSlotTap: onSlotTap,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({
    required this.ymd,
    required this.style,
    required this.selected,
    required this.grid,
    required this.colorMode,
    required this.assigneeFilter,
    required this.searchQuery,
    required this.onDaySelected,
    required this.onSlotTap,
  });

  final String ymd;
  final _WeekdayStyle style;
  final bool selected;
  final GeneralScheduleDayGrid grid;
  final GeneralScheduleColorMode colorMode;
  final String assigneeFilter;
  final String searchQuery;
  final ValueChanged<String> onDaySelected;
  final void Function(int slotIndex, String ymd, GeneralScheduleCell? cell)
      onSlotTap;

  @override
  Widget build(BuildContext context) {
    final slots = filterDaySlotsForAssignee(
      normalizeGeneralScheduleDaySlots(grid[ymd]),
      assigneeFilter,
    );
    final isToday = ymd == todayYmdSeoul();
    final isFull = slots.every((c) => c != null);
    final dayNum = int.tryParse(ymd.split('-').last) ?? 0;
    final query = searchQuery.trim().toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onDaySelected(ymd),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday
                      ? const Color(0xFF2563EB)
                      : isFull
                          ? const Color(0xFFFECACA)
                          : selected
                              ? Colors.white
                              : Colors.transparent,
                  border: Border.all(
                    color: isToday
                        ? const Color(0xFF1D4ED8)
                        : isFull
                            ? const Color(0xFFF87171)
                            : selected
                                ? const Color(0xFF93C5FD)
                                : Colors.white,
                    width: isToday || isFull || selected ? 2 : 1.5,
                  ),
                ),
                child: Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: isToday
                        ? Colors.white
                        : isFull
                            ? const Color(0xFFB91C1C)
                            : style.dateFg,
                  ),
                ),
              ),
            ),
          ),
        ),
        for (var slot = 0; slot < kGeneralScheduleSlotsPerDay; slot++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                1.5,
                slot == 0 ? 1.5 : 1,
                1.5,
                slot == kGeneralScheduleSlotsPerDay - 1 ? 1.5 : 0,
              ),
              child: _WeekSlotBar(
                cell: slots[slot],
                colorMode: colorMode,
                searchQuery: query,
                onTap: () => onSlotTap(slot, ymd, slots[slot]),
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekSlotBar extends StatelessWidget {
  const _WeekSlotBar({
    required this.cell,
    required this.colorMode,
    required this.searchQuery,
    required this.onTap,
  });

  final GeneralScheduleCell? cell;
  final GeneralScheduleColorMode colorMode;
  final String searchQuery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = cell != null;
    final mismatch = filled &&
        searchQuery.isNotEmpty &&
        !_cellMatchesQuery(cell!, searchQuery);
    final fill = filled
        ? generalScheduleBarColor(
            cell: cell!,
            mode: colorMode,
            fallback: const Color(0xFF2563EB),
          )
        : const Color(0xFFFFFFFF);
    final site = (cell?.site ?? '').trim();
    final borderColor = filled
        ? Color.lerp(fill, const Color(0xFF111827), 0.38)!
        : const Color(0xFF6B7280);
    const radius = BorderRadius.all(Radius.circular(4));

    return Material(
      color: mismatch ? fill.withValues(alpha: 0.38) : fill,
      elevation: filled ? 0.6 : 0,
      shadowColor: filled ? Colors.black26 : Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor, width: filled ? 1.3 : 1.1),
          ),
          child: filled
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Center(
                    child: Text(
                      site.isEmpty ? '—' : site,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(
                          alpha: mismatch ? 0.75 : 1,
                        ),
                        shadows: const [
                          Shadow(color: Color(0x66000000), blurRadius: 1.4),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}

bool _cellMatchesQuery(GeneralScheduleCell cell, String query) {
  if (query.isEmpty) return true;
  final haystack = [
    cell.site,
    cell.userName ?? '',
    cell.start,
    cell.endDate,
    ...cell.doorTypes,
    ...cell.models.map((m) => m.name),
  ].join(' ').toLowerCase();
  return haystack.contains(query);
}
