import 'dart:math';

import 'package:coad_customer_calls/models/estimate_document.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
                        decoration: const InputDecoration(labelText: '모델명'),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      TextField(
                        controller: customerController,
                        decoration: const InputDecoration(labelText: '고객명'),
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
                        decoration: const InputDecoration(labelText: '현장명'),
                      ),
                      TextField(
                        controller: baseAmountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: '기본 금액'),
                      ),
                      TextField(
                        controller: widthController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: '폭 (mm)'),
                      ),
                      TextField(
                        controller: heightController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: '높이 (mm)'),
                      ),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: '수량'),
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
                        '납기',
                        '유효기간',
                      ].map((key) {
                        final controller = TextEditingController(
                          text: customFields[key] ?? '',
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextField(
                            controller: controller,
                            readOnly: key == '견적번호',
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
                                      icon: const Icon(Icons.delete_outline),
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
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: '금액',
                                  ),
                                  onChanged: (v) =>
                                      extras[idx] = EstimateExtraItem(
                                        name: extras[idx].name,
                                        amount: int.tryParse(v) ?? 0,
                                        quantity: extras[idx].quantity,
                                      ),
                                ),
                                TextField(
                                  controller: qtyController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: '수량',
                                  ),
                                  onChanged: (v) =>
                                      extras[idx] = EstimateExtraItem(
                                        name: extras[idx].name,
                                        amount: extras[idx].amount,
                                        quantity: (int.tryParse(v) ?? 1).clamp(
                                          1,
                                          99,
                                        ),
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
                        decoration: const InputDecoration(labelText: '메모'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          final category = categoryController.text.trim();
                          final model = modelController.text.trim();
                          final customer = customerController.text.trim();
                          final width = int.tryParse(widthController.text) ?? 0;
                          final height =
                              int.tryParse(heightController.text) ?? 0;
                          final quantity =
                              int.tryParse(quantityController.text) ?? 0;
                          if (category.isEmpty ||
                              model.isEmpty ||
                              customer.isEmpty ||
                              width <= 0 ||
                              height <= 0 ||
                              quantity <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('카테고리/모델명/고객명/폭/높이/수량은 필수입니다.'),
                              ),
                            );
                            return;
                          }
                          final now = DateTime.now();
                          final doc = EstimateDocument(
                            id: existing?.id ?? _genId(),
                            category: category,
                            modelName: model,
                            customerName: customer,
                            siteName: siteController.text.trim(),
                            widthMm: width,
                            heightMm: height,
                            quantity: quantity,
                            baseAmount:
                                int.tryParse(baseAmountController.text) ?? 0,
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
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await _load();
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                existing == null
                                    ? '견적서를 저장했습니다.'
                                    : '견적서를 수정했습니다.',
                              ),
                            ),
                          );
                        },
                        child: Text(existing == null ? '견적서 저장' : '수정 저장'),
                      ),
                    ],
                  ),
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
                        return ListTile(
                          tileColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(
                            '${item.category} · ${item.modelName}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item.customerName} / ${item.siteName}\n'
                            '${item.widthMm}×${item.heightMm}mm · ${item.quantity}개 · ${_krw.format(item.totalAmount)}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await _openForm(item);
                              } else if (v == 'delete') {
                                await _delete(item.id);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('수정')),
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
