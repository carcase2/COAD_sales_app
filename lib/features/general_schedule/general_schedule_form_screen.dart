import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_providers.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_stats.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeneralScheduleFormScreen extends ConsumerStatefulWidget {
  const GeneralScheduleFormScreen({
    super.key,
    this.editing,
    this.initialStartYmd,
    this.initialSlotIndex,
  });

  final GeneralScheduleRecord? editing;
  final String? initialStartYmd;
  /// 빈 칸 탭 등록 시 고정할 slot (0~5).
  final int? initialSlotIndex;

  @override
  ConsumerState<GeneralScheduleFormScreen> createState() =>
      _GeneralScheduleFormScreenState();
}

class _GeneralScheduleFormScreenState
    extends ConsumerState<GeneralScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _siteController = TextEditingController();

  late DateTime _startDate;
  late DateTime _endDate;
  int _teamCount = 1;
  int _dayCount = 1;
  bool _saving = false;

  final Map<String, int> _doorTypeQuantities = {};
  final Set<String> _selectedDoorCodes = {};

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    final initial = widget.initialStartYmd ?? todayYmdSeoul();
    if (editing != null) {
      _siteController.text = editing.site;
      _startDate = DateTime.parse(editing.start);
      _endDate = DateTime.parse(editing.endDate);
      _teamCount = editing.teamCount.clamp(1, kGeneralScheduleSlotsPerDay);
      _dayCount = inclusiveDayCount(editing.start, editing.endDate);
      for (final code in editing.doorTypes) {
        _selectedDoorCodes.add(code);
      }
    } else {
      _startDate = DateTime.parse(initial);
      _endDate = DateTime.parse(initial);
      _dayCount = 1;
    }
    _syncDayCountFromRange();
  }

  @override
  void dispose() {
    _siteController.dispose();
    super.dispose();
  }

  void _syncDayCountFromRange() {
    _dayCount = inclusiveDayCount(_ymd(_startDate), _ymd(_endDate));
    if (_dayCount < 1) _dayCount = 1;
  }

  void _applyDayCount(int count) {
    setState(() {
      _dayCount = count;
      _endDate = _startDate.add(Duration(days: count - 1));
    });
  }

  String _ymd(DateTime d) => ymdSeoulFromDateTime(d);

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('ko', 'KR'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        _endDate = _startDate.add(Duration(days: _dayCount - 1));
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate;
        }
        _syncDayCountFromRange();
      }
    });
  }

  List<ScheduleModelEntry> _buildModels(List<DoorTypeOption> doorTypes) {
    final byCode = {for (final d in doorTypes) d.code: d};
    final models = <ScheduleModelEntry>[];
    for (final code in _selectedDoorCodes) {
      final qty = _doorTypeQuantities[code] ?? 0;
      if (qty <= 0) continue;
      final opt = byCode[code];
      models.add(
        ScheduleModelEntry(
          name: opt?.name ?? code,
          quantity: qty,
          color: opt?.color,
        ),
      );
    }
    return models;
  }

  void _restoreDoorTypeQuantitiesFromModels(
    List<DoorTypeOption> doorTypes,
    List<ScheduleModelEntry> models,
  ) {
    for (final m in models) {
      if (m.quantity <= 0) continue;
      for (final dt in doorTypes) {
        if (dt.name == m.name || dt.code == m.name) {
          _doorTypeQuantities[dt.code] = m.quantity;
          break;
        }
      }
    }
  }

  Map<String, List<int>>? _existingSlotsByDate(GeneralScheduleRecord record) {
    final map = <String, List<int>>{};
    for (final s in record.slots) {
      map.putIfAbsent(s.date, () => []).add(s.slot);
    }
    for (final entry in map.entries) {
      entry.value.sort();
    }
    return map.isEmpty ? null : map;
  }

  Future<bool> _confirmSlotRegistration({
    required String startYmd,
    required String endYmd,
    required List<ScheduleModelEntry> models,
    required List<String> doorTypeCodes,
  }) async {
    final slotIndex = widget.initialSlotIndex;
    if (slotIndex == null || widget.editing != null) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final period = _dayCount == 1
            ? formatYmdFlowLabelKo(startYmd)
            : '${formatYmdFlowLabelKo(startYmd)} ~ ${formatYmdFlowLabelKo(endYmd)}';
        final modelLines = models
            .map((m) => '${m.name} ${m.quantity}개')
            .toList(growable: false);

        return AlertDialog(
          title: const Text('입력 내용 확인'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('등록 위치: ${formatYmdFlowLabelKo(startYmd)} · ${slotIndex + 1}칸'),
                const SizedBox(height: 6),
                Text('현장명: ${_siteController.text.trim()}'),
                Text('기간: $period'),
                Text('팀 수: $_teamCount팀'),
                Text('공사 일수: $_dayCount일'),
                const SizedBox(height: 8),
                Text(
                  '도어 타입',
                  style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                if (modelLines.isNotEmpty)
                  ...modelLines.map(Text.new)
                else if (doorTypeCodes.isNotEmpty)
                  Text(doorTypeCodes.join(', '))
                else
                  const Text('선택 없음'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('수정'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authControllerProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    final startYmd = _ymd(_startDate);
    final endYmd = _ymd(_endDate);
    final doorTypes = ref.read(generalScheduleDoorTypesProvider).valueOrNull ?? [];
    final models = _buildModels(doorTypes);
    final doorTypeCodes = _selectedDoorCodes.toList();
    final confirmed = await _confirmSlotRegistration(
      startYmd: startYmd,
      endYmd: endYmd,
      models: models,
      doorTypeCodes: doorTypeCodes,
    );
    if (!confirmed || !mounted) return;

    final grid = ref.read(generalScheduleGridProvider);
    final editingId = widget.editing?.id;

    final SlotAssignmentResult assignment;
    if (_teamCount > 1) {
      assignment = assignMultiTeamSlots(
        grid: grid,
        startYmd: startYmd,
        endYmd: endYmd,
        teamCount: _teamCount,
        dayCount: _dayCount,
        editingScheduleId: editingId,
        existingSlotsByDate: widget.editing == null
            ? null
            : _existingSlotsByDate(widget.editing!),
      );
    } else if (_teamCount == 1 &&
        (widget.initialSlotIndex != null || startYmd != endYmd)) {
      if (widget.initialSlotIndex != null) {
        assignment = assignFixedSlotRow(
          grid: grid,
          startYmd: startYmd,
          endYmd: endYmd,
          slotIndex: widget.initialSlotIndex!,
          editingScheduleId: editingId,
        );
      } else {
        assignment = assignSingleTeamSlots(
          grid: grid,
          startYmd: startYmd,
          endYmd: endYmd,
          editingScheduleId: editingId,
        );
      }
    } else {
      assignment = assignSingleTeamSlots(
        grid: grid,
        startYmd: startYmd,
        endYmd: endYmd,
        editingScheduleId: editingId,
      );
    }

    if (!assignment.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(assignment.errorMessage ?? '칸 배치에 실패했습니다.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(generalScheduleRepositoryProvider);
      GeneralScheduleRecord saved;
      if (widget.editing != null) {
        await repo.update(
          id: widget.editing!.id,
          site: _siteController.text.trim(),
          startYmd: startYmd,
          endYmd: endYmd,
          userId: user.id,
          slotMap: assignment.slotMap,
          doorTypes: doorTypeCodes,
          models: models,
          extraTeamSlots: assignment.teamSlotMap.isEmpty
              ? null
              : assignment.teamSlotMap,
        );
        final all = await repo.fetchAll();
        saved = all.firstWhere((e) => e.id == widget.editing!.id);
        unawaited(
          repo.notifyTelegram(
            action: 'updated',
            scheduleData: _telegramPayload(
              record: saved,
              userName: user.name,
              models: models,
              doorTypes: doorTypeCodes,
              oldStart: widget.editing!.start,
              oldEnd: widget.editing!.endDate,
            ),
          ),
        );
      } else {
        saved = await repo.create(
          site: _siteController.text.trim(),
          startYmd: startYmd,
          endYmd: endYmd,
          userId: user.id,
          slotMap: assignment.slotMap,
          doorTypes: doorTypeCodes,
          models: models,
          extraTeamSlots: assignment.teamSlotMap.isEmpty
              ? null
              : assignment.teamSlotMap,
        );
        unawaited(
          repo.notifyTelegram(
            action: 'created',
            scheduleData: _telegramPayload(
              record: saved,
              userName: user.name,
              models: models,
              doorTypes: doorTypeCodes,
            ),
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _telegramPayload({
    required GeneralScheduleRecord record,
    required String userName,
    required List<ScheduleModelEntry> models,
    required List<String> doorTypes,
    String? oldStart,
    String? oldEnd,
  }) {
    return {
      'site': record.site,
      'start_date': record.start,
      'end_date': record.endDate,
      'models': models
          .map((m) => {'name': m.name, 'quantity': m.quantity})
          .toList(),
      'door_types': doorTypes,
      'user_name': userName,
      'sourceTab': 'general_schedule',
      ..._optionalPayloadField('old_start_date', oldStart),
      ..._optionalPayloadField('old_end_date', oldEnd),
    };
  }

  Map<String, dynamic> _optionalPayloadField(String key, String? value) =>
      value == null ? const <String, dynamic>{} : <String, dynamic>{key: value};

  String get _saveLabel {
    if (widget.editing != null) return '수정 저장';
    if (widget.initialSlotIndex != null) return '그날 일정 추가';
    return '등록';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editing != null;
    final slotIndex = widget.initialSlotIndex;
    final doorTypesAsync = ref.watch(generalScheduleDoorTypesProvider);
    ref.listen<AsyncValue<List<DoorTypeOption>>>(
      generalScheduleDoorTypesProvider,
      (previous, next) {
        next.whenData((doorTypes) {
          final editing = widget.editing;
          if (!mounted || editing == null || editing.models.isEmpty) return;
          if (_doorTypeQuantities.isNotEmpty) return;
          _restoreDoorTypeQuantitiesFromModels(doorTypes, editing.models);
          setState(() {});
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? '일정 수정'
              : slotIndex != null
                  ? '일정 등록 · ${slotIndex + 1}칸'
                  : '일정 등록',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => unawaited(_save()),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_saveLabel),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
            if (widget.initialSlotIndex != null && widget.editing == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      '${formatYmdFlowLabelKo(widget.initialStartYmd ?? _ymd(_startDate))} · '
                      '${widget.initialSlotIndex! + 1}칸\n'
                      '기간·도어·수량을 입력한 뒤 등록하세요. (기간 변경 시 같은 칸 유지)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            TextFormField(
              controller: _siteController,
              decoration: const InputDecoration(
                labelText: '현장명',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '현장명을 입력하세요.' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => unawaited(_pickDate(isStart: true)),
                    child: Text('시작: ${_ymd(_startDate)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => unawaited(_pickDate(isStart: false)),
                    child: Text('종료: ${_ymd(_endDate)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('공사 일수', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [1, 2, 3, 5, 7].map((d) {
                final selected = _dayCount == d;
                return ChoiceChip(
                  label: Text('$d일'),
                  selected: selected,
                  onSelected: (_) => _applyDayCount(d),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              _dayCount == 1
                  ? '종료일: ${formatYmdFlowLabelKo(_ymd(_endDate))}'
                  : '기간: ${formatYmdFlowLabelKo(_ymd(_startDate))} ~ '
                      '${formatYmdFlowLabelKo(_ymd(_endDate))} ($_dayCount일)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text('팀 수', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(kGeneralScheduleSlotsPerDay, (i) {
                  final team = i + 1;
                  final selected = _teamCount == team;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i == kGeneralScheduleSlotsPerDay - 1 ? 0 : 8,
                    ),
                    child: ChoiceChip(
                      label: Text('$team팀'),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _teamCount = team);
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '도어 타입',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '타입을 선택한 뒤 수량을 입력하세요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            doorTypesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(koreanErrorMessage(e)),
              data: (options) {
                if (options.isEmpty) {
                  return const Text('등록된 도어 타입이 없습니다.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final opt in options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DoorTypeChip(
                          label: opt.name,
                          code: opt.code,
                          color: opt.color,
                          selected: _selectedDoorCodes.contains(opt.code),
                          quantity: _doorTypeQuantities[opt.code] ?? 1,
                          onSelected: (on) {
                            setState(() {
                              if (on) {
                                _selectedDoorCodes.add(opt.code);
                                _doorTypeQuantities.putIfAbsent(opt.code, () => 1);
                              } else {
                                _selectedDoorCodes.remove(opt.code);
                                _doorTypeQuantities.remove(opt.code);
                              }
                            });
                          },
                          onQuantityChanged: _selectedDoorCodes.contains(opt.code)
                              ? (qty) {
                                  setState(() {
                                    _doorTypeQuantities[opt.code] = qty;
                                  });
                                }
                              : null,
                        ),
                      ),
                  ],
                );
              },
            ),
                ],
              ),
            ),
            Material(
              elevation: 6,
              shadowColor: Theme.of(context).colorScheme.shadow,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => unawaited(_save()),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            widget.editing != null
                                ? Icons.save_rounded
                                : Icons.add_circle_rounded,
                            size: 22,
                          ),
                    label: Text(_saving ? '저장 중…' : _saveLabel),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoorTypeChip extends StatelessWidget {
  const _DoorTypeChip({
    required this.label,
    required this.code,
    required this.selected,
    required this.onSelected,
    required this.quantity,
    this.color,
    this.onQuantityChanged,
  });

  final String label;
  final String code;
  final String? color;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final int quantity;
  final ValueChanged<int>? onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent =
        parseGeneralScheduleUserColor(color, fallback: scheme.primary) ??
            scheme.primary;
    final qty = quantity.clamp(0, 9999);

    return Material(
      color: selected
          ? accent.withValues(alpha: 0.14)
          : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? accent : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onSelected(!selected),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 18,
                            color: selected ? accent : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          if (color != null && color!.isNotEmpty)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (color != null && color!.isNotEmpty)
                            const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: selected ? accent : scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (selected && onQuantityChanged != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QtyIconButton(
                        icon: Icons.remove_rounded,
                        enabled: qty > 0,
                        accent: accent,
                        onPressed: () =>
                            onQuantityChanged!((qty - 1).clamp(0, 9999)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '$qty',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                        ),
                      ),
                      _QtyIconButton(
                        icon: Icons.add_rounded,
                        enabled: true,
                        accent: accent,
                        onPressed: () =>
                            onQuantityChanged!((qty + 1).clamp(0, 9999)),
                      ),
                      Text(
                        '개',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyIconButton extends StatelessWidget {
  const _QtyIconButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
    required this.accent,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? accent.withValues(alpha: 0.12) : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: enabled
              ? accent.withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? accent : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}