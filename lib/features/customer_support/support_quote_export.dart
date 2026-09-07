import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_paper.dart';
import 'package:coad_customer_calls/features/customer_support/support_today_desk.dart';
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

Future<Uint8List> supportQuotePngToPdf(Uint8List pngBytes) async {
  final doc = pw.Document();
  final image = pw.MemoryImage(pngBytes);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
    ),
  );
  return doc.save();
}

enum SupportQuoteViewAction { close, sent, unsent, edit }

Future<SupportQuoteViewAction> showSupportQuoteExportSheet(
  BuildContext context, {
  required SupportQuoteDocument doc,
}) async {
  final result = await showModalBottomSheet<SupportQuoteViewAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: false,
    builder: (_) => _SupportQuoteExportSheet(doc: doc),
  );
  return result ?? SupportQuoteViewAction.close;
}

/// 작성 중 견적서 미리보기 (저장·발송 전).
/// `true`면 미리보기에서 「저장하고 보내기」를 선택한 것.
Future<bool> showSupportQuotePreviewSheet(
  BuildContext context, {
  required SupportQuoteDocument doc,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: false,
    builder: (_) => _SupportQuotePreviewSheet(doc: doc),
  );
  return result == true;
}

class _SupportQuotePreviewSheet extends StatelessWidget {
  const _SupportQuotePreviewSheet({required this.doc});

  final SupportQuoteDocument doc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom + media.viewInsets.bottom;
    final audit = supportQuoteAuditLine(doc);
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
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: FittedBox(child: SupportQuotePaper(doc: doc)),
                    ),
                    if (doc.editHistory.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _SupportQuoteEditHistory(doc: doc),
                    ],
                  ],
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
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '저장하고 보내기',
                        maxLines: 1,
                        softWrap: false,
                      ),
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

class _SupportQuoteEditHistory extends StatelessWidget {
  const _SupportQuoteEditHistory({required this.doc});

  final SupportQuoteDocument doc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = doc.editHistory.reversed.take(12).toList();
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '수정 이력',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          for (final e in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${_shortAt(e.at)} · ${e.by}\n${e.summary}',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _shortAt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _SupportQuoteExportSheet extends ConsumerStatefulWidget {
  const _SupportQuoteExportSheet({required this.doc});

  final SupportQuoteDocument doc;

  @override
  ConsumerState<_SupportQuoteExportSheet> createState() =>
      _SupportQuoteExportSheetState();
}

class _SupportQuoteExportSheetState
    extends ConsumerState<_SupportQuoteExportSheet> {
  final _paperKey = GlobalKey();
  bool _busy = false;
  late SupportQuoteDocument _doc;
  final _won = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
  }

  ButtonStyle get _compactActionStyle => FilledButton.styleFrom(
    minimumSize: const Size(0, 36),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );

  String get _stem => supportQuoteFileStem(_doc);

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

