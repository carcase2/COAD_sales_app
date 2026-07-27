import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/navigation/app_menu.dart';
import 'package:flutter/material.dart';

/// 햄버거 드로어 — 상단 3열 그리드 바로가기 + 하단 계정 메뉴(중복 최소화).
class AppMenuDrawer extends StatefulWidget {
  const AppMenuDrawer({
    super.key,
    required this.catalog,
    required this.accountName,
    required this.accountSubtitle,
    this.headerDecoration,
  });

  final AppMenuCatalog catalog;
  final String accountName;
  final String accountSubtitle;
  final BoxDecoration? headerDecoration;

  @override
  State<AppMenuDrawer> createState() => _AppMenuDrawerState();
}

class _AppMenuDrawerState extends State<AppMenuDrawer> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppMenuEntry> get _enabledEntries =>
      widget.catalog.entries.where((e) => e.enabled).toList();

  List<AppMenuEntry> get _quickEntries =>
      _enabledEntries.where((e) => e.quickAccess).toList();

  /// 하단 목록 — 바로가기 그리드와 겹치지 않는 항목만.
  List<AppMenuEntry> get _listEntries =>
      _enabledEntries.where((e) => !e.quickAccess).toList();

  List<AppMenuEntry> get _visibleListEntries {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _listEntries;
    return _enabledEntries
        .where(
          (e) => e.searchTokens.any((t) => t.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final searching = _query.trim().isNotEmpty;
    final showGrid = !searching && _quickEntries.isNotEmpty;
    final visibleList = _visibleListEntries;

    return Drawer(
      child: Column(
        children: [
          _CompactDrawerHeader(
            accountName: widget.accountName,
            accountSubtitle: widget.accountSubtitle,
            decoration:
                widget.headerDecoration ?? BoxDecoration(color: scheme.primary),
            scheme: scheme,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: SearchBar(
              controller: _searchController,
              hintText: '메뉴 검색',
              leading: const Icon(Icons.search_rounded, size: 20),
              trailing: _query.isEmpty
                  ? null
                  : [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ],
              onChanged: (v) => setState(() => _query = v),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              ),
            ),
          ),
          // 그리드+목록을 한 스크롤로 — 하단 overflow 방지
          Expanded(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                if (showGrid) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                      child: Text(
                        '바로가기',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  // 3열 그리드 — 남는 높이 강제 없이 콘텐츠 높이만 사용
                  // (항상 스크롤 부모 안이므로 overflow 없음)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: _QuickGridSliver(
                      entries: _quickEntries,
                      scheme: scheme,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
                if (searching)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        '검색 결과',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                if (visibleList.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          searching ? '검색 결과가 없습니다.' : '추가 메뉴가 없습니다.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  )
                else if (!searching)
                  SliverList(
                    delegate: SliverChildListDelegate([
                      for (final section in widget.catalog.sections)
                        if (visibleList.any((e) => e.sectionId == section.id))
                          ...[
                            _SectionTitle(
                              title: section.title,
                              scheme: scheme,
                            ),
                            for (final entry in visibleList.where(
                              (e) => e.sectionId == section.id,
                            ))
                              _MenuListTile(entry: entry, scheme: scheme),
                          ],
                      const SizedBox(height: 8),
                    ]),
                  )
                else
                  SliverList(
                    delegate: SliverChildListDelegate([
                      for (final entry in visibleList)
                        _MenuListTile(entry: entry, scheme: scheme),
                      const SizedBox(height: 8),
                    ]),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 더보기(드로어)에서 바로 버전 확인 — 고정 하단
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'COAD Sales App',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'v$kAppVersion',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 바로가기 3열 그리드 (슬라버) — 행 수에 맞게 높이 계산.
class _QuickGridSliver extends StatelessWidget {
  const _QuickGridSliver({
    required this.entries,
    required this.scheme,
  });

  final List<AppMenuEntry> entries;
  final ColorScheme scheme;

  static const _cols = 3;
  static const _gap = 8.0;
  // 셀 대략 높이 (아이콘+라벨) — LayoutBuilder로 폭 기준 보정
  static const _minCellH = 72.0;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.crossAxisExtent;
        final cellW = (maxW - _gap * (_cols - 1)) / _cols;
        // 약간 납작하게 — 세로 overflow 여유
        final cellH = (cellW / 1.08).clamp(_minCellH, 96.0);
        final rows = (entries.length / _cols).ceil();
        final totalH =
            rows * cellH + (rows > 0 ? (rows - 1) * _gap : 0);

        return SliverToBoxAdapter(
          child: SizedBox(
            height: totalH,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _cols,
                mainAxisSpacing: _gap,
                crossAxisSpacing: _gap,
                mainAxisExtent: cellH,
              ),
              itemBuilder: (context, i) =>
                  _GridMenuTile(entry: entries[i], scheme: scheme),
            ),
          ),
        );
      },
    );
  }
}

class _CompactDrawerHeader extends StatelessWidget {
  const _CompactDrawerHeader({
    required this.accountName,
    required this.accountSubtitle,
    required this.decoration,
    required this.scheme,
  });

  final String accountName;
  final String accountSubtitle;
  final BoxDecoration decoration;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: decoration,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  size: 26,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onPrimary.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridMenuTile extends StatelessWidget {
  const _GridMenuTile({required this.entry, required this.scheme});

  final AppMenuEntry entry;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final label = entry.quickLabel ?? entry.title;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: entry.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(entry.icon, size: 22, color: scheme.primary),
                  if (entry.badge != null)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.badge!,
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            color: scheme.onTertiary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.scheme});

  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MenuListTile extends StatelessWidget {
  const _MenuListTile({required this.entry, required this.scheme});

  final AppMenuEntry entry;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isLogout = entry.id == 'logout';
    final accent = isLogout ? scheme.error : scheme.primary;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(entry.icon, color: accent, size: 22),
      title: Text(
        entry.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isLogout ? scheme.error : scheme.onSurface,
        ),
      ),
      subtitle: entry.subtitle == null
          ? null
          : Text(
              entry.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
      trailing: entry.badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                entry.badge!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            )
          : Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
      onTap: entry.onTap,
    );
  }
}
