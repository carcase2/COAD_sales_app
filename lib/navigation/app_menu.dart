import 'package:flutter/material.dart';

/// 앱 전역 메뉴 한 줄 — 드로어·추후 「더보기」탭·바텀시트가 동일 목록을 씀.
class AppMenuEntry {
  const AppMenuEntry({
    required this.id,
    required this.sectionId,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.enabled = true,
    this.keywords = const [],
    this.quickAccess = false,
    this.quickLabel,
    required this.onTap,
  });

  final String id;
  final String sectionId;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final bool enabled;
  /// 검색용 동의어(메뉴가 늘어날 때 드로어 검색에 사용).
  final List<String> keywords;
  /// 드로어 상단 그리드에만 표시(아래 목록에는 중복 노출 안 함).
  final bool quickAccess;
  /// 바로가기 칩 라벨(없으면 [title]).
  final String? quickLabel;
  final VoidCallback onTap;

  Iterable<String> get searchTokens => [
        title,
        if (subtitle != null) subtitle!,
        if (badge != null) badge!,
        ...keywords,
      ];
}

class AppMenuSection {
  const AppMenuSection({required this.id, required this.title});

  final String id;
  final String title;
}

/// [AppMenuDrawer]에 넘길 섹션·항목 묶음.
class AppMenuCatalog {
  const AppMenuCatalog({required this.sections, required this.entries});

  final List<AppMenuSection> sections;
  final List<AppMenuEntry> entries;

  List<AppMenuEntry> entriesForSection(String sectionId) =>
      entries.where((e) => e.sectionId == sectionId).toList(growable: false);
}
