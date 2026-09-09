import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/size_quote_repository.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_paper.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<Uint8List> sizeQuoteToPdf({
  required Uint8List quotePng,
  List<Uint8List> promoImages = const [],
}) async {
  final doc = pw.Document();
  final quote = pw.MemoryImage(quotePng);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Center(child: pw.Image(quote, fit: pw.BoxFit.contain)),
    ),
  );
  for (final bytes in promoImages) {
    if (bytes.isEmpty) continue;
    final image = pw.MemoryImage(bytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
  }
  return doc.save();
}

enum SizeQuoteViewAction { close, sent, unsent, edit }

Future<SizeQuoteViewAction> showSizeQuoteExportSheet(
  BuildContext context, {
  required SizeQuoteDocument doc,
}) async {
  final result = await showModalBottomSheet<SizeQuoteViewAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: false,
    builder: (_) => _SizeQuoteExportSheet(doc: doc),
  );
  return result ?? SizeQuoteViewAction.close;
}

Future<bool> showSizeQuotePreviewSheet(
  BuildContext context, {
  required SizeQuoteDocument doc,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: false,
    builder: (_) => _SizeQuotePreviewSheet(doc: doc),
  );
  return result == true;
}

class _SizeQuotePreviewSheet extends StatelessWidget {
  const _SizeQuotePreviewSheet({required this.doc});

  final SizeQuoteDocument doc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom + media.viewInsets.bottom;
    final audit = sizeQuoteAuditLine(doc);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.86 - bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '견적서 미리보기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              audit.isEmpty ? '저장·발송 전 확인용입니다' : audit,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            if (doc.promoImageIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '홍보 이미지 ${doc.promoImageIds.length}장 · PDF 다음장',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Center(
                  child: FittedBox(child: SizeQuotePaper(doc: doc)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('닫기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('저장하고 보내기', maxLines: 1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeQuoteExportSheet extends ConsumerStatefulWidget {
  const _SizeQuoteExportSheet({required this.doc});

  final SizeQuoteDocument doc;

  @override
  ConsumerState<_SizeQuoteExportSheet> createState() =>
      _SizeQuoteExportSheetState();
}

class _SizeQuoteExportSheetState extends ConsumerState<_SizeQuoteExportSheet> {
  final _paperKey = GlobalKey();
  bool _busy = false;
  late SizeQuoteDocument _doc;
  final _won = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
  }

  SizeQuoteRepository get _repo => ref.read(sizeQuoteRepositoryProvider);

  ButtonStyle get _compactActionStyle => FilledButton.styleFrom(
    minimumSize: const Size(0, 36),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );

  String get _stem => sizeQuoteFileStem(_doc);

  String get _totalLabel {
    final n = _doc.total;
    return n <= 0 ? '-' : '${_won.format(n)}원';
  }

  String? get _editorName {
    final user = ref.read(authControllerProvider);
    return user?.name ?? user?.id;
  }

  Future<Uint8List?> _capturePng() async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final boundary =
        _paperKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.6);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Future<List<Uint8List>> _promoBytes() async {
    if (_doc.promoImageIds.isEmpty) return const [];
    try {
      final images = await _repo.listPromoImagesByIds(_doc.promoImageIds);
      final out = <Uint8List>[];
      for (final image in images) {
        try {
          out.add(await _repo.downloadPromoBytes(image.storagePath));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _run(Future<void> Function(Uint8List png) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _capturePng();
      if (png == null || png.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('견적서 이미지를 만들지 못했습니다.')),
        );
        return;
      }
      await action(png);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _writePdfFile(Uint8List png) async {
    final pdf = await sizeQuoteToPdf(
      quotePng: png,
      promoImages: await _promoBytes(),
    );
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/size_quotes');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/$_stem.pdf');
    await file.writeAsBytes(pdf, flush: true);
    return file;
  }

  Future<void> _uploadCloudPdf(
    File file, {
    required bool markSent,
    bool markEmail = false,
  }) async {
    final bytes = await file.readAsBytes();
    final saved = await _repo.uploadPdf(
      _doc,
      bytes: Uint8List.fromList(bytes),
      editorName: _editorName,
      markSent: markSent,
      markEmail: markEmail,
    );
    if (!mounted) return;
    setState(() => _doc = saved);
  }

  Future<void> _openCloudPdf() async {
    final url = _repo.publicPdfUrl(_doc);
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클라우드 PDF를 열지 못했습니다.')),
      );
    }
  }

