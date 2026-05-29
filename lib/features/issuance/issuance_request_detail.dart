import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:flutter/material.dart';

void showIssuanceRequestDetail(BuildContext context, IssuanceRequestRow row) {
  String statusLabel(String raw) {
    if (row.isPartial) return '부분발급';
    if (row.isCompleted) return '완료';
    switch (raw.trim().toLowerCase()) {
      case 'pending':
        return '대기';
      case 'draft':
        return '임시저장';
      case 'in_progress':
      case 'inprogress':
        return '진행중';
      case 'completed':
      case 'complete':
        return '완료';
      default:
        return raw.trim().isEmpty ? '-' : raw;
    }
  }

  final scheme = Theme.of(context).colorScheme;
  final isTax = row.domain == IssuanceDomain.taxInvoice;
  final master = row.master;
  final accent = isTax ? Colors.indigo.shade600 : Colors.deepOrange.shade700;

  String textOf(String key, {Map<String, dynamic>? from}) {
    final source = from ?? master;
    final value = (source[key] ?? '').toString().trim();
    return value.isEmpty ? '-' : value;
  }

  String formatWon(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty || normalized == '-') return '-';
    final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    if (digitsOnly.isEmpty) return '-';
    final parsed = num.tryParse(digitsOnly);
    if (parsed == null) return raw.isEmpty ? '-' : raw;
    final amount = parsed.round();
    final s = amount.toString();
    final chars = <String>[];
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      chars.add(s[i]);
      if (idx > 1 && idx % 3 == 1) chars.add(',');
    }
    return '${chars.join()}원';
  }

  Widget kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String formatBondPeriod(String raw) {
    final v = double.tryParse(raw.trim());
    if (v == null || v <= 0) return raw;
    final months = v * 12.0;
    final roundedMonths = months.roundToDouble();
    if ((months - roundedMonths).abs() < 0.001) {
      return '${roundedMonths.toInt()}달';
    }
    return '${months.toStringAsFixed(1)}달';
  }

  final details = <Widget>[
    kv('요청 구분', isTax ? '세금계산서' : '이행증권'),
    kv('상태', statusLabel(textOf('status'))),
    kv('요청일', row.createdAtText),
    kv('요청자', textOf('requester')),
    if (isTax) ...[
      kv('고객명', textOf('customer_name')),
      kv('품목명', textOf('item_name')),
      kv('총액', formatWon(textOf('total_amount'))),
      kv('발행 퍼센트', '${textOf('percentage')}%'),
      if (row.isPartial) kv('남은 발급', '${row.remainingPct.round()}%'),
      kv('지사', textOf('branch')),
    ] else ...[
      kv('업체명', textOf('company_name')),
      kv('증권 종류', textOf('bond_type')),
      kv('계약금액', formatWon(textOf('contract_amount'))),
      kv('보증금율', '${textOf('guarantee_rate')}%'),
      kv('보증기간', formatBondPeriod(textOf('guarantee_period'))),
    ],
  ];

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isTax ? Icons.receipt_long_rounded : Icons.gavel_rounded,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.32,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(children: details),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
