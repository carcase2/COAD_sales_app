import 'dart:convert';

import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String formatBondPeriod(String raw, String bondType) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '-';
    final asInt = int.tryParse(trimmed);
    if (asInt != null && asInt > 0) {
      return bondType == '하자이행' ? '$asInt년' : '$asInt달';
    }
    final years = double.tryParse(trimmed);
    if (years == null || years <= 0) return trimmed;
    final rounded = years.round();
    if (rounded <= 0) return trimmed;
    return bondType == '하자이행' ? '$rounded년' : '$rounded달';
  }

  String formatDateTime(String raw) {
    if (raw == '-') return raw;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  List<String> parseUrlList(dynamic raw) {
    if (raw == null) return const [];
    final text = raw.toString().trim();
    if (text.isEmpty || text == '-') return const [];
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    if (text.startsWith('{')) return const [];
    return [text];
  }

  Map<String, List<String>> parseBondGroups(dynamic rawValue) {
    final raw = (rawValue ?? '').toString().trim();
    if (raw.isEmpty || raw == '-') return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final business = ((decoded['business'] as List?) ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final contract = ((decoded['contract'] as List?) ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final map = <String, List<String>>{};
        if (business.isNotEmpty) map['사업자등록증'] = business;
        if (contract.isNotEmpty) map['계약서'] = contract;
        return map;
      }
      if (decoded is List) {
        final list = decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (list.isEmpty) return const {};
        return {'첨부': list};
      }
    } catch (_) {}
    return const {};
  }

  Map<String, List<String>> dedupeGroups(Map<String, List<String>> src) {
    final result = <String, List<String>>{};
    for (final entry in src.entries) {
      final deduped = <String>[];
      final seen = <String>{};
      for (final u in entry.value) {
        if (seen.add(u)) deduped.add(u);
      }
      if (deduped.isNotEmpty) result[entry.key] = deduped;
    }
    return result;
  }

  Future<Map<String, List<String>>> fetchBondGroupsFromDb() async {
    final masterId = master['id']?.toString().trim() ?? '';
    if (masterId.isEmpty) return const {};
    try {
      final rows = await Supabase.instance.client
          .from('performance_bond_issues')
          .select('request_image_url, issue_order, created_at')
          .eq('performance_bond_id', masterId)
          .order('issue_order', ascending: false)
          .order('created_at', ascending: false);
      final grouped = <String, List<String>>{};
      for (final rowMap in List<Map<String, dynamic>>.from(rows)) {
        final parsed = parseBondGroups(rowMap['request_image_url']);
        for (final entry in parsed.entries) {
          grouped.putIfAbsent(entry.key, () => []);
          grouped[entry.key]!.addAll(entry.value);
        }
      }
      return dedupeGroups(grouped);
    } catch (_) {
      return const {};
    }
  }

  List<({String url, String label})> flattenLabeledImages(
    Map<String, List<String>> groups,
  ) {
    final items = <({String url, String label})>[];
    for (final entry in groups.entries) {
      for (final url in entry.value) {
        if (classifyAttachmentUrl(url) == AttachmentKind.image) {
          items.add((url: url, label: entry.key));
        }
      }
    }
    return items;
  }

  void openGallery(
    BuildContext context,
    String title,
    List<({String url, String label})> items,
  ) {
    if (items.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _IssuanceNetworkGalleryScreen(
          title: title,
          items: items,
        ),
      ),
    );
  }

  Future<void> openExternalFirst(BuildContext context, List<String> urls) async {
    if (urls.isEmpty) return;
    final uri = Uri.tryParse(urls.first);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('첨부 파일을 열 수 없습니다.')),
      );
    }
  }

  Widget attachmentButton(
    BuildContext context,
    Map<String, List<String>> groups, {
    String galleryTitle = '첨부',
    String buttonPrefix = '첨부',
  }) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final totalCount = groups.values.fold<int>(0, (sum, list) => sum + list.length);
    final imageItems = flattenLabeledImages(groups);
    final allUrls = groups.values.expand((e) => e).toList(growable: false);
    return FilledButton.tonalIcon(
      onPressed: () async {
        if (imageItems.isNotEmpty) {
          openGallery(context, galleryTitle, imageItems);
        } else {
          await openExternalFirst(context, allUrls);
        }
      },
      icon: Icon(
        imageItems.isNotEmpty
            ? Icons.photo_library_outlined
            : Icons.insert_drive_file_outlined,
        size: 18,
      ),
      label: Text('$buttonPrefix ($totalCount)'),
    );
  }

  final isUrgent = isTax && (issue?['is_urgent'] ?? false) == true;
  final taxBizUrls = isTax ? parseUrlList(master['business_registration_image_url']) : const <String>[];
  final currentBondGroups = isTax ? const <String, List<String>>{} : parseBondGroups(issue?['request_image_url']);
  final primaryGroups = isTax
      ? (taxBizUrls.isEmpty ? const <String, List<String>>{} : {'사업자등록증': taxBizUrls})
      : dedupeGroups(currentBondGroups);

  List<String> issuedDocUrls() {
    if (isTax) {
      final fromIssue = parseUrlList(issue?['invoice_image_url']);
      if (fromIssue.isNotEmpty) return fromIssue;
      return parseUrlList(master['invoice_image_url']);
    }
    final fromIssue = parseUrlList(issue?['bond_image_url']);
    if (fromIssue.isNotEmpty) return fromIssue;
    return parseUrlList(master['bond_image_url']);
  }

  final issuedUrls = issuedDocUrls();
  final issuedGroups = issuedUrls.isEmpty
      ? const <String, List<String>>{}
      : {isTax ? '발급 계산서' : '발급 증권': issuedUrls};
  final issueYmd = issuanceIssueYmdForRow(row);

  final details = <Widget>[
    kv('요청 구분', isTax ? '세금계산서' : '이행증권'),
    kv('상태', statusLabel(textOf('status'))),
    if (isUrgent) kv('긴급', '예'),
    kv('요청일', row.createdAtText),
    if (issuedUrls.isNotEmpty && issueYmd.isNotEmpty)
      kv('발행일', issueYmd),
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
    ] else ...[
      kv('증권번호', textOf('bond_number')),
      kv('업체명', textOf('company_name')),
      kv('증권 종류', textOf('bond_type')),
      kv('계약금액', formatWon(textOf('contract_amount'))),
      kv('보증금율', '${textOf('guarantee_rate')}%'),
      kv('보증기간', formatBondPeriod(textOf('guarantee_period'), textOf('bond_type'))),
      kv(
        '시공 시작일',
        textOf('construction_start_date', from: issue) == '-'
            ? textOf('contract_date')
            : textOf('construction_start_date', from: issue),
      ),
      kv('시공 종료일', textOf('construction_end_date', from: issue)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(children: details),
                ),
                if (primaryGroups.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  attachmentButton(context, primaryGroups),
                ],
                if (issuedGroups.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  attachmentButton(
                    context,
                    issuedGroups,
                    galleryTitle: isTax ? '발급 계산서' : '발급 증권',
                    buttonPrefix: isTax ? '발급 계산서' : '발급 증권',
                  ),
                ],
                if (!isTax && primaryGroups.isEmpty) ...[
                  const SizedBox(height: 12),
                  FutureBuilder<Map<String, List<String>>>(
                    future: fetchBondGroupsFromDb(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final groups = snapshot.data ?? const <String, List<String>>{};
                      if (groups.isEmpty) return const SizedBox.shrink();
                      return attachmentButton(context, groups);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _IssuanceNetworkGalleryScreen extends StatefulWidget {
  const _IssuanceNetworkGalleryScreen({
    required this.title,
    required this.items,
  });

  final String title;
  final List<({String url, String label})> items;

  @override
  State<_IssuanceNetworkGalleryScreen> createState() =>
      _IssuanceNetworkGalleryScreenState();
}

class _IssuanceNetworkGalleryScreenState
    extends State<_IssuanceNetworkGalleryScreen> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '${_index + 1}/${widget.items.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, i) {
              final item = widget.items[i];
              return InteractiveViewer(
                minScale: 0.7,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    item.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const CircularProgressIndicator(color: Colors.white);
                    },
                    errorBuilder: (_, _, _) => const Text(
                      '이미지를 불러올 수 없습니다.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.items[_index].label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
