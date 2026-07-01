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
          if (showGrid) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.08,
                children: [
                  for (final entry in _quickEntries)
                    _GridMenuTile(entry: entry, scheme: scheme),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
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
          Expanded(
            child: visibleList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        searching ? '검색 결과가 없습니다.' : '추가 메뉴가 없습니다.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      if (!searching)
                        for (final section in widget.catalog.sections)
                          if (visibleList.any(
                            (e) => e.sectionId == section.id,
                          )) ...[
                            _SectionTitle(title: section.title, scheme: scheme),
                            for (final entry in visibleList.where(
                              (e) => e.sectionId == section.id,
                            ))
                              _MenuListTile(entry: entry, scheme: scheme),
                          ]
                      else
                        for (final entry in visibleList)
                          _MenuListTile(entry: entry, scheme: scheme),
                    ],
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'COAD Sales App v$kAppVersion',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(entry.icon, size: 24, color: scheme.primary),
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
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
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
