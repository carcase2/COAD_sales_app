import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/data/sales_calls_repository.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_display.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SalesCallSearchDelegate extends SearchDelegate<void> {
  SalesCallSearchDelegate({
    required this.initialItems,
    required this.repository,
  });

  /// 초기 제안용 목록 (오늘 접수분 등)
  final List<SalesCall> initialItems;
  final SalesCallsRepository repository;

  @override
  String get searchFieldLabel => '전화번호, 현장명, 상담내용 검색';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildServerSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (looksLikePhoneQuery(query)) {
      return _buildServerSearchResults(context);
    }
    if (query.isEmpty) {
      return _buildEmptyState(
        context,
        '전화번호, 현장명, 상담내용으로 검색하세요.',
        hints: const [
          '010으로 시작하는 번호',
          '현장명·고객명',
          '과거 상담은 검색 후 「서버 검색」',
        ],
      );
    }

    final localResults = _filterLocalItems(query);
    
    return ListView(
      children: [
        if (localResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('현재 목록 내 결과 (${localResults.length})', 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          ...localResults.map((c) => _buildSearchItem(context, c, Theme.of(context).colorScheme)),
        ],
        ListTile(
          leading: const Icon(Icons.search_rounded, color: Colors.blue),
          title: Text('"$query" 전체 내역 서버 검색'),
          subtitle: const Text('오늘 이전의 모든 과거 기록을 포함하여 검색합니다.'),
          onTap: () => showResults(context),
        ),
      ],
    );
  }

  Widget _buildServerSearchResults(BuildContext context) {
    return FutureBuilder<List<SalesCall>>(
      future: repository.searchCalls(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildEmptyState(
            context,
            koreanErrorMessage(snapshot.error!),
            onRetry: () => showResults(context),
          );
        }
        
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return _buildEmptyState(context, '"$query"에 대한 전체 검색 결과가 없습니다.');
        }

        final scheme = Theme.of(context).colorScheme;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final c = results[index];
            return _buildSearchItem(context, c, scheme);
          },
        );
      },
    );
  }

  List<SalesCall> _filterLocalItems(String q) {
    final terms = q.toLowerCase().split(' ').where((t) => t.isNotEmpty);
    if (terms.isEmpty) return [];

    return initialItems.where((c) {
      return terms.every(
        (term) => termMatchesSalesCallSearch(
          term,
          customerName: c.customerName,
          customerPhone: c.customerPhone,
          inquiryContent: c.inquiryContent,
          regionLabel: c.regionLabel,
          productCategoryName: c.productCategoryName,
        ),
      );
    }).toList();
  }

  Widget _buildSearchItem(BuildContext context, SalesCall c, ColorScheme scheme) {
    final statusLabel = c.effectiveStatusLabel();
    final stageLabel = c.displayStageLabel;
    final inquiryMethod = c.displayInquiryMethod;
    final inquiry = (c.inquiryContent ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SalesCallDetailScreen(id: c.id, initial: c),
            ),
          );
        },
        onLongPress: () =>
            LauncherUtils.copyPhone(context, c.customerPhone ?? ''),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.business_rounded, size: 16, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SearchHighlightText(
                            text: c.customerName ?? '(이름 없음)',
                            query: query,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: [
                          _searchBadge(stageLabel, scheme.secondaryContainer, scheme.onSecondaryContainer),
                          _searchBadge(statusLabel, scheme.primaryContainer, scheme.onPrimaryContainer, bold: true),
                          if (inquiryMethod != null)
                            _searchBadge(inquiryMethod, scheme.tertiaryContainer, scheme.onTertiaryContainer),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.callDate ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone_android_rounded, size: 14, color: scheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SearchHighlightText(
                      text: c.customerPhone ?? '연락처 없음',
                      query: query,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.secondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (inquiry.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '문의내용',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SearchHighlightText(
                        text: inquiry,
                        query: query,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildQuickAction(Icons.call, Colors.green, () => LauncherUtils.makePhoneCall(c.customerPhone ?? '')),
                  const SizedBox(width: 8),
                  _buildQuickAction(Icons.message_rounded, Colors.blue, () => LauncherUtils.sendSMS(c.customerPhone ?? '')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: color.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String message, {
    List<String> hints = const [],
    VoidCallback? onRetry,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 64, color: scheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hints.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...hints.map(
                (h) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tips_and_updates_outlined,
                          size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        h,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 검색'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _searchBadge(String label, Color bg, Color fg, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        iconTheme: theme.iconTheme.copyWith(color: theme.colorScheme.onSurface),
        titleTextStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(fontSize: 16),
      ),
    );
  }
}
