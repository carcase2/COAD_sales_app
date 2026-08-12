import 'dart:async';

import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/cached_app_image.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/data/checksheet_archive_repository.dart';
import 'package:coad_customer_calls/features/checksheet/checksheet_usage_screen.dart';
import 'package:coad_customer_calls/models/checksheet_archive.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/usage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// MES 아카이브 체크시트(TP1) 검색 · 조회 (읽기 전용).
class ChecksheetSearchScreen extends ConsumerStatefulWidget {
  const ChecksheetSearchScreen({super.key});

  @override
  ConsumerState<ChecksheetSearchScreen> createState() =>
      _ChecksheetSearchScreenState();
}

class _ChecksheetSearchScreenState
    extends ConsumerState<ChecksheetSearchScreen> {
  final _queryCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  AsyncValue<ChecksheetSearchResult> _data = const AsyncData(
    ChecksheetSearchResult.empty,
  );
  bool _loadingMore = false;
  bool _searched = false;
  String _activeQuery = '';

  int? _year;
  int? _month;

  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authControllerProvider);
      if (user == null) return;
      unawaited(
        UsageService.recordChecksheet(
          userId: user.id,
          userName: user.name,
          action: 'open',
        ),
      );
    });
  }

  void _track(String action) {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    unawaited(
      UsageService.recordChecksheet(
        userId: user.id,
        userName: user.name,
        action: action,
      ),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      unawaited(_loadMore());
    }
  }

  Future<void> _search({bool reset = true}) async {
    FocusScope.of(context).unfocus();
    final user = ref.read(authControllerProvider);
    final q = _queryCtrl.text.trim();
    HapticFeedback.selectionClick();

    if (reset) {
      setState(() {
        _searched = true;
        _activeQuery = q;
        _data = const AsyncLoading();
      });
    }

    try {
      final result = await ref.read(checksheetArchiveRepositoryProvider).search(
            query: q,
            year: _year,
            month: _month,
            limit: _pageSize,
            offset: 0,
            userId: user?.id,
          );
      _track('search');
      if (!mounted) return;
      setState(() {
        _activeQuery = q;
        _data = AsyncData(result);
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _data = AsyncError(e, st));
    }
  }

  Future<void> _loadMore() async {
    final current = _data.asData?.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    if (_data.isLoading) return;

    setState(() => _loadingMore = true);
    final user = ref.read(authControllerProvider);
    try {
      final next = await ref.read(checksheetArchiveRepositoryProvider).search(
            query: _queryCtrl.text.trim(),
            year: _year,
            month: _month,
            limit: _pageSize,
            offset: current.nextOffset ?? current.sites.length,
            userId: user?.id,
          );
      if (!mounted) return;
      setState(() {
        _data = AsyncData(
          ChecksheetSearchResult(
            sites: [...current.sites, ...next.sites],
            totalSites: next.totalSites,
            totalAttachments:
                current.totalAttachments + next.totalAttachments,
            offset: next.offset,
            limit: next.limit,
            nextOffset: next.nextOffset,
            query: next.query,
          ),
        );
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _openSite(ChecksheetSite site) {
    final user = ref.read(authControllerProvider);
    final repo = ref.read(checksheetArchiveRepositoryProvider);
    _track('view');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChecksheetGalleryScreen(
          site: site,
          highlightQuery: _activeQuery,
          resolveUrl: (path) =>
              repo.absoluteMediaUrl(path, userId: user?.id),
          headersForUrl: repo.mediaHttpHeadersForUrl,
          onDownload: () => _track('download'),
        ),
      ),
    );
  }

  ({String? url, Map<String, String>? headers}) _thumb(ChecksheetSite site) {
    final path =
        site.thumbnailMediaPath ?? site.attachments.firstOrNull?.mediaPath;
    if (path == null || path.isEmpty) {
      return (url: null, headers: null);
    }
    try {
      final user = ref.read(authControllerProvider);
      final repo = ref.read(checksheetArchiveRepositoryProvider);
      final url = repo.absoluteMediaUrl(path, userId: user?.id);
      return (url: url, headers: repo.mediaHttpHeadersForUrl(url));
    } catch (_) {
      return (url: null, headers: null);
    }
  }

  InputDecoration _dropdownDeco(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final years = List<int>.generate(
      8,
      (i) => DateTime.now().year - i,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('체크시트 검색'),
        actions: [
          if (isAppAdmin(ref.watch(authControllerProvider)))
            IconButton(
              tooltip: '사용 내역',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChecksheetUsageScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.bar_chart_rounded),
            ),
          TextButton(
            onPressed: () => unawaited(_search()),
            child: const Text('검색'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _queryCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => unawaited(_search()),
                    decoration: InputDecoration(
                      hintText: '현장명 (예: 화성)',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
                      suffixIcon: _queryCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '지우기',
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                _queryCtrl.clear();
                                setState(() {});
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          isExpanded: true,
                          isDense: true,
                          // ignore: deprecated_member_use
                          value: _year,
                          decoration: _dropdownDeco('연도'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('전체', overflow: TextOverflow.ellipsis),
                            ),
                            ...years.map(
                              (y) => DropdownMenuItem<int?>(
                                value: y,
                                child: Text(
                                  '$y',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _year = v;
                            if (v == null) _month = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          isExpanded: true,
                          isDense: true,
                          // ignore: deprecated_member_use
                          value: _month,
                          decoration: _dropdownDeco('월'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('전체', overflow: TextOverflow.ellipsis),
                            ),
                            ...List.generate(
                              12,
                              (i) => DropdownMenuItem<int?>(
                                value: i + 1,
                                child: Text(
                                  '${i + 1}월',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: _year == null
                              ? null
                              : (v) => setState(() => _month = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => unawaited(_search()),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          minimumSize: const Size(64, 44),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '검색',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '체크시트(TP1) · MES 아카이브',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(child: _buildBody(scheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (!_searched) {
      return const _ScrollableMessage(
        child: AppEmpty(
          message: '현장명을 입력하고 검색하세요.\n예: 화성, 삼성전자',
          icon: Icons.image_search_rounded,
        ),
      );
    }

    return _data.when(
      loading: () => const AppLoading(message: '검색 중…'),
      error: (e, _) => _ScrollableMessage(
        child: AppErrorState(
          message: koreanErrorMessage(e),
          onRetry: () => unawaited(_search()),
        ),
      ),
      data: (result) {
        if (result.sites.isEmpty) {
          return _ScrollableMessage(
            child: AppEmpty(
              message: result.query != null && result.query!.isNotEmpty
                  ? '‘${result.query}’ 결과가 없습니다.'
                  : '검색 결과가 없습니다.',
              icon: Icons.folder_off_outlined,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _search(),
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: result.sites.length + (_loadingMore ? 1 : 0) + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                  child: Text(
                    _activeQuery.isEmpty
                        ? '현장 ${result.totalSites}곳'
                        : '‘$_activeQuery’ · 현장 ${result.totalSites}곳',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                );
              }
              final i = index - 1;
              if (i >= result.sites.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final site = result.sites[i];
              final thumb = _thumb(site);
              return _SiteCard(
                site: site,
                highlightQuery: _activeQuery,
                thumbUrl: thumb.url,
                thumbHeaders: thumb.headers,
                onTap: () => _openSite(site),
              );
            },
          ),
        );
      },
    );
  }
}

class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.highlightQuery,
    required this.thumbUrl,
    this.thumbHeaders,
    required this.onTap,
  });

  final ChecksheetSite site;
  final String highlightQuery;
  final String? thumbUrl;
  final Map<String, String>? thumbHeaders;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reg = (site.regDate != null && site.regDate!.trim().isNotEmpty)
        ? site.regDate!.trim()
        : '없음';
    final install =
        (site.installCompletedDate != null &&
            site.installCompletedDate!.trim().isNotEmpty)
        ? site.installCompletedDate!.trim()
        : '없다';
    final lineStyle = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: thumbUrl == null || thumbUrl!.isEmpty
                      ? ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.description_outlined,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : CachedAppImage(
                          url: thumbUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 160,
                          memCacheHeight: 160,
                          httpHeaders: thumbHeaders,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchHighlightText(
                      text: site.siteName,
                      query: highlightQuery,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                      highlightStyle: TextStyle(
                        backgroundColor: scheme.tertiaryContainer,
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('등록일 $reg', style: lineStyle),
                    Text(
                      '시공완료일 $install',
                      style: lineStyle.copyWith(
                        color: install == '없다'
                            ? scheme.error.withValues(alpha: 0.85)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '체크시트 ${site.checksheetCount}장',
                      style: lineStyle,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecksheetGalleryScreen extends StatefulWidget {
  const _ChecksheetGalleryScreen({
    required this.site,
    required this.highlightQuery,
    required this.resolveUrl,
    required this.headersForUrl,
    this.onDownload,
  });

  final ChecksheetSite site;
  final String highlightQuery;
  final String Function(String mediaPath) resolveUrl;
  final Map<String, String>? Function(String absoluteUrl) headersForUrl;
  final VoidCallback? onDownload;

  @override
  State<_ChecksheetGalleryScreen> createState() =>
      _ChecksheetGalleryScreenState();
}

class _ChecksheetGalleryScreenState extends State<_ChecksheetGalleryScreen> {
  void _openFull(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ChecksheetFullscreenViewer(
          site: widget.site,
          attachments: widget.site.attachments,
          initialIndex: index,
          resolveUrl: widget.resolveUrl,
          headersForUrl: widget.headersForUrl,
          onDownload: widget.onDownload,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final atts = widget.site.attachments;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: SearchHighlightText(
          text: widget.site.siteName,
          query: widget.highlightQuery,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          highlightStyle: TextStyle(
            backgroundColor: scheme.tertiaryContainer,
            color: scheme.onTertiaryContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: atts.isEmpty
          ? const AppEmpty(
              message: '이 현장의 체크시트 이미지가 없습니다.',
              icon: Icons.image_not_supported_outlined,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Text(
                    '체크시트 ${atts.length}장 · 탭하면 확대 · 다운로드',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemCount: atts.length,
                    itemBuilder: (context, i) {
                      final a = atts[i];
                      final url = widget.resolveUrl(a.mediaPath);
                      final headers = widget.headersForUrl(url);
                      return Material(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openFull(i),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedAppImage(
                                url: url,
                                fit: BoxFit.cover,
                                memCacheWidth: 480,
                                memCacheHeight: 480,
                                httpHeaders: headers,
                              ),
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${i + 1}/${atts.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChecksheetFullscreenViewer extends StatefulWidget {
  const _ChecksheetFullscreenViewer({
    required this.site,
    required this.attachments,
    required this.initialIndex,
    required this.resolveUrl,
    required this.headersForUrl,
    this.onDownload,
  });

  final ChecksheetSite site;
  final List<ChecksheetAttachment> attachments;
  final int initialIndex;
  final String Function(String mediaPath) resolveUrl;
  final Map<String, String>? Function(String absoluteUrl) headersForUrl;
  final VoidCallback? onDownload;

  @override
  State<_ChecksheetFullscreenViewer> createState() =>
      _ChecksheetFullscreenViewerState();
}

class _ChecksheetFullscreenViewerState
    extends State<_ChecksheetFullscreenViewer> {
  late final PageController _pageCtrl;
  late int _index;
  bool _downloading = false;
  final _transformationControllers = <int, TransformationController>{};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.attachments.length - 1);
    _pageCtrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _transformationControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TransformationController _controllerFor(int i) {
    return _transformationControllers.putIfAbsent(
      i,
      TransformationController.new,
    );
  }

  String _sanitizeFilePart(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]+'), '_');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(RegExp(r'_+'), '_');
    if (s.isEmpty) return '현장';
    if (s.length > 60) s = s.substring(0, 60);
    return s;
  }

  /// 파일명: `날짜_현장명` (+ 복수 시 `_2`)
  String _downloadBaseName(int index) {
    final att = widget.attachments[index];
    final dateFmt = DateFormat('yyyy-MM-dd');
    String datePart;
    if (att.uploadedAt != null) {
      datePart = dateFmt.format(att.uploadedAt!.toLocal());
    } else if (widget.site.regDate != null &&
        widget.site.regDate!.trim().isNotEmpty) {
      final rd = widget.site.regDate!.trim();
      datePart = rd.length >= 10 ? rd.substring(0, 10) : rd;
    } else if (widget.site.year != null && widget.site.month != null) {
      datePart =
          '${widget.site.year}-${widget.site.month.toString().padLeft(2, '0')}-01';
    } else {
      datePart = dateFmt.format(DateTime.now());
    }

    final sitePart = _sanitizeFilePart(widget.site.siteName);
    final base = '${datePart}_$sitePart';
    if (widget.attachments.length <= 1) return base;
    return '${base}_${index + 1}';
  }

  Future<void> _downloadCurrent() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    HapticFeedback.selectionClick();

    final index = _index;
    final att = widget.attachments[index];
    final url = widget.resolveUrl(att.mediaPath);
    final headers = widget.headersForUrl(url) ?? const <String, String>{};
    final baseName = _downloadBaseName(index);

    try {
      final res = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 60));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('download failed ${res.statusCode}');
      }
      final bytes = res.bodyBytes;
      if (bytes.isEmpty) throw Exception('empty body');

      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('갤러리 접근 권한이 필요합니다.')),
          );
          return;
        }
      }

      await Gal.putImageBytes(
        Uint8List.fromList(bytes),
        name: baseName,
      );
      widget.onDownload?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장했습니다: $baseName.jpg')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 저장에 실패했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _resetZoom() {
    _controllerFor(_index).value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.attachments.length;
    final att = widget.attachments[_index];
    final dateLabel = att.uploadedAt != null
        ? DateFormat('yyyy.MM.dd HH:mm').format(att.uploadedAt!.toLocal())
        : (widget.site.regDate ?? '');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.site.siteName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            if (dateLabel.isNotEmpty)
              Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '확대 초기화',
            onPressed: _resetZoom,
            icon: const Icon(Icons.zoom_out_map_rounded),
          ),
          IconButton(
            tooltip: '다운로드',
            onPressed: _downloading ? null : () => unawaited(_downloadCurrent()),
            icon: _downloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: total,
            onPageChanged: (i) {
              // 페이지 이동 시 이전 줌 리셋
              _controllerFor(_index).value = Matrix4.identity();
              setState(() => _index = i);
            },
            itemBuilder: (context, i) {
              final url = widget.resolveUrl(widget.attachments[i].mediaPath);
              final headers = widget.headersForUrl(url);
              return InteractiveViewer(
                transformationController: _controllerFor(i),
                minScale: 0.8,
                maxScale: 5,
                child: Center(
                  child: CachedAppImage(
                    url: url,
                    fit: BoxFit.contain,
                    memCacheWidth: 2000,
                    httpHeaders: headers,
                  ),
                ),
              );
            },
          ),
          // 갤러리 페이지 표시 1/3
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${_index + 1} / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          // 좌우 힌트(여러 장일 때만)
          if (total > 1 && _index > 0)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  tooltip: '이전',
                  onPressed: () {
                    _pageCtrl.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 36,
                  ),
                ),
              ),
            ),
          if (total > 1 && _index < total - 1)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  tooltip: '다음',
                  onPressed: () {
                    _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 36,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
