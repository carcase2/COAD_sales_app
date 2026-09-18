import 'package:coad_customer_calls/core/widgets/cached_app_image.dart';
import 'package:coad_customer_calls/data/checksheet_archive_repository.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_create_screen.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_provider.dart';
import 'package:coad_customer_calls/models/overdue_install_site.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

Future<IssuanceCreateResult?> showOverdueInstallDetailSheet({
  required BuildContext context,
  required OverdueInstallSite site,
}) {
  return showModalBottomSheet<IssuanceCreateResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _OverdueInstallDetailSheet(site: site),
  );
}

class _OverdueInstallDetailSheet extends ConsumerStatefulWidget {
  const _OverdueInstallDetailSheet({required this.site});

  final OverdueInstallSite site;

  @override
  ConsumerState<_OverdueInstallDetailSheet> createState() =>
      _OverdueInstallDetailSheetState();
}

class _OverdueInstallDetailSheetState
    extends ConsumerState<_OverdueInstallDetailSheet> {
  OverdueInstallArchive? _archive;
  bool _archiveLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    try {
      final archive = await ref
          .read(overdueInstallRepositoryProvider)
          .fetchSiteArchive(
            siteName: widget.site.displayName,
            inqNo: widget.site.inqNo,
          );
      if (!mounted) return;
      setState(() {
        _archive = archive;
        _archiveLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _archive = const OverdueInstallArchive();
        _archiveLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vat = widget.site.vatSplit;
    final site = widget.site;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              site.displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '시공완료 안 됨',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.deepOrange.shade700,
              ),
            ),
            const SizedBox(height: 12),
            if (site.hasTaxRequest)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '발행요청 ${site.taxRequestCount}건 있음. 같은 현장은 추가로 요청할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.teal.shade800,
                    height: 1.35,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '아직 발행요청이 없습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.deepOrange.shade800,
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed: () => _openTaxRequest(site),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppTokens.primaryCtaHeight),
              ),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(
                site.hasTaxRequest ? '세금계산서 추가 요청' : '세금계산서 발행 요청',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 16),
            _kv('담당자', site.assigneeKey),
            _kv('시공예정일', site.instalDt),
            if (site.custNm.isNotEmpty && site.custNm != site.siteNm)
              _kv('고객', site.custNm),
            _kv('인쿼리', site.inqNo),
            _kv('지점', site.plantNm.isEmpty ? site.plantCd : site.plantNm),
            if (site.itemCd.isNotEmpty) _kv('품목', site.itemCd),
            if ((site.itemQty ?? '').isNotEmpty) _kv('수량', site.itemQty!),
            if ((site.inqStatus ?? '').isNotEmpty) _kv('상태', site.inqStatus!),
            const Divider(height: 28),
            Text(
              '금액',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (vat == null)
              Text(
                '수주금액 정보가 없습니다.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else ...[
              _kv('공급가액', _won(vat.supply)),
              _kv('세액', _won(vat.tax)),
              _kv('합계 (부가세 포함)', _won(vat.total)),
            ],
            const Divider(height: 28),
            Text(
              '수금',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            if ((site.orderNo ?? '').isNotEmpty) _kv('수주번호', site.orderNo!),
            if (site.initialPay != null) _kv('계약금', _won(site.initialPay!)),
            if (site.paidSum != null) _kv('입금합계', _won(site.paidSum!)),
            if (site.remainPay != null) _kv('잔금', _won(site.remainPay!)),
            if ((site.receivedStatus ?? '').isNotEmpty)
              _kv('수금상태', site.receivedStatus!),
            if (site.paidSum == null &&
                site.remainPay == null &&
                site.initialPay == null)
              Text(
                site.hasUnpaidCache
                    ? '수금 금액이 없습니다.'
                    : 'MES 수금 캐시 없음 (시공완료 전). 시공완료되면 잔금·입금이 들어옵니다.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            const Divider(height: 28),
            Text(
              '현장 자료 (R2)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (_archiveLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (_archive == null || _archive!.isEmpty)
              Text(
                '이 현장의 계약완료보고서·체크시트가 없습니다.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else ...[
              if (_archive!.contracts.isNotEmpty)
                _photoStrip('계약완료보고서', _archive!.contracts),
              if (_archive!.checksheets.isNotEmpty)
                _photoStrip('체크시트', _archive!.checksheets),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openTaxRequest(OverdueInstallSite site) async {
    HapticFeedback.mediumImpact();
    final created = await Navigator.of(context).push<IssuanceCreateResult?>(
      MaterialPageRoute(
        builder: (_) => IssuanceRequestCreateScreen(
          initialDomain: IssuanceDomain.taxInvoice,
          taxPrefill: site.toTaxPrefill(),
        ),
      ),
    );
    if (!mounted || created == null) return;
    Navigator.of(context).pop(created);
  }

  Widget _photoStrip(String title, List<OverdueInstallArchivePhoto> photos) {
    final repo = ref.read(checksheetArchiveRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title ${photos.length}장',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final url = repo.absoluteMediaUrl(photos[i].mediaPath);
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _ArchiveGalleryScreen(
                          title: title,
                          photos: photos,
                          initialIndex: i,
                          resolveUrl: repo.absoluteMediaUrl,
                          headersForUrl: repo.mediaHttpHeadersForUrl,
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedAppImage(
                      url: url,
                      width: 84,
                      height: 84,
                      memCacheWidth: 200,
                      httpHeaders: repo.mediaHttpHeadersForUrl(url),
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

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _won(int n) => '${NumberFormat('#,###').format(n)}원';
}

class _ArchiveGalleryScreen extends StatefulWidget {
  const _ArchiveGalleryScreen({
    required this.title,
    required this.photos,
    required this.initialIndex,
    required this.resolveUrl,
    required this.headersForUrl,
  });

  final String title;
  final List<OverdueInstallArchivePhoto> photos;
  final int initialIndex;
  final String Function(String mediaPath) resolveUrl;
  final Map<String, String>? Function(String url) headersForUrl;

  @override
  State<_ArchiveGalleryScreen> createState() => _ArchiveGalleryScreenState();
}

class _ArchiveGalleryScreenState extends State<_ArchiveGalleryScreen> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;
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
                total == 0 ? '0' : '${_index + 1} / $total',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final url = widget.resolveUrl(widget.photos[i].mediaPath);
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(
                  child: CachedAppImage(
                    url: url,
                    fit: BoxFit.contain,
                    memCacheWidth: 2000,
                    httpHeaders: widget.headersForUrl(url),
                  ),
                ),
              );
            },
          ),
          if (total > 1 && _index > 0)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  color: Colors.white,
                  onPressed: () => _page.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
                  icon: const Icon(Icons.chevron_left_rounded, size: 36),
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
                  color: Colors.white,
                  onPressed: () => _page.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
                  icon: const Icon(Icons.chevron_right_rounded, size: 36),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