  Future<void> _run(Future<void> Function(Uint8List png) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final png = await _capturePng();
      if (png == null || png.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('견적서 이미지를 만들지 못했습니다.')));
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
    final pdf = await supportQuotePngToPdf(png);
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/as_quotes');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/$_stem.pdf');
    await file.writeAsBytes(pdf, flush: true);
    return file;
  }

  Future<void> _uploadCloudPdf(File file, {required bool markSent}) async {
    final bytes = await file.readAsBytes();
    final saved = await ref
        .read(supportAsQuoteRepositoryProvider)
        .uploadPdf(
          _doc,
          bytes: Uint8List.fromList(bytes),
          editorName: _editorName,
          markSent: markSent,
        );
    if (!mounted) return;
    setState(() => _doc = saved);
    if (markSent) {
      await _syncReceptionQuoteSent(sentYmd: saved.sentYmd ?? todayYmdSeoul());
    }
  }

  /// 홈 미발송은 접수 상담 문구를 보므로, 견적서 발송 시 같이 맞춘다.
  Future<void> _syncReceptionQuoteSent({required String sentYmd}) async {
    final logId = (_doc.callLogId ?? '').trim();
    if (logId.isEmpty) return;
    try {
      final user = ref.read(authControllerProvider);
      await ref.read(supportCallLogRepositoryProvider).markLatestQuoteSentForCallLog(
        logId,
        sentYmd: sentYmd,
        createdBy: user?.name ?? user?.id,
      );
      unawaited(refreshSupportDueReminders(ref));
      ref.invalidate(supportTodayDeskProvider);
    } catch (_) {}
  }

  Future<void> _markSentAndClose() async {
    final day = todayYmdSeoul();
    try {
      final user = ref.read(authControllerProvider);
      final stored = await ref.read(supportAsQuoteRepositoryProvider).upsert(
        _doc.copyWith(sentYmd: day),
        editorName: user?.name ?? user?.id,
      );
      if (mounted) setState(() => _doc = stored);
      await _syncReceptionQuoteSent(sentYmd: day);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(SupportQuoteViewAction.sent);
  }

  Future<void> _openCloudPdf() async {
    final url = ref.read(supportAsQuoteRepositoryProvider).publicPdfUrl(_doc);
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('클라우드 PDF를 열지 못했습니다.')));
    }
  }

  Future<void> _saveImage(Uint8List png) async {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('갤러리 접근 권한이 필요합니다.')));
        return;
      }
    }
    await Gal.putImageBytes(png, name: '$_stem.png');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('견적서 이미지를 앨범에 저장했습니다.')));
    Navigator.of(context).pop(SupportQuoteViewAction.sent);
  }

  /// 클라우드에 PDF+메타를 저장한 뒤, 파일 앱·메일로 공유한다.
  Future<void> _savePdf(Uint8List png) async {
    final file = await _writePdfFile(png);
    await _uploadCloudPdf(file, markSent: true);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'application/pdf', name: '$_stem.pdf'),
        ],
        subject: supportQuoteEmailSubject(_doc),
        text:
            '${supportQuoteEmailBody(_doc, totalLabel: _totalLabel)}\n\n'
            '파일 앱·다운로드·메일에서 이 PDF를 저장하거나 열어 보세요.',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'PDF를 클라우드에 저장했습니다. 생성일·작성자·수정자·발송일이 함께 남습니다.',
        ),
      ),
    );
    Navigator.of(context).pop(SupportQuoteViewAction.sent);
  }

  Future<void> _emailPdf(Uint8List png) async {
    final file = await _writePdfFile(png);
    await _uploadCloudPdf(file, markSent: true);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'application/pdf', name: '$_stem.pdf'),
        ],
        subject: supportQuoteEmailSubject(_doc),
        text: supportQuoteEmailBody(_doc, totalLabel: _totalLabel),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(SupportQuoteViewAction.sent);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    // Android 3버튼/제스처 바 + 키보드 모두 피한다.
    final bottomInset = media.viewPadding.bottom + media.viewInsets.bottom;
    final audit = supportQuoteAuditLine(_doc);
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
              _doc.customerName.trim().isEmpty
                  ? 'PDF 저장 · 공유 · 앨범(이미지)'
                  : '${_doc.customerName.trim()} · PDF 저장 · 공유',
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
              color: (_doc.isSent ? AppTokens.success(scheme) : scheme.error)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                child: Row(
                  children: [
                    Icon(
                      _doc.isSent
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                      size: 16,
                      color: _doc.isSent
                          ? AppTokens.success(scheme)
                          : scheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _doc.isSent
                            ? '발송완료 ${(_doc.sentYmd ?? '').trim()}'
                            : '미발송',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: _doc.isSent
                              ? AppTokens.success(scheme)
                              : scheme.error,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'PDF 열기',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (_doc.isSent) {
                                Navigator.of(context).pop(
                                  SupportQuoteViewAction.unsent,
                                );
                              } else {
                                _markSentAndClose();
                              }
                            },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          child: SupportQuotePaper(doc: _doc),
                        ),
                      ),
                    ),
                    if (_doc.editHistory.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _SupportQuoteEditHistory(doc: _doc),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            _run(_savePdf);
                          },
                    style: _compactActionStyle,
                    icon: _busy
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('PDF 저장'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(_emailPdf),
                    style: _compactActionStyle,
                    icon: const Icon(Icons.ios_share_rounded, size: 16),
                    label: const Text('공유'),
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
                'PDF 저장·공유 시 클라우드에도 올리고, 생성일·작성자·수정자·발송일을 함께 저장합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(SupportQuoteViewAction.edit),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('수정'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(SupportQuoteViewAction.close),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
