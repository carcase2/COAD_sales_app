import 'package:coad_customer_calls/features/quoter/shutter_quick_estimate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// 셔터 견적의 모터·시공·장비·절곡·이윤을 고친다. 취소하면 null.
Future<ShutterQuickCosts?> showShutterCostSheet(
  BuildContext context, {
  required ShutterQuickCosts costs,
}) {
  return showModalBottomSheet<ShutterQuickCosts>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ShutterCostSheet(initial: costs),
  );
}

class _ShutterCostSheet extends StatefulWidget {
  const _ShutterCostSheet({required this.initial});

  final ShutterQuickCosts initial;

  @override
  State<_ShutterCostSheet> createState() => _ShutterCostSheetState();
}

class _ShutterCostSheetState extends State<_ShutterCostSheet> {
  final _fmt = NumberFormat('#,###');
  late final _motor = _ctrl(widget.initial.motor);
  late final _install = _ctrl(widget.initial.install);
  late final _equip = _ctrl(widget.initial.equip);
  late final _bending = _ctrl(widget.initial.bending);
  late final _profit = _ctrl(widget.initial.profit);

  TextEditingController _ctrl(int v) =>
      TextEditingController(text: _fmt.format(v));

  @override
  void dispose() {
    for (final c in [_motor, _install, _equip, _bending, _profit]) {
      c.dispose();
    }
    super.dispose();
  }

  int _read(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  void _fill(ShutterQuickCosts c) {
    _motor.text = _fmt.format(c.motor);
    _install.text = _fmt.format(c.install);
    _equip.text = _fmt.format(c.equip);
    _bending.text = _fmt.format(c.bending);
    _profit.text = _fmt.format(c.profit);
    setState(() {});
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.end,
        decoration: InputDecoration(
          labelText: label,
          suffixText: '원',
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onTap: () => c.selection = TextSelection(
          baseOffset: 0,
          extentOffset: c.text.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '셔터 비용 조정',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _fill(const ShutterQuickCosts()),
                    child: const Text('기본값'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _field('모터', _motor),
              _field('시공비', _install),
              _field('장비', _equip),
              _field('절곡', _bending),
              _field('이윤', _profit),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  ShutterQuickCosts(
                    motor: _read(_motor),
                    install: _read(_install),
                    equip: _read(_equip),
                    bending: _read(_bending),
                    profit: _read(_profit),
                  ),
                ),
                child: const Text('적용'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