  Future<void> _saveImage(Uint8List png) async {
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
    await Gal.putImageBytes(png, name: '$_stem.png');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('견적서 이미지를 앨범에 저장했습니다.')),
    );
  }

  Future<void> _savePdf(Uint8List png) async {
    final file = await _writePdfFile(png);
    await _uploadCloudPdf(file, markSent: false);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'application/pdf', name: '$_stem.pdf'),
        ],
        subject: sizeQuoteEmailSubject(_doc),
        text:
            '${sizeQuoteEmailBody(_doc, totalLabel: _totalLabel)}\n\n'
            '파일 앱·다운로드에서 이 PDF를 저장하거나 열어 보세요.',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF를 클라우드에 저장했습니다. 기록에서 다시 열 수 있습니다.')),
    );
    Navigator.of(context).pop(SizeQuoteViewAction.sent);
  }

  Future<void> _emailPdf(Uint8List png) async {
    final file = await _writePdfFile(png);
    await _uploadCloudPdf(file, markSent: true, markEmail: true);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'application/pdf', name: '$_stem.pdf'),
        ],
        subject: sizeQuoteEmailSubject(_doc),
        text: sizeQuoteEmailBody(_doc, totalLabel: _totalLabel),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(SizeQuoteViewAction.sent);
  }

  Future<void> _shareImage(Uint8List png) async {
    final root = await getTemporaryDirectory();
    final file = File('${root.path}/$_stem.png');
    await file.writeAsBytes(png, flush: true);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'image/png', name: '$_stem.png'),
        ],
        subject: sizeQuoteEmailSubject(_doc),
        text: sizeQuoteEmailBody(_doc, totalLabel: _totalLabel),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(SizeQuoteViewAction.sent);
  }

  Future<void> _markSentAndClose({required bool sent}) async {
    final user = ref.read(authControllerProvider);
    try {
      final stored = await _repo.upsert(
        sent
            ? _doc.copyWith(sentYmd: todayYmdSeoul())
            : _doc.copyWith(clearSentYmd: true),
        editorName: user?.name ?? user?.id,
      );
      if (mounted) setState(() => _doc = stored);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(
      sent ? SizeQuoteViewAction.sent : SizeQuoteViewAction.unsent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom + media.viewInsets.bottom;
    final audit = sizeQuoteAuditLine(_doc);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.86 - bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '견적서',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              [
                if (_doc.site.trim().isNotEmpty) _doc.site.trim(),
                if (_doc.modelName.trim().isNotEmpty) _doc.modelName.trim(),
                '이미지 · PDF · 메일',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            if (audit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  audit,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Material(
              color: (_doc.isEmailSent
                      ? AppTokens.success(scheme)
                      : (_doc.isSent ? scheme.primary : scheme.error))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                child: Row(
                  children: [
                    Icon(
                      _doc.isEmailSent
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                      size: 16,
                      color: _doc.isEmailSent
                          ? AppTokens.success(scheme)
                          : (_doc.isSent ? scheme.primary : scheme.error),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _doc.isEmailSent
                            ? '메일 발송 ${(_doc.emailSentYmd ?? '').trim()}'
                            : (_doc.isSent
                                  ? '발송 ${(_doc.sentYmd ?? '').trim()}'
                                  : '미발송'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _doc.isEmailSent
                              ? AppTokens.success(scheme)
                              : (_doc.isSent ? scheme.primary : scheme.error),
                        ),
                      ),
                    ),
                    if (_doc.hasCloudPdf)
                      TextButton(
                        onPressed: _busy ? null : _openCloudPdf,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'PDF 열기',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _markSentAndClose(sent: !_doc.isSent),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _doc.isSent ? '미발송으로' : '발송완료로',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: FittedBox(
                        child: RepaintBoundary(
                          key: _paperKey,
                          child: SizeQuotePaper(doc: _doc),
                        ),
                      ),
                    ),
                    if (_doc.promoImageIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '홍보 이미지 ${_doc.promoImageIds.length}장 · PDF 다음장에 붙습니다',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _run(_savePdf),
                    style: _compactActionStyle,
                    icon: _busy
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('PDF'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(_emailPdf),
                    style: _compactActionStyle,
                    icon: const Icon(Icons.mail_outline_rounded, size: 16),
                    label: const Text('메일'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(_shareImage),
                    style: _compactActionStyle,
                    icon: const Icon(Icons.ios_share_rounded, size: 16),
                    label: const Text('이미지'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(_saveImage),
                    style: _compactActionStyle,
                    icon: const Icon(Icons.photo_outlined, size: 16),
                    label: const Text('앨범'),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'PDF는 기록에 남고 다시 열 수 있습니다. 메일은 발송일이 따로 표시됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(SizeQuoteViewAction.edit),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('수정'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
