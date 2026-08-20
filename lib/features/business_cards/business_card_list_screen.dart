import 'dart:async';

import 'package:coad_customer_calls/core/utils/business_card_permissions.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_detail_screen.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_edit_screen.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_widgets.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BusinessCardListScreen extends ConsumerStatefulWidget {
  const BusinessCardListScreen({super.key});

  @override
  ConsumerState<BusinessCardListScreen> createState() =>
      _BusinessCardListScreenState();
}

class _BusinessCardListScreenState extends ConsumerState<BusinessCardListScreen> {
  final _queryCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  BusinessCardListFilter _filter = BusinessCardListFilter.all;
  List<BusinessCard> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingMore || !_hasMore) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 240) {
      unawaited(_loadMore());
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      unawaited(_reload());
    });
  }

  Future<void> _reload() async {
    final user = ref.read(authControllerProvider);
    if (user == null || !canAccessBusinessCards(user)) {
      setState(() {
        _loading = false;
        _error = '명함 수첩 권한이 없습니다.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _activeQuery = _queryCtrl.text.trim();
    });
    try {
      final result = await ref.read(businessCardRepositoryProvider).list(
            user: user,
            query: _activeQuery,
            filter: _filter,
          );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final user = ref.read(authControllerProvider);
    if (user == null || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await ref.read(businessCardRepositoryProvider).list(
            user: user,
            query: _activeQuery,
            filter: _filter,
            offset: _items.length,
          );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...result.items];
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _openCreate() async {
    HapticFeedback.selectionClick();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const BusinessCardEditScreen()),
    );
    if (saved == true && mounted) unawaited(_reload());
  }

  Future<void> _openDetail(BusinessCard card) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BusinessCardDetailScreen(cardId: card.id, initial: card),
      ),
    );
    if (changed == true && mounted) unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          '명함 수첩',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: user != null && canAccessBusinessCards(user)
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('명함 등록'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: '이름 · 회사 · 번호 · 팩스 · 주소 · 등록자',
              leading: const Icon(Icons.search_rounded, size: 20),
              trailing: _queryCtrl.text.isEmpty
                  ? null
                  : [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _queryCtrl.clear();
                          unawaited(_reload());
                          setState(() {});
                        },
                      ),
                    ],
              onChanged: (v) {
                setState(() {});
                _onQueryChanged(v);
              },
              onSubmitted: (_) => unawaited(_reload()),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _filterChip('전체', BusinessCardListFilter.all, scheme),
                _filterChip('내가 등록', BusinessCardListFilter.mine, scheme),
                _filterChip('비공개', BusinessCardListFilter.privateOnly, scheme),
                _filterChip('블랙리스트', BusinessCardListFilter.blacklisted, scheme),
              ],
            ),
          ),
          Expanded(child: _buildBody(scheme)),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    BusinessCardListFilter value,
    ColorScheme scheme,
  ) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _filter = value);
        unawaited(_reload());
      },
      selectedColor: value == BusinessCardListFilter.blacklisted
          ? scheme.errorContainer
          : scheme.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) {
      return const AppLoading(message: '명함을 불러오는 중…');
    }
    if (_error != null) {
      return AppErrorState(
        message: koreanErrorMessage(_error!),
        onRetry: () => unawaited(_reload()),
      );
    }
    if (_items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: AppEmpty(
                icon: Icons.contact_page_outlined,
                message: _activeQuery.isEmpty ? '등록된 명함이 없습니다.' : '검색 결과가 없습니다.',
                detail: _activeQuery.isEmpty
                    ? '명함을 촬영하면 이름·전화번호가 자동으로 채워집니다.'
                    : null,
                actionLabel: _activeQuery.isEmpty ? '명함 등록' : null,
                onAction: _activeQuery.isEmpty ? _openCreate : null,
              ),
            ),
          );
        },
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: AppLoading(compact: true)),
            );
          }
          final card = _items[index];
          return _CardTile(
            card: card,
            query: _activeQuery,
            scheme: scheme,
            onTap: () => unawaited(_openDetail(card)),
          );
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.query,
    required this.scheme,
    required this.onTap,
  });

  final BusinessCard card;
  final String query;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              BusinessCardAvatar(card: card),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SearchHighlightText(
                            text: card.displayName,
                            query: query,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (card.isBlacklisted)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.block_rounded,
                              size: 16,
                              color: scheme.error,
                            ),
                          ),
                        if (card.isPrivate)
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: scheme.outline,
                          ),
                      ],
                    ),
                    if (card.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      SearchHighlightText(
                        text: card.subtitle,
                        query: query,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    SearchHighlightText(
                      text: [
                        if (card.primaryPhone.isNotEmpty) card.primaryPhone,
                        if (card.officePhone.isNotEmpty &&
                            card.officePhone != card.primaryPhone)
                          card.officePhone,
                        if (card.faxPhone.isNotEmpty) '팩스 ${card.faxPhone}',
                        card.createdByName,
                        formatSeoulDateTime(card.createdAt),
                        if (card.commentCount > 0) '메모 ${card.commentCount}',
                      ].join(' · '),
                      query: query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                      ),
                    ),
                    if (query.trim().isNotEmpty) ...[
                      for (final extra in _matchingExtras(card, query)) ...[
                        const SizedBox(height: 2),
                        SearchHighlightText(
                          text: extra,
                          query: query,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _matchingExtras(BusinessCard card, String query) {
  final extras = <String>[];
  if (card.address.isNotEmpty && searchTextMatches(card.address, query)) {
    extras.add(card.address);
  }
  if (card.email.isNotEmpty && searchTextMatches(card.email, query)) {
    extras.add(card.email);
  }
  return extras;
}
