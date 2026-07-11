import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/features/quoter/quoter_formatters.dart';
import 'package:coad_customer_calls/models/estimate_document.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EstimateWriterScreen extends ConsumerStatefulWidget {
  const EstimateWriterScreen({super.key});

  @override
  ConsumerState<EstimateWriterScreen> createState() =>
      _EstimateWriterScreenState();
}

class _EstimateWriterScreenState extends ConsumerState<EstimateWriterScreen> {
  final _searchController = TextEditingController();
  final _krw = NumberFormat.currency(
    locale: 'ko_KR',
    symbol: '₩',
    decimalDigits: 0,
  );

  List<EstimateDocument> _items = const [];
  bool _loading = true;

  static const List<String> _defaultCategories = <String>[
    '자동문',
    '오버헤드도어',
    '차고문',
    '셔터',
    '기타',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(estimateDocumentRepositoryProvider);
    final docs = await repo.list(query: _searchController.text);
    if (!mounted) return;
    setState(() {
      _items = docs;
      _loading = false;
    });
  }

  String _genId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return 'est_$now$rand';
  }

  List<String> _dynamicFieldKeys(String category, String modelName) {
    final normalized = '$category $modelName';
    if (normalized.contains('자동문')) return const ['프레임 색상', '유리 사양', '센서 종류'];
    if (normalized.contains('오버헤드')) return const ['패널 두께', '레일 길이', '모터 브랜드'];
    if (normalized.contains('차고문')) return const ['리모컨 수량', '보온등급', '설치 위치'];
    if (normalized.contains('셔터')) return const ['슬랫 규격', '모터 용량', '방화 여부'];
    return const ['추가 사양 1', '추가 사양 2'];
  }

  String _generateQuoteNumber() {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'EST-$stamp';
  }

  String _formatCreatedAt(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }

  String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>| ]+'), '_');
  }

  Widget _buildEstimateExportPaper(EstimateDocument item) {
    final fields = item.customFields;
    final extrasTotal = item.extraItems.fold<int>(
      0,
      (sum, e) => sum + (e.amount * e.quantity),
    );
    final siteManagerSign = fields['현장담당자 서명'] ?? '';
    final staffSign = fields['등록자 담당자 서명'] ?? '';
    Uint8List? decodeSign(String raw) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      try {
        return base64Decode(text);
      } catch (_) {
        return null;
      }
    }

    final siteSignBytes = decodeSign(siteManagerSign);
    final staffSignBytes = decodeSign(staffSign);
    Widget signBox(String label, Uint8List? bytes) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: bytes == null
                ? const Center(
                    child: Text('서명 없음', style: TextStyle(fontSize: 12)),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
          ),
        ],
      );
    }

    Widget line(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
    }

    return Container(
      width: 380,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(
            child: Text(
              '견 적 서',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          line('견적번호', fields['견적번호'] ?? item.id),
          line('작성일자', fields['작성일자'] ?? _formatCreatedAt(item.createdAt)),
          line('받는사람', fields['기본 받는 사람'] ?? item.customerName),
          line('현장명', item.siteName),
          line('카테고리/모델', '${item.category} / ${item.modelName}'),
          line(
            '규격',
            '${item.widthMm} x ${item.heightMm} mm / ${item.quantity}개',
          ),
          const Divider(height: 16),
          line('기본 금액', _krw.format(item.baseAmount)),
          ...item.extraItems.map(
            (e) => line(
              '${e.name} (${e.quantity}개)',
              _krw.format(e.amount * e.quantity),
            ),
          ),
          const Divider(height: 16),
          line('총 금액', _krw.format(item.baseAmount + extrasTotal)),
          const SizedBox(height: 8),
          if (item.memo.trim().isNotEmpty) line('메모', item.memo.trim()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: signBox('현장담당자 서명', siteSignBytes)),
              const SizedBox(width: 8),
              Expanded(child: signBox('등록자 담당자 서명', staffSignBytes)),
            ],
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _captureBoundary(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveEstimateImage(
    Uint8List bytes,
    EstimateDocument item,
  ) async {
    final filename =
        '견적서_${_safeFileName(item.siteName)}_${DateTime.now().millisecondsSinceEpoch}';
    await FileSaver.instance.saveFile(
      name: filename,
      bytes: bytes,
      fileExtension: 'png',
      mimeType: MimeType.png,
    );
  }

  Future<void> _shareEstimateImage(
    Uint8List bytes,
    EstimateDocument item,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/estimate_${item.id}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: '[견적서] ${item.siteName}'),
    );
  }

  Future<void> _openExportSheet(EstimateDocument item) async {
    final imageKey = GlobalKey();
    bool busy = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> runAction(
              Future<void> Function(Uint8List bytes) action,
            ) async {
              setModalState(() => busy = true);
              try {
                await Future<void>.delayed(const Duration(milliseconds: 30));
                final bytes = await _captureBoundary(imageKey);
                if (bytes == null || bytes.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('이미지 생성에 실패했습니다.')),
                  );
                  return;
                }
                await action(bytes);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(SnackBar(content: Text('처리 중 오류: $e')));
                }
              } finally {
                if (context.mounted) setModalState(() => busy = false);
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '견적서 이미지',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: RepaintBoundary(
                          key: imageKey,
                          child: _buildEstimateExportPaper(item),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => runAction(
                                    (bytes) => _saveEstimateImage(bytes, item),
                                  ),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('이미지 저장'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () => runAction(
                                    (bytes) => _shareEstimateImage(bytes, item),
                                  ),
                            icon: busy
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.share_rounded),
                            label: Text(busy ? '처리 중...' : '공유하기'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _signaturePreview(String base64Data, ColorScheme scheme) {
    if (base64Data.trim().isEmpty) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '서명 없음',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    try {
      final bytes = base64Decode(base64Data);
      return Container(
        height: 72,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      );
    } catch (_) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.error),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '서명 데이터 오류',
            style: TextStyle(
              color: scheme.error,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
  }

  Future<String?> _openSignatureDialog({
    required String title,
    String? initialBase64,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _SignaturePadDialog(title: title, initialBase64: initialBase64),
    );
  }

  Future<String> _resolveCurrentUserPhone() async {
    final loginUser = ref.read(authControllerProvider);
    if (loginUser == null || loginUser.id.trim().isEmpty) return '';
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', loginUser.id)
          .maybeSingle();
      if (row == null) return '';
      final keys = [
        'phone',
        'mobile_phone',
        'cell_phone',
        'tel',
        'telephone',
        'contact_phone',
      ];
      for (final key in keys) {
        final raw = row[key];
        if (raw != null && raw.toString().trim().isNotEmpty) {
          return raw.toString().trim();
        }
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _openForm([EstimateDocument? existing]) async {
    final customerController = TextEditingController(
      text: existing?.customerName ?? '',
    );
    final siteController = TextEditingController(
      text: existing?.siteName ?? '',
    );
    final categoryController = TextEditingController(
      text: existing?.category ?? _defaultCategories.first,
    );
    final modelController = TextEditingController(
      text: existing?.modelName ?? '',
    );
    final baseAmountController = TextEditingController(
      text: existing == null ? '' : existing.baseAmount.toString(),
    );
    final widthController = TextEditingController(
      text: existing == null ? '' : existing.widthMm.toString(),
    );
    final heightController = TextEditingController(
      text: existing == null ? '' : existing.heightMm.toString(),
    );
    final quantityController = TextEditingController(
      text: existing == null ? '1' : existing.quantity.toString(),
    );
    final memoController = TextEditingController(text: existing?.memo ?? '');
    final extras = [...(existing?.extraItems ?? const <EstimateExtraItem>[])];
    final customFields = Map<String, String>.from(
      existing?.customFields ?? const {},
    );
    final loginUser = ref.read(authControllerProvider);
    final defaultRegistrantName = loginUser?.name ?? '';
    final defaultRegistrantPhone = await _resolveCurrentUserPhone();
    final prefs = ref.read(appDependenciesProvider).prefs;
    final loginUserId = loginUser?.id.trim() ?? '';
    final staffSignatureKey = 'estimate_staff_signature_$loginUserId';
    String siteManagerSignature = customFields['현장담당자 서명'] ?? '';
    String staffSignature =
        customFields['등록자 담당자 서명'] ??
        (loginUserId.isEmpty ? '' : (prefs.getString(staffSignatureKey) ?? ''));

    customFields.putIfAbsent('기본 받는 사람', () => '귀하');
    customFields.putIfAbsent('고상명', () => '');
    customFields.putIfAbsent('담당자', () => '');
    customFields.putIfAbsent('담당자 전화번호', () => '');
    customFields.putIfAbsent('휴대폰번호', () => '');
    customFields.putIfAbsent('팩스 번호', () => '');
    customFields.putIfAbsent('e-mail', () => '');
    customFields.putIfAbsent('견적번호', _generateQuoteNumber);
    customFields.putIfAbsent('납기', () => '발주 후 15일');
    customFields.putIfAbsent('유효기간', () => '견적 후 10일 이내');
    customFields.putIfAbsent('등록자 지사주소', () => '');
    customFields.putIfAbsent('등록자 전화번호', () => '');
    customFields.putIfAbsent('등록자 팩스번호', () => '');
    customFields.putIfAbsent('등록자 홈페이지 주소', () => '');
    customFields.putIfAbsent('등록자 e-mail주소', () => '');
    customFields.putIfAbsent('등록자 담당자이름', () => defaultRegistrantName);
    customFields.putIfAbsent('등록자 담당자 전화번호', () => defaultRegistrantPhone);

    if (!mounted) return;
    bool isSaving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final fields = _dynamicFieldKeys(
              categoryController.text,
              modelController.text,
            );
            for (final key in fields) {
              customFields.putIfAbsent(key, () => '');
            }
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              existing == null ? '견적서 작성' : '견적서 수정',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _defaultCategories
                                  .map(
                                    (cat) => ChoiceChip(
                                      label: Text(cat),
                                      selected: categoryController.text == cat,
                                      onSelected: (_) => setModalState(
                                        () => categoryController.text = cat,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: categoryController,
                              decoration: const InputDecoration(
                                labelText: '카테고리(직접 입력/수정 가능)',
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                            TextField(
                              controller: modelController,
                              decoration: const InputDecoration(
                                labelText: '모델명',
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                            TextField(
                              controller: customerController,
                              decoration: const InputDecoration(
                                labelText: '고객명',
                              ),
                              onChanged: (v) {
                                final current = (customFields['기본 받는 사람'] ?? '')
                                    .trim();
                                if (current.isEmpty || current == '귀하') {
                                  customFields['기본 받는 사람'] = v.trim().isEmpty
                                      ? '귀하'
                                      : '${v.trim()} 귀하';
                                  setModalState(() {});
                                }
                              },
                            ),
                            TextField(
                              controller: siteController,
                              decoration: const InputDecoration(
                                labelText: '현장명 *',
                              ),
                            ),
                            TextField(
                              controller: baseAmountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                const ThousandsFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText: '기본 금액',
                              ),
                            ),
                            TextField(
                              controller: widthController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: '폭 (mm) *',
                              ),
                            ),
                            TextField(
                              controller: heightController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: '높이 (mm) *',
                              ),
                            ),
                            TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: '수량 *',
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '기본 견적 정보',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...[
                              '기본 받는 사람',
                              '고상명',
                              '담당자',
                              '담당자 전화번호',
                              '휴대폰번호',
                              '팩스 번호',
                              'e-mail',
                              '견적번호',
                              '작성일자',
                              '납기',
                              '유효기간',
                            ].map((key) {
                              if (key == '작성일자') {
                                customFields[key] = _formatCreatedAt(
                                  existing?.createdAt ?? DateTime.now(),
                                );
                              }
                              final controller = TextEditingController(
                                text: customFields[key] ?? '',
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: controller,
                                  readOnly: key == '견적번호' || key == '작성일자',
                                  decoration: InputDecoration(labelText: key),
                                  onChanged: (v) => customFields[key] = v,
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            const Text(
                              '등록자 정보',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...[
                              '등록자 지사주소',
                              '등록자 전화번호',
                              '등록자 팩스번호',
                              '등록자 홈페이지 주소',
                              '등록자 e-mail주소',
                              '등록자 담당자이름',
                              '등록자 담당자 전화번호',
                            ].map((key) {
                              final controller = TextEditingController(
                                text: customFields[key] ?? '',
                              );
                              final readonly =
                                  key == '등록자 담당자이름' || key == '등록자 담당자 전화번호';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: controller,
                                  readOnly: readonly,
                                  decoration: InputDecoration(
                                    labelText: key,
                                    helperText: readonly ? '로그인 정보 자동입력' : null,
                                  ),
                                  onChanged: (v) => customFields[key] = v,
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            const Text(
                              '서명',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '현장담당자 서명',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _signaturePreview(
                                    siteManagerSignature,
                                    Theme.of(context).colorScheme,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: () async {
                                          final value =
                                              await _openSignatureDialog(
                                                title: '현장담당자 서명',
                                                initialBase64:
                                                    siteManagerSignature,
                                              );
                                          if (value == null) return;
                                          setModalState(() {
                                            siteManagerSignature = value;
                                          });
                                        },
                                        child: Text(
                                          siteManagerSignature.isEmpty
                                              ? '서명 입력'
                                              : '다시 서명',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => setModalState(() {
                                          siteManagerSignature = '';
                                        }),
                                        child: const Text('지우기'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '등록자 담당자 서명',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _signaturePreview(
                                    staffSignature,
                                    Theme.of(context).colorScheme,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: () async {
                                          final value =
                                              await _openSignatureDialog(
                                                title: '등록자 담당자 서명',
                                                initialBase64: staffSignature,
                                              );
                                          if (value == null) return;
                                          setModalState(() {
                                            staffSignature = value;
                                          });
                                        },
                                        child: Text(
                                          staffSignature.isEmpty
                                              ? '서명 입력'
                                              : '다시 서명',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => setModalState(() {
                                          staffSignature = '';
                                        }),
                                        child: const Text('지우기'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '모델별 추가 입력',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...fields.map((key) {
                              final controller = TextEditingController(
                                text: customFields[key] ?? '',
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(labelText: key),
                                  onChanged: (v) => customFields[key] = v,
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  '추가 항목',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => setModalState(() {
                                    extras.add(
                                      EstimateExtraItem(
                                        name: '추가 항목',
                                        amount: 0,
                                        quantity: 1,
                                      ),
                                    );
                                  }),
                                  icon: const Icon(Icons.add),
                                  label: const Text('항목 추가'),
                                ),
                              ],
                            ),
                            ...extras.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final nameController = TextEditingController(
                                text: item.name,
                              );
                              final amountController = TextEditingController(
                                text: item.amount.toString(),
                              );
                              final qtyController = TextEditingController(
                                text: item.quantity.toString(),
                              );
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '추가 #${idx + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            onPressed: () => setModalState(
                                              () => extras.removeAt(idx),
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextField(
                                        controller: nameController,
                                        decoration: const InputDecoration(
                                          labelText: '항목명',
                                        ),
                                        onChanged: (v) =>
                                            extras[idx] = EstimateExtraItem(
                                              name: v,
                                              amount: extras[idx].amount,
                                              quantity: extras[idx].quantity,
                                            ),
                                      ),
                                      TextField(
                                        controller: amountController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          const ThousandsFormatter(),
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: '금액',
                                        ),
                                        onChanged: (v) =>
                                            extras[idx] = EstimateExtraItem(
                                              name: extras[idx].name,
                                              amount:
                                                  int.tryParse(
                                                    v.replaceAll(',', ''),
                                                  ) ??
                                                  0,
                                              quantity: extras[idx].quantity,
                                            ),
                                      ),
                                      TextField(
                                        controller: qtyController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: '수량',
                                        ),
                                        onChanged: (v) =>
                                            extras[idx] = EstimateExtraItem(
                                              name: extras[idx].name,
                                              amount: extras[idx].amount,
                                              quantity: (int.tryParse(v) ?? 1)
                                                  .clamp(1, 99),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            TextField(
                              controller: memoController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: '메모',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              try {
                                FocusScope.of(context).unfocus();
                                ScaffoldMessenger.of(this.context)
                                  ..clearSnackBars()
                                  ..showSnackBar(
                                    const SnackBar(
                                      content: Text('저장 중...'),
                                      duration: Duration(seconds: 10),
                                    ),
                                  );
                                final category =
                                    categoryController.text.trim().isEmpty
                                    ? '기타'
                                    : categoryController.text.trim();
                                final model =
                                    modelController.text.trim().isEmpty
                                    ? '기본모델'
                                    : modelController.text.trim();
                                final customer =
                                    customerController.text.trim().isEmpty
                                    ? '고객'
                                    : customerController.text.trim();
                                final site = siteController.text.trim();
                                final width =
                                    int.tryParse(widthController.text) ?? 0;
                                final height =
                                    int.tryParse(heightController.text) ?? 0;
                                final quantity =
                                    int.tryParse(quantityController.text) ?? 0;
                                final missing = <String>[
                                  if (site.isEmpty) '현장명',
                                  if (width <= 0) '폭(mm)',
                                  if (height <= 0) '높이(mm)',
                                  if (quantity <= 0) '수량',
                                ];
                                if (missing.isNotEmpty) {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('필수 항목 누락'),
                                      content: Text(
                                        '* 필수 항목이 누락되었습니다.\n\n- ${missing.join('\n- ')}',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext).pop(),
                                          child: const Text('확인'),
                                        ),
                                      ],
                                    ),
                                  );
                                  setModalState(() => isSaving = false);
                                  return;
                                }
                                final now = DateTime.now();
                                customFields['현장담당자 서명'] = siteManagerSignature;
                                customFields['등록자 담당자 서명'] = staffSignature;
                                final doc = EstimateDocument(
                                  id: existing?.id ?? _genId(),
                                  category: category,
                                  modelName: model,
                                  customerName: customer,
                                  siteName: site,
                                  widthMm: width,
                                  heightMm: height,
                                  quantity: quantity,
                                  baseAmount:
                                      int.tryParse(
                                        baseAmountController.text.replaceAll(
                                          ',',
                                          '',
                                        ),
                                      ) ??
                                      0,
                                  extraItems: extras,
                                  customFields: customFields.map(
                                    (key, value) => MapEntry(key, value.trim()),
                                  ),
                                  memo: memoController.text.trim(),
                                  createdAt: existing?.createdAt ?? now,
                                  updatedAt: now,
                                );
                                await ref
                                    .read(estimateDocumentRepositoryProvider)
                                    .upsert(doc);
                                if (loginUserId.isNotEmpty &&
                                    staffSignature.trim().isNotEmpty) {
                                  await prefs.setString(
                                    staffSignatureKey,
                                    staffSignature,
                                  );
                                }
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        existing == null
                                            ? '견적서를 저장했습니다.'
                                            : '견적서를 수정했습니다.',
                                      ),
                                    ),
                                  );
                                  unawaited(_load());
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(content: Text('저장 중 오류: $e')),
                                  );
                                }
                                setModalState(() => isSaving = false);
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(existing == null ? '견적서 저장' : '수정 저장'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _delete(String id) async {
    await ref.read(estimateDocumentRepositoryProvider).delete(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '고객명/현장명/모델명/카테고리 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(child: Text('저장된 견적서가 없습니다.'))
                  : ListView.separated(
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final q = _searchController.text.trim();
                        return ListTile(
                          tileColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: SearchHighlightText(
                            text: '${item.category} · ${item.modelName}',
                            query: q,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: SearchHighlightText(
                            text:
                                '${item.customerName} / ${item.siteName}\n'
                                '${item.widthMm}×${item.heightMm}mm · ${item.quantity}개 · ${_krw.format(item.totalAmount)}'
                                ' · 작성 ${_formatCreatedAt(item.createdAt)}',
                            query: q,
                            maxLines: 3,
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _openForm(item);
                              } else if (v == 'export') {
                                await _openExportSheet(item);
                              } else if (v == 'delete') {
                                await _delete(item.id);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('수정')),
                              PopupMenuItem(
                                value: 'export',
                                child: Text('이미지 저장/공유'),
                              ),
                              PopupMenuItem(value: 'delete', child: Text('삭제')),
                            ],
                          ),
                          onTap: () => _openForm(item),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemCount: _items.length,
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('견적서 작성'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

class _SignaturePadDialog extends StatefulWidget {
  const _SignaturePadDialog({required this.title, this.initialBase64});

  final String title;
  final String? initialBase64;

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  final List<Offset?> _points = <Offset?>[];
  final GlobalKey _padKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.of(context).size.height;
    final padHeight = min(180.0, max(120.0, availableHeight * 0.28));

    return AlertDialog(
      title: Text(widget.title),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: padHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: RepaintBoundary(
                key: _padKey,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _points.add(details.localPosition);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _points.add(details.localPosition);
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      _points.add(null);
                    });
                  },
                  child: CustomPaint(
                    painter: _SignaturePainter(points: _points),
                    size: Size(double.infinity, padHeight),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() => _points.clear()),
                  child: const Text('지우기'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () async {
                    final data = await _exportBase64();
                    if (!context.mounted) return;
                    Navigator.of(context).pop(data);
                  },
                  child: const Text('서명 적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _exportBase64() async {
    final boundary =
        _padKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return '';
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List() ?? Uint8List(0);
    return base64Encode(bytes);
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({required this.points});

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    // 드로잉 중 프레임마다 즉시 반영되도록 항상 재페인트한다.
    return true;
  }
}
