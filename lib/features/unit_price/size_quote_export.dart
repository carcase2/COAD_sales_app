import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/size_quote_repository.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_paper.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_spec_note.dart';
import 'package:coad_customer_calls/models/app_user.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';
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

String sizeQuoteLoginStaffLabel(AppUser? user) {
  return sizeQuoteStaffLabel(
    name: user?.name ?? '',
    title: user?.title,
    fallback: user?.id ?? '',
  );
}

/// 사용자 행의 휴대폰. 로그인 정보에 없으면 users.phone 을 읽는다.
Future<String> lookupSizeQuoteStaffPhone(String userId) async {
  final id = userId.trim();
  if (id.isEmpty) return '';
  try {
    final row = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return '';
    for (final key in const [
      'phone',
      'mobile_phone',
      'cell_phone',
      'tel',
      'telephone',
      'contact_phone',
    ]) {
      final raw = row[key];
      if (raw != null && raw.toString().trim().isNotEmpty) {
        return raw.toString().trim();
      }
    }
  } catch (_) {}
  return '';
}

/// 저장된 작성자가 없거나 로그인 아이디만 있으면 지금 로그인한 사람 이름을 쓴다.
String sizeQuoteShownManager({
  required String? createdBy,
  required AppUser? user,
}) {
  final staff = sizeQuoteLoginStaffLabel(user);
  final stored = (createdBy ?? '').trim();
  final id = user?.id.trim() ?? '';
  if (stored.isEmpty) return staff;
  if (id.isNotEmpty && stored == id && staff.isNotEmpty) return staff;
  return stored;
}

Future<SizeQuoteViewAction> showSizeQuoteExportSheet(
  BuildContext context, {
  required SizeQuoteDocument doc,
}) async {
  final result = await showModalBottomSheet<SizeQuoteViewAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    enableDrag: false,
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
    enableDrag: false,
    useSafeArea: false,
    builder: (_) => _SizeQuotePreviewSheet(doc: doc),
  );
  return result == true;
}

class _SizeQuotePreviewSheet extends ConsumerStatefulWidget {
  const _SizeQuotePreviewSheet({required this.doc});

  final SizeQuoteDocument doc;

  @override
  ConsumerState<_SizeQuotePreviewSheet> createState() =>
      _SizeQuotePreviewSheetState();
}

