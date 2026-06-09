import 'dart:convert';

import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:flutter/material.dart';

void showIssuanceRequestDetail(BuildContext context, IssuanceRequestRow row) {
  String statusLabel(String raw) {
    if (row.kind == IssuanceRowKind.cancelled) return '취소';
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
      case 'cancelled':
      case 'canceled':
      case 'cancel':
        return '취소';
      default:
        return raw.trim().isEmpty ? '-' : raw;
    }
  }

  final scheme = Theme.of(context).colorScheme;
  final isTax = row.domain == IssuanceDomain.taxInvoice;
  final master = row.master;
  final issue = row.issue;
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

  String attachmentSummary(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final trimmed = raw.trim();
    if (trimmed.startsWith('[')) {
      try {
        final list = jsonDecode(trimmed);
        if (list is List && list.isNotEmpty) return '${list.length}개 파일';
      } catch (_) {}
    }
    if (trimmed.startsWith('{')) return '첨부 있음';
    if (trimmed.contains('http')) return '첨부 있음';
    return trimmed;
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
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '-';
    final asInt = int.tryParse(trimmed);
    if (asInt != null && asInt > 0) return '$asInt달';
    final years = double.tryParse(trimmed);
    if (years == null || years <= 0) return trimmed;
    if (years < 1) {
      final legacyMonths = (years * 12).round();
      if (legacyMonths > 0) return '$legacyMonths달';
    }
    return '${(years * 12).round()}달';
  }

  String formatDateTime(String raw) {
    if (raw == '-') return raw;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  final isUrgent = isTax && (issue?['is_urgent'] ?? false) == true;

  final details = <Widget>[
    kv('요청 구분', isTax ? '세금계산서' : '이행증권'),
    kv('상태', statusLabel(textOf('status'))),
    if (isUrgent) kv('긴급', '예'),
    kv('요청일', row.createdAtText),
    kv('요청자', textOf('requester')),
    if (isTax) ...[
      kv('계산서번호', textOf('invoice_number')),
      kv('고객명', textOf('customer_name')),
      kv('종사업자번호', textOf('customer_registration_number')),
      kv('항목 구분', textOf('item_type')),
      kv('품목명', textOf('item_name')),
      kv('총액', formatWon(textOf('total_amount'))),
      kv('발행 퍼센트', '${textOf('percentage')}%'),
      if (row.isPartial) kv('남은 발급', '${row.remainingPct.round()}%'),
      kv('지사', textOf('branch')),
      kv('이메일', textOf('email')),
      kv('MES 등록', master['mes_registered'] == true ? '예' : '아니오'),
      kv(
        '사업자등록증',
        attachmentSummary(textOf('business_registration_image_url')),
      ),
    ] else ...[
      kv('증권번호', textOf('bond_number')),
      kv('업체명', textOf('company_name')),
      kv('증권 종류', textOf('bond_type')),
      kv('계약금액', formatWon(textOf('contract_amount'))),
      kv('보증금율', '${textOf('guarantee_rate')}%'),
      kv('보증기간', formatBondPeriod(textOf('guarantee_period'))),
      kv('계약일', textOf('contract_date')),
      kv('요청기한', textOf('request_deadline')),
      kv('이메일', textOf('email')),
    ],
    if (row.kind == IssuanceRowKind.cancelled) ...[
      kv('취소 일시', formatDateTime(textOf('cancelled_at'))),
      kv('취소 담당', textOf('cancelled_by')),
      kv('취소 사유', textOf('cancel_reason')),
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
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '긴급',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
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
