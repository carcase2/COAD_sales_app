import 'dart:io';
import 'dart:ui' as ui;

import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_paper.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

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

class _SupportQuoteExportSheet extends StatefulWidget {
  const _SupportQuoteExportSheet({required this.doc});

  final SupportQuoteDocument doc;

  @override
  State<_SupportQuoteExportSheet> createState() =>
      _SupportQuoteExportSheetState();
}

class _SupportQuoteExportSheetState extends State<_SupportQuoteExportSheet> {
  final _paperKey = GlobalKey();
  bool _busy = false;
  final _won = NumberFormat('#,###');

  ButtonStyle get _compactActionStyle => FilledButton.styleFrom(
    minimumSize: const Size(0, 36),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );

  String get _stem => supportQuoteFileStem(widget.doc);

  String get _totalLabel {
    final n = widget.doc.total;
    return n <= 0 ? '-' : '${_won.format(n)}원';
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

  Future<void> _savePdf(Uint8List png) async {
    final pdf = await supportQuotePngToPdf(png);
    await FileSaver.instance.saveFile(
      name: _stem,
      bytes: pdf,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('견적서 PDF를 저장했습니다.')));
    Navigator.of(context).pop(SupportQuoteViewAction.sent);
  }

  Future<void> _emailPdf(Uint8List png) async {
    final pdf = await supportQuotePngToPdf(png);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$_stem.pdf';
    await File(path).writeAsBytes(pdf, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/pdf', name: '$_stem.pdf')],
        subject: supportQuoteEmailSubject(widget.doc),
        text: supportQuoteEmailBody(widget.doc, totalLabel: _totalLabel),
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
            const SizedBox(height: 4),
            Text(
              '${widget.doc.customerName} · 보기 · 이미지·PDF·이메일',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Material(
              color: (widget.doc.isSent ? AppTokens.success(scheme) : scheme.error)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      widget.doc.isSent
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                      size: 18,
                      color: widget.doc.isSent
                          ? AppTokens.success(scheme)
                          : scheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.doc.isSent
                            ? '발송완료 ${widget.doc.sentYmd!.trim()}'
                            : '미발송 · 작성만 된 상태입니다',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: widget.doc.isSent
                              ? AppTokens.success(scheme)
                              : scheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(
                              widget.doc.isSent
                                  ? SupportQuoteViewAction.unsent
                                  : SupportQuoteViewAction.sent,
                            ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        widget.doc.isSent ? '미발송으로' : '발송완료로',
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
                child: Center(
                  child: FittedBox(
                    child: RepaintBoundary(
                      key: _paperKey,
                      child: SupportQuotePaper(doc: widget.doc),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(_saveImage),
                    style: _compactActionStyle,
                    icon: const Icon(Icons.photo_outlined, size: 16),
                    label: const Text('이미지'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(_savePdf),
                    style: _compactActionStyle,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('PDF'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            _run(_emailPdf);
                          },
                    style: _compactActionStyle,
                    icon: _busy
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.email_outlined, size: 16),
                    label: const Text('이메일'),
                  ),
                ),
              ],
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
