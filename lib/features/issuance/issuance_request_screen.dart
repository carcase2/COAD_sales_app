import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_create_screen.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IssuanceRequestScreen extends ConsumerStatefulWidget {
  const IssuanceRequestScreen({super.key});

  @override
  ConsumerState<IssuanceRequestScreen> createState() => _IssuanceRequestScreenState();
}

class _IssuanceRequestScreenState extends ConsumerState<IssuanceRequestScreen> {
  IssuanceDomain _domain = IssuanceDomain.taxInvoice;
  String _selectedAssignee = '전체';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rowsAsync = ref.watch(issuanceRequestRowsProvider(_domain));
    final taxRowsAsync = ref.watch(issuanceRequestRowsProvider(IssuanceDomain.taxInvoice));
    final bondRowsAsync = ref.watch(issuanceRequestRowsProvider(IssuanceDomain.performanceBond));
    final taxCount = taxRowsAsync.valueOrNull?.length;
    final bondCount = bondRowsAsync.valueOrNull?.length;
    final isTax = _domain == IssuanceDomain.taxInvoice;
    final accent = isTax ? Colors.indigo.shade600 : Colors.deepOrange.shade700;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: 0.92), accent.withValues(alpha: 0.72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '발급요청',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '새로고침',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          ref.invalidate(issuanceRequestRowsProvider(_domain));
                          ref.invalidate(issuanceRequestBadgeCountProvider);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                      ),
                      const SizedBox(width: 6),
                      rowsAsync.when(
                        data: (rows) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${rows.length}건',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (error, stack) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildDomainTabButton(
                          label: '세금계산서',
                          count: taxCount,
                          selected: _domain == IssuanceDomain.taxInvoice,
                          accent: accent,
                          onTap: () => setState(() => _domain = IssuanceDomain.taxInvoice),
                        ),
                        const SizedBox(width: 6),
                        _buildDomainTabButton(
                          label: '이행증권',
                          count: bondCount,
                          selected: _domain == IssuanceDomain.performanceBond,
                          accent: accent,
                          onTap: () => setState(() => _domain = IssuanceDomain.performanceBond),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openCreateForCurrentDomain,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('발급하기'),
              ),
            ),
          ),
          Expanded(child: _buildBody(scheme, rowsAsync)),
        ],
      ),
    );
  }

  Future<void> _openCreateForCurrentDomain() async {
    final selected = _domain;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => IssuanceRequestCreateScreen(initialDomain: selected),
      ),
    );
    if (created == true && mounted) {
      setState(() => _domain = selected);
      ref.invalidate(issuanceRequestRowsProvider(IssuanceDomain.taxInvoice));
      ref.invalidate(issuanceRequestRowsProvider(IssuanceDomain.performanceBond));
      ref.invalidate(issuanceRequestBadgeCountProvider);
    }
  }

  Widget _buildBody(ColorScheme scheme, AsyncValue<List<IssuanceRequestRow>> rowsAsync) {
    return rowsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error, size: 40),
              const SizedBox(height: 8),
              Text(
                '발급요청을 불러오지 못했습니다.\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      data: (rows) {
        final userName = ref.watch(authControllerProvider)?.name?.trim();
        final counts = <String, int>{'전체': rows.length};
        for (final row in rows) {
          final assignee = _assigneeText(row);
          counts[assignee] = (counts[assignee] ?? 0) + 1;
        }

        if (_selectedAssignee == '전체' && userName != null && userName.isNotEmpty && counts.containsKey(userName)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedAssignee == '전체') {
              setState(() => _selectedAssignee = userName);
            }
          });
        }

        final filteredRows = rows
            .where(
              (row) => _selectedAssignee == '전체' || _assigneeText(row) == _selectedAssignee,
            )
            .toList();

        final assignees = counts.keys.toList()
          ..sort((a, b) {
            if (a == '전체') return -1;
            if (b == '전체') return 1;
            final cA = counts[a] ?? 0;
            final cB = counts[b] ?? 0;
            if (cA != cB) return cB.compareTo(cA);
            return a.compareTo(b);
          });

        if (rows.isEmpty) {
          return Center(
            child: Text(
              '현재 발급요청 대기 건이 없습니다.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          );
        }
        return Column(
          children: [
            Container(
              height: 46,
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: assignees.length,
                itemBuilder: (context, idx) {
                  final name = assignees[idx];
                  final count = counts[name] ?? 0;
                  final selected = _selectedAssignee == name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$name  $count'),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _selectedAssignee = name),
                      labelStyle: TextStyle(
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: filteredRows.isEmpty
                  ? Center(
                      child: Text(
                        '선택한 담당자의 발급요청이 없습니다.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filteredRows.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _IssuanceRequestCard(
                        row: filteredRows[index],
                        onTap: () => _showRequestDetail(filteredRows[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  String _assigneeText(IssuanceRequestRow row) {
    final master = row.master;
    final assignee = (master['requester'] ?? master['created_by_name'] ?? master['created_by'] ?? '').toString().trim();
    return assignee.isEmpty ? '미지정' : assignee;
  }

  void _showRequestDetail(IssuanceRequestRow row) {
    String statusLabel(String raw) {
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
    final issue = row.issue;
    final accent = isTax ? Colors.indigo.shade600 : Colors.deepOrange.shade700;

    String textOf(String key, {Map<String, dynamic>? from}) {
      final source = from ?? master;
      final value = (source[key] ?? '').toString().trim();
      return value.isEmpty ? '-' : value;
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

    final details = <Widget>[
      kv('요청 구분', isTax ? '세금계산서' : '이행증권'),
      kv('상태', statusLabel(textOf('status'))),
      kv('요청일', row.createdAtText),
      kv('요청자', textOf('requester')),
      if (isTax) ...[
        kv('고객명', textOf('customer_name')),
        kv('품목명', textOf('item_name')),
        kv('총액', textOf('total_amount')),
        kv('발행 퍼센트', '${textOf('percentage')}%'),
        kv('지사', textOf('branch')),
      ] else ...[
        kv('업체명', textOf('company_name')),
        kv('증권 종류', textOf('bond_type')),
        kv('계약금액', textOf('contract_amount')),
        kv('보증금율', '${textOf('guarantee_rate')}%'),
        kv('보증기간', '${textOf('guarantee_period')}년'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: details,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDomainTabButton({
    required String label,
    required int? count,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final countText = count == null ? '…' : '$count';
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? accent : Colors.white.withValues(alpha: 0.92),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? accent.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  countText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? accent : Colors.white,
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

class _IssuanceRequestCard extends StatelessWidget {
  const _IssuanceRequestCard({
    required this.row,
    required this.onTap,
  });

  final IssuanceRequestRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String textOf(String key) => (row.master[key] ?? '').toString().trim();
    String statusLabel(String raw) {
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
      final num = int.tryParse(raw.replaceAll(',', ''));
      if (num == null) return raw.isEmpty ? '-' : raw;
      final s = num.toString();
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
    final title = isTax
        ? (textOf('customer_name').isEmpty ? row.title : textOf('customer_name'))
        : (textOf('company_name').isEmpty ? row.title : textOf('company_name'));
    final assignee = (textOf('requester').isEmpty ? textOf('created_by') : textOf('requester'));
    final status = statusLabel(textOf('status'));
    final extra = isTax
        ? '품목: ${textOf('item_name').isEmpty ? '-' : textOf('item_name')} · 총액: ${formatWon(textOf('total_amount'))}'
        : '종류: ${textOf('bond_type').isEmpty ? '-' : textOf('bond_type')} · 계약금액: ${formatWon(textOf('contract_amount'))}';
    final requestStepText = row.issue == null ? '요청 접수' : '요청 진행';
    final isUrgent = (row.issue?['is_urgent'] ?? false) == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isTax ? '세금' : '이행',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '상태: $status · 담당: ${assignee.isEmpty ? '미지정' : assignee}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                extra,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: accent.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$requestStepText · ${row.createdAtText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (row.issue == null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '요청 접수 후 처리 대기건',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
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
