import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:flutter/material.dart';

class IssuanceRequestCard extends StatelessWidget {
  const IssuanceRequestCard({
    required this.row,
    required this.onTap,
    this.isOwn = false,
    super.key,
  });

  final IssuanceRequestRow row;
  final VoidCallback onTap;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String textOf(String key) => (row.master[key] ?? '').toString().trim();

    String statusLabel(String raw, {required bool isCompleted}) {
      if (isCompleted) return '완료';
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
          return raw.trim().isEmpty ? '-' : raw.trim();
      }
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

    final isTax = row.domain == IssuanceDomain.taxInvoice;
    final accent = isTax ? Colors.indigo.shade600 : Colors.deepOrange.shade700;
    final bg = isTax
        ? Colors.indigo.withValues(alpha: 0.05)
        : Colors.deepOrange.withValues(alpha: 0.06);

    String compactTitle(String raw) {
      var t = raw.trim();
      if (t.endsWith(' 발급요청')) {
        t = t.substring(0, t.length - ' 발급요청'.length).trim();
      } else if (t.endsWith(' 요청')) {
        t = t.substring(0, t.length - ' 요청'.length).trim();
      }
      return t.isEmpty ? raw.trim() : t;
    }

    final title = isTax
        ? (textOf('customer_name').isEmpty
              ? row.title
              : textOf('customer_name'))
        : (textOf('company_name').isEmpty ? row.title : textOf('company_name'));
    final displayTitle = compactTitle(title);
    final assignee = (textOf('requester').isEmpty
        ? textOf('created_by')
        : textOf('requester'));
    final status = row.kind == IssuanceRowKind.cancelled
        ? '취소'
        : row.isPartial
        ? '부분발급'
        : statusLabel(textOf('status'), isCompleted: row.isCompleted);
    final extra = isTax
        ? '품목: ${textOf('item_name').isEmpty ? '-' : textOf('item_name')} · 총액: ${formatWon(textOf('total_amount'))}'
        : '종류: ${textOf('bond_type').isEmpty ? '-' : textOf('bond_type')} · 계약금액: ${formatWon(textOf('contract_amount'))}';
    final partialExtra = row.isPartial && isTax
        ? ' · ${row.remainingPct.round()}% 남음'
        : '';
    final requestStepText = row.isPartial
        ? '부분 발급'
        : row.isCompleted
        ? '발급 완료'
        : (row.issue == null ? '요청 접수' : '요청 진행');
    final isUrgent = isTax && (row.issue?['is_urgent'] ?? false) == true;

    Color statusColor(String label) {
      switch (label) {
        case '부분발급':
          return Colors.orange.shade800;
        case '완료':
          return Colors.teal.shade700;
        case '취소':
          return Colors.grey.shade700;
        case '진행중':
          return Colors.blue.shade700;
        case '임시저장':
          return Colors.blueGrey.shade600;
        case '대기':
        default:
          return accent;
      }
    }

    final statusAccent = statusColor(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bg, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOwn
                  ? accent.withValues(alpha: 0.55)
                  : accent.withValues(alpha: 0.35),
              width: isOwn ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isTax ? '세금' : '이행',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: statusAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusAccent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '긴급',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade50,
                        ),
                      ),
                    ),
                  if (isOwn)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '내 요청',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '담당: ${assignee.isEmpty ? '미지정' : assignee}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                '$extra$partialExtra',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: accent.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$requestStepText · ${row.createdAtText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (!row.isCompleted && row.issue == null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '요청 접수 후 처리 대기건',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 발급대기·부분발급 행 액션 버튼.
class IssuanceRowActions extends StatelessWidget {
  const IssuanceRowActions({
    required this.row,
    required this.onIssue,
    required this.onCancel,
    this.onOpenDetail,
    super.key,
  });

  final IssuanceRequestRow row;
  final Future<void> Function(IssuanceRequestRow row) onIssue;
  final Future<void> Function(IssuanceRequestRow row) onCancel;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    if (row.kind == IssuanceRowKind.request) {
      final isTax = row.domain == IssuanceDomain.taxInvoice;
      if (!isTax) {
        final accent = Colors.deepOrange.shade700;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onOpenDetail,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('상세 보기'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => onCancel(row),
                child: const Text('취소'),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: OutlinedButton(
          onPressed: () => onCancel(row),
          child: const Text('취소'),
        ),
      );
    }
    if (row.kind == IssuanceRowKind.partial &&
        row.domain == IssuanceDomain.taxInvoice) {
      final remaining = row.remainingPct.round();
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: FilledButton(
          onPressed: remaining <= 0 ? null : () => onIssue(row),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: Text('발급요청 ($remaining%)'),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
