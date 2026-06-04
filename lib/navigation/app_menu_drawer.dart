import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/navigation/app_menu.dart';
import 'package:flutter/material.dart';

/// 햄버거 드로어 — 바로가기·검색·카드형 목록(메뉴 추가 시 구조 유지).
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

  List<AppMenuEntry> get _visibleEntries {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _enabledEntries;
    return _enabledEntries
        .where(
          (e) => e.searchTokens.any((t) => t.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visibleEntries;
    final visibleIds = visible.map((e) => e.id).toSet();
    final showQuick = _query.isEmpty && _quickEntries.isNotEmpty;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            currentAccountPicture: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 40,
                color: scheme.onPrimaryContainer,
              ),
            ),
            accountName: Text(
              widget.accountName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(
              widget.accountSubtitle,
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8)),
            ),
            decoration:
                widget.headerDecoration ?? BoxDecoration(color: scheme.primary),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _searchController,
              hintText: '메뉴 검색 (미통화, 달력, 접수…)',
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
                EdgeInsets.symmetric(horizontal: 12),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHighest.withValues(alpha: 0.65),
              ),
            ),
          ),
          if (showQuick) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '바로가기',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _quickEntries)
                    _QuickChip(entry: entry, scheme: scheme),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '검색 결과가 없습니다.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (final section in widget.catalog.sections) ...[
                        if (visible.any((e) => e.sectionId == section.id)) ...[
                          _SectionTitle(title: section.title, scheme: scheme),
                          for (final entry in widget.catalog.entriesForSection(
                            section.id,
                          ))
                            if (visibleIds.contains(entry.id))
                              _MenuCard(entry: entry, scheme: scheme),
                        ],
                      ],
                    ],
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
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

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.entry, required this.scheme});

  final AppMenuEntry entry;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(entry.icon, size: 18, color: scheme.primary),
      label: Text(
        entry.quickLabel ?? entry.title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: entry.onTap,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.45),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.primary.withValues(alpha: 0.7),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.entry, required this.scheme});

  final AppMenuEntry entry;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isLogout = entry.id == 'logout';
    final accent = isLogout ? scheme.error : scheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: entry.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(entry.icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isLogout ? scheme.error : scheme.onSurface,
                        ),
                      ),
                      if (entry.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (entry.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      entry.badge!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