class _SizeQuotePreviewSheetState extends ConsumerState<_SizeQuotePreviewSheet> {
  String _phone = '';
  SizeQuoteNoteBook? _notes;
  List<QuoteBranchContact> _branches = const [];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider);
    final cached = (user?.phone ?? '').trim();
    if (cached.isNotEmpty) {
      _phone = cached;
    } else {
      unawaited(_loadPhone(user?.id ?? ''));
    }
    unawaited(_loadNotes());
    unawaited(_loadBranches());
  }

  Future<void> _loadBranches() async {
    try {
      final rows = await ref
          .read(sizeQuoteRepositoryProvider)
          .loadQuoteBranchContacts();
      if (!mounted) return;
      setState(() => _branches = rows);
    } catch (_) {}
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await ref.read(sizeQuoteRepositoryProvider).loadQuoteNotes();
      if (!mounted) return;
      setState(() => _notes = notes);
    } catch (_) {}
  }

  Future<void> _loadPhone(String userId) async {
    final phone = await lookupSizeQuoteStaffPhone(userId);
    if (!mounted || phone.isEmpty) return;
    setState(() => _phone = phone);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom + media.viewInsets.bottom;
    final user = ref.watch(authControllerProvider);
    final staff = sizeQuoteLoginStaffLabel(user);
    final manager = sizeQuoteManagerLine(
      staff.isNotEmpty
          ? staff
          : sizeQuoteShownManager(createdBy: doc.createdBy, user: user),
      _phone.isNotEmpty ? _phone : user?.phone,
    );
    final audit = sizeQuoteAuditLine(doc);
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 12 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.92 - bottomInset,
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
            Text(
              '두 손가락으로 확대 · 한 손가락으로 이동',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
            const SizedBox(height: 8),
            Flexible(
              child: _SizeQuotePaperViewer(
                child: SizeQuotePaper(
                  doc: doc,
                  managerName: manager,
                  branchName: user?.branchName,
                  office: sizeQuoteOfficeFor(user?.branchName, _branches),
                  notes: _notes,
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
  String _phone = '';
  SizeQuoteNoteBook? _notes;
  List<QuoteBranchContact> _branches = const [];

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
    final user = ref.read(authControllerProvider);
    final cached = (user?.phone ?? '').trim();
    if (cached.isNotEmpty) {
      _phone = cached;
    } else {
      unawaited(_loadPhone(user?.id ?? ''));
    }
    unawaited(_loadNotes());
    unawaited(_loadBranches());
  }

  Future<void> _loadBranches() async {
    try {
      final rows = await ref
          .read(sizeQuoteRepositoryProvider)
          .loadQuoteBranchContacts();
      if (!mounted) return;
      setState(() => _branches = rows);
    } catch (_) {}
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await ref.read(sizeQuoteRepositoryProvider).loadQuoteNotes();
      if (!mounted) return;
      setState(() => _notes = notes);
    } catch (_) {}
  }

  Future<void> _loadPhone(String userId) async {
    final phone = await lookupSizeQuoteStaffPhone(userId);
    if (!mounted || phone.isEmpty) return;
    setState(() => _phone = phone);
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
    final label = sizeQuoteLoginStaffLabel(ref.read(authControllerProvider));
    return label.isEmpty ? null : label;
  }

  String get _managerName {
    final user = ref.read(authControllerProvider);
    return sizeQuoteManagerLine(
      sizeQuoteShownManager(createdBy: _doc.createdBy, user: user),
      _phone.isNotEmpty ? _phone : user?.phone,
    );
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
    try {
      final stored = await _repo.upsert(
        sent
            ? _doc.copyWith(sentYmd: todayYmdSeoul())
            : _doc.copyWith(clearSentYmd: true),
        editorName: _editorName,
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
      padding: EdgeInsets.fromLTRB(8, 0, 8, 12 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.92 - bottomInset,
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
            Text(
              '두 손가락으로 확대 · 한 손가락으로 이동',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Column(
                children: [
                  Expanded(
                    child: _SizeQuotePaperViewer(
                      child: RepaintBoundary(
                        key: _paperKey,
                        child: SizeQuotePaper(
                          doc: _doc,
                          managerName: _managerName,
                          branchName: ref.read(authControllerProvider)?.branchName,
                          office: sizeQuoteOfficeFor(
                            ref.read(authControllerProvider)?.branchName,
                            _branches,
                          ),
                          notes: _notes,
                        ),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(
                            SizeQuoteViewAction.close,
                          ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('뒤로'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(
                            SizeQuoteViewAction.edit,
                          ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('수정'),
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

/// 화면 안에 견적서 전체가 들어오도록 맞춘 변환.
/// 오른쪽이 잘리지 않게 가로·세로 중 더 작은 배율을 쓴다.
Matrix4 sizeQuoteFitMatrix({required Size view, required Size paper}) {
  if (view.width <= 0 ||
      view.height <= 0 ||
      paper.width <= 0 ||
      paper.height <= 0) {
    return Matrix4.identity();
  }
  final scale = math.min(view.width / paper.width, view.height / paper.height);
  final dx = (view.width - paper.width * scale) / 2;
  final dy = (view.height - paper.height * scale) / 2;
  return Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1)
    ..scaleByDouble(scale, scale, scale, 1);
}

/// 처음에는 견적서 전체를 보여주고, 두 손가락으로 확대한 뒤 이동할 수 있다.
class _SizeQuotePaperViewer extends StatefulWidget {
  const _SizeQuotePaperViewer({required this.child});

  final Widget child;

  @override
  State<_SizeQuotePaperViewer> createState() => _SizeQuotePaperViewerState();
}

class _SizeQuotePaperViewerState extends State<_SizeQuotePaperViewer> {
  final _controller = TransformationController();
  final _childKey = GlobalKey();
  double _minScale = 0.05;
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fit() {
    if (!mounted || _fitted) return;
    final view = context.findRenderObject() as RenderBox?;
    final child = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (view == null ||
        child == null ||
        !view.hasSize ||
        !child.hasSize ||
        view.size.width <= 0 ||
        child.size.width <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
      return;
    }
    final matrix = sizeQuoteFitMatrix(view: view.size, paper: child.size);
    final scale = matrix.getMaxScaleOnAxis();
    _controller.value = matrix;
    setState(() {
      _minScale = scale;
      _fitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedOpacity(
        opacity: _fitted ? 1 : 0,
        duration: const Duration(milliseconds: 80),
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: _minScale,
          maxScale: 5,
          constrained: false,
          alignment: Alignment.topLeft,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          clipBehavior: Clip.hardEdge,
          panEnabled: true,
          scaleEnabled: true,
          child: KeyedSubtree(key: _childKey, child: widget.child),
        ),
      ),
    );
  }
}
