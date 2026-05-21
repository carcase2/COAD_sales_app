import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/quoter/quoter_hub_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IssuanceRequestCreateScreen extends ConsumerStatefulWidget {
  const IssuanceRequestCreateScreen({super.key, required this.initialDomain});

  final IssuanceDomain initialDomain;

  @override
  ConsumerState<IssuanceRequestCreateScreen> createState() =>
      _IssuanceRequestCreateScreenState();
}

class _IssuanceRequestCreateScreenState
    extends ConsumerState<IssuanceRequestCreateScreen> {
  final _taxFormKey = GlobalKey<FormState>();
  final _bondFormKey = GlobalKey<FormState>();
  final _rand = Random();
  final _storage = Supabase.instance.client.storage.from('tax-invoices');
  final _client = Supabase.instance.client;

  late IssuanceDomain _domain;
  bool _saving = false;

  // Tax invoice
  final _taxCustomerName = TextEditingController();
  final _taxRegistrationNumber = TextEditingController();
  final _taxIssueDate = TextEditingController();
  final _taxTotalAmount = TextEditingController();
  final _taxItemName = TextEditingController(text: '셔터');
  final _taxEmail = TextEditingController();
  int _taxPercentage = 100;
  String _taxItemType = '선급금';
  bool _taxMesRegistered = false;
  bool _taxUrgent = false;
  String? _taxBranch;
  List<PlatformFile> _taxBizFiles = [];
  List<String> _branchOptions = [];

  // Performance bond
  String _bondType = '계약이행';
  final _bondCompanyName = TextEditingController();
  final _bondEmail = TextEditingController();
  final _bondContractAmount = TextEditingController();
  final _bondGuaranteeRate = TextEditingController(text: '10');
  final _bondGuaranteePeriod = TextEditingController(text: '1');
  final _bondContractDate = TextEditingController();
  final _bondConstructionEndDate = TextEditingController();
  final _bondRequestDeadline = TextEditingController();
  List<PlatformFile> _bondBizFiles = [];
  List<PlatformFile> _bondContractFiles = [];
  bool _quickActionsOpen = false;

  @override
  void initState() {
    super.initState();
    _domain = widget.initialDomain;
    _taxIssueDate.text = _todayYmd();
    _bondContractDate.text = _todayYmd();
    _bondConstructionEndDate.text = _todayYmd();
    _loadBranches();
  }

  @override
  void dispose() {
    _taxCustomerName.dispose();
    _taxRegistrationNumber.dispose();
    _taxIssueDate.dispose();
    _taxTotalAmount.dispose();
    _taxItemName.dispose();
    _taxEmail.dispose();
    _bondCompanyName.dispose();
    _bondEmail.dispose();
    _bondContractAmount.dispose();
    _bondGuaranteeRate.dispose();
    _bondGuaranteePeriod.dispose();
    _bondContractDate.dispose();
    _bondConstructionEndDate.dispose();
    _bondRequestDeadline.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final res = await _client.from('regions').select('branch_type');
      final set = <String>{};
      for (final row in List<Map<String, dynamic>>.from(res)) {
        final v = (row['branch_type'] ?? '').toString().trim();
        if (v.isNotEmpty) set.add(v);
      }
      final list = set.toList()..sort();
      if (!mounted) return;
      setState(() {
        _branchOptions = list;
        _taxBranch ??= list.isNotEmpty ? list.first : null;
      });
    } catch (_) {}
  }

  String _todayYmd() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _safe(String input) =>
      input.trim().replaceAll(RegExp(r'[^a-zA-Z0-9가-힣._-]'), '_');

  Future<List<PlatformFile>> _pickFiles({required bool imageOnly}) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: imageOnly
          ? const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif']
          : const [
              'jpg',
              'jpeg',
              'png',
              'gif',
              'webp',
              'bmp',
              'heic',
              'heif',
              'pdf',
            ],
    );
    if (result == null) return [];
    return result.files.where((f) {
      if (f.path == null) return false;
      final sizeOk = f.size <= 10 * 1024 * 1024;
      if (!sizeOk) return false;
      final mime = lookupMimeType(f.path!);
      if (mime == null) return false;
      return imageOnly
          ? mime.startsWith('image/')
          : (mime.startsWith('image/') || mime == 'application/pdf');
    }).toList();
  }

  Future<List<String>> _uploadFiles({
    required List<PlatformFile> files,
    required String rootPath,
    required String ownerName,
  }) async {
    final date = _todayYmd();
    final safeOwner = _safe(ownerName.isEmpty ? 'unknown' : ownerName);
    final urls = <String>[];
    for (final f in files) {
      final p = f.path;
      if (p == null) continue;
      final bytes = await File(p).readAsBytes();
      final original = _safe(f.name);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final rand = _rand.nextInt(999999).toString().padLeft(6, '0');
      final objectPath =
          '$rootPath/$safeOwner/$date/${stamp}_${rand}_$original';
      final mime = lookupMimeType(p);
      await _storage.uploadBinary(
        objectPath,
        bytes,
        fileOptions: FileOptions(upsert: false, contentType: mime),
      );
      urls.add(_storage.getPublicUrl(objectPath));
    }
    return urls;
  }

  int _parseMoney(String raw) =>
      (double.tryParse(raw.replaceAll(',', '').trim()) ?? 0).round();

  double _parseGuaranteePeriodYears(String raw) {
    final text = raw.trim().toLowerCase().replaceAll(' ', '');
    if (text.isEmpty) return 0;
    if (text.endsWith('개월')) {
      final n = double.tryParse(text.replaceAll('개월', '')) ?? 0;
      return n / 12.0;
    }
    if (text.endsWith('달')) {
      final n = double.tryParse(text.replaceAll('달', '')) ?? 0;
      return n / 12.0;
    }
    if (text.endsWith('년')) {
      return double.tryParse(text.replaceAll('년', '')) ?? 0;
    }
    // 기본 입력 단위는 달입니다. (예: 1 -> 1달)
    final months = double.tryParse(text) ?? 0;
    return months / 12.0;
  }

  Future<String> _generateNumber({
    required String table,
    required String prefix,
  }) async {
    final now = DateTime.now();
    final ym = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final fullPrefix = '$prefix-$ym-';
    final rows = await _client
        .from(table)
        .select(table == 'tax_invoices' ? 'invoice_number' : 'bond_number')
        .like(
          table == 'tax_invoices' ? 'invoice_number' : 'bond_number',
          '$fullPrefix%',
        )
        .order('created_at', ascending: false)
        .limit(1);
    int next = 1;
    if (rows.isNotEmpty) {
      final key = table == 'tax_invoices' ? 'invoice_number' : 'bond_number';
      final last = (rows.first[key] ?? '').toString();
      final n = int.tryParse(last.split('-').last) ?? 0;
      next = n + 1;
    }
    return '$fullPrefix${next.toString().padLeft(4, '0')}';
  }

  Future<void> _pickDate(
    TextEditingController ctrl, {
    DateTime? firstDate,
  }) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(ctrl.text) ?? now,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (date != null) {
      ctrl.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final user = ref.read(authControllerProvider);
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 정보가 필요합니다.')));
      return;
    }

    setState(() => _saving = true);
    try {
      if (_domain == IssuanceDomain.taxInvoice) {
        await _submitTax(user.name);
      } else {
        await _submitBond(user.name);
      }
      if (!mounted) return;
      ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.taxInvoice));
      ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.performanceBond));
      ref.invalidate(issuanceRequestBadgeCountProvider);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('발행요청이 등록되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitTax(String userName) async {
    if (!_taxFormKey.currentState!.validate()) {
      throw Exception('필수 입력값을 확인해주세요.');
    }
    if (_taxBizFiles.isEmpty) throw Exception('사업자등록증 이미지를 1개 이상 첨부해주세요.');
    if (_taxBranch == null || _taxBranch!.trim().isEmpty) {
      throw Exception('지사를 선택해주세요.');
    }

    final totalAmount = _parseMoney(_taxTotalAmount.text);
    if (totalAmount <= 0) throw Exception('총액을 올바르게 입력해주세요.');
    final taxAmount = totalAmount ~/ 11;
    final supplyAmount = totalAmount - taxAmount;
    final invoiceNumber = await _generateNumber(
      table: 'tax_invoices',
      prefix: 'TAX',
    );
    final urls = await _uploadFiles(
      files: _taxBizFiles,
      rootPath: 'business_registration',
      ownerName: _taxCustomerName.text.trim(),
    );
    final imageValue = urls.length == 1 ? urls.first : jsonEncode(urls);

    final inserted = await _client
        .from('tax_invoices')
        .insert({
          'invoice_number': invoiceNumber,
          'issue_date': _taxIssueDate.text.trim(),
          'customer_name': _taxCustomerName.text.trim(),
          if (_taxRegistrationNumber.text.trim().isNotEmpty)
            'customer_registration_number': _taxRegistrationNumber.text.trim(),
          'supply_amount': supplyAmount,
          'tax_amount': taxAmount,
          'total_amount': totalAmount,
          'status': 'pending',
          'created_by': userName,
          'business_registration_image_url': imageValue,
          'requester': userName,
          'requester_date': DateTime.now().toIso8601String(),
          'percentage': _taxPercentage,
          'mes_registered': _taxMesRegistered,
          'item_type': _taxItemType,
          'item_name': _taxItemName.text.trim(),
          'branch': _taxBranch,
          if (_taxEmail.text.trim().isNotEmpty) 'email': _taxEmail.text.trim(),
        })
        .select('id')
        .single();

    if (_taxUrgent) {
      final invoiceId = inserted['id'];
      final orderRows = await _client
          .from('tax_invoice_issues')
          .select('issue_order')
          .eq('tax_invoice_id', invoiceId)
          .order('issue_order', ascending: false)
          .limit(1);
      final currentMax = (orderRows.isNotEmpty)
          ? (orderRows.first['issue_order'] as num?)?.toInt() ?? 0
          : 0;
      await _client.from('tax_invoice_issues').insert({
        'tax_invoice_id': invoiceId,
        'invoice_image_url': null,
        'is_urgent': true,
        'supply_amount': supplyAmount,
        'tax_amount': taxAmount,
        'total_amount': totalAmount,
        'issue_order': currentMax + 1,
      });
    }
  }

  Future<void> _submitBond(String userName) async {
    if (!_bondFormKey.currentState!.validate()) {
      throw Exception('필수 입력값을 확인해주세요.');
    }
    if (_bondBizFiles.isEmpty) throw Exception('사업자등록증 파일을 1개 이상 첨부해주세요.');
    if (_bondContractFiles.isEmpty) throw Exception('계약서 파일을 1개 이상 첨부해주세요.');

    final contractAmount = _parseMoney(_bondContractAmount.text);
    final guaranteeRate = double.tryParse(_bondGuaranteeRate.text.trim()) ?? 0;
    final guaranteePeriod = _parseGuaranteePeriodYears(
      _bondGuaranteePeriod.text.trim(),
    );
    if (contractAmount <= 0) throw Exception('계약금액을 올바르게 입력해주세요.');
    if (guaranteeRate <= 0 || guaranteeRate > 100) {
      throw Exception('보증금율은 0~100 사이여야 합니다.');
    }
    if (guaranteePeriod <= 0) {
      throw Exception('보증기간을 올바르게 입력해주세요. (예: 1, 6, 12달)');
    }

    final contractDate = DateTime.tryParse(_bondContractDate.text.trim());
    final endDate = DateTime.tryParse(_bondConstructionEndDate.text.trim());
    if (contractDate == null || endDate == null) {
      throw Exception('시공 시작일/종료일을 입력해주세요.');
    }
    if (endDate.isBefore(contractDate)) {
      throw Exception('시공 종료일은 시작일 이후여야 합니다.');
    }

    final bondNumber = await _generateNumber(
      table: 'performance_bonds',
      prefix: 'BOND',
    );
    final businessUrls = await _uploadFiles(
      files: _bondBizFiles,
      rootPath: 'bond',
      ownerName: _bondCompanyName.text.trim(),
    );
    final contractUrls = await _uploadFiles(
      files: _bondContractFiles,
      rootPath: 'bond',
      ownerName: _bondCompanyName.text.trim(),
    );

    final inserted = await _client
        .from('performance_bonds')
        .insert({
          'bond_number': bondNumber,
          'bond_type': _bondType,
          'company_name': _bondCompanyName.text.trim(),
          'contract_amount': contractAmount,
          'guarantee_rate': guaranteeRate,
          'guarantee_period': guaranteePeriod,
          'contract_date': _bondContractDate.text.trim(),
          if (_bondRequestDeadline.text.trim().isNotEmpty)
            'request_deadline': _bondRequestDeadline.text.trim(),
          'status': 'pending',
          'created_by': userName,
          'requester': userName,
          'requester_date': DateTime.now().toIso8601String(),
          if (_bondEmail.text.trim().isNotEmpty)
            'email': _bondEmail.text.trim(),
          'bond_image_url': null,
        })
        .select('id')
        .single();

    await _client.from('performance_bond_issues').insert({
      'performance_bond_id': inserted['id'],
      'request_image_url': jsonEncode({
        'business': businessUrls,
        'contract': contractUrls,
      }),
      'bond_image_url': null,
      'issue_order': 1,
      'construction_start_date': _bondContractDate.text.trim(),
      'construction_end_date': _bondConstructionEndDate.text.trim(),
      'issue_date': _todayYmd(),
      'issued_by': userName,
    });
  }

  void _applyBondDefaultsByType(String type) {
    switch (type) {
      case '선급금':
        _bondGuaranteeRate.text = '100';
        _bondGuaranteePeriod.text = '1';
        break;
      case '하자이행':
        _bondGuaranteeRate.text = '3';
        _bondGuaranteePeriod.text = '1';
        break;
      case '계약이행':
      default:
        _bondGuaranteeRate.text = '10';
        _bondGuaranteePeriod.text = '1';
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTax = _domain == IssuanceDomain.taxInvoice;
    final taxRowsAsync = ref.watch(
      issuanceRequestRowsProvider(IssuanceDomain.taxInvoice),
    );
    final bondRowsAsync = ref.watch(
      issuanceRequestRowsProvider(IssuanceDomain.performanceBond),
    );
    final taxCount = taxRowsAsync.valueOrNull?.length;
    final bondCount = bondRowsAsync.valueOrNull?.length;
    final accent = isTax ? Colors.indigo.shade600 : Colors.deepOrange.shade700;
    final scheme = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final actionsBottom = 12.0 + safeBottom;
    final quickActions = <_CreateQuickActionItem>[
      _CreateQuickActionItem(
        label: '홈',
        color: Colors.blueGrey.shade700,
        icon: Icons.home_rounded,
        onTap: () {
          setState(() => _quickActionsOpen = false);
          openHomeHub(context, ref);
        },
      ),
      _CreateQuickActionItem(
        label: '접수',
        color: scheme.tertiary,
        icon: Icons.add_ic_call_rounded,
        onTap: () async {
          setState(() => _quickActionsOpen = false);
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SalesCallCreateScreen(),
            ),
          );
        },
      ),
      _CreateQuickActionItem(
        label: '견적기 (테스트중)',
        color: Colors.teal.shade600,
        icon: Icons.calculate_rounded,
        onTap: () async {
          setState(() => _quickActionsOpen = false);
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('견적기 (테스트중)'),
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                ),
                body: const QuoterHubScreen(),
              ),
            ),
          );
        },
      ),
    ];
    final inputTheme = Theme.of(context).inputDecorationTheme.copyWith(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade600, width: 1.8),
      ),
      labelStyle: TextStyle(
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: TextStyle(color: accent, fontWeight: FontWeight.w700),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('발행요청 등록'),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isTax
                            ? Icons.receipt_long_rounded
                            : Icons.gavel_rounded,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isTax ? '세금계산서 발행요청 작성' : '이행증권 발행요청 작성',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SegmentedButton<IssuanceDomain>(
                    segments: [
                      ButtonSegment(
                        value: IssuanceDomain.taxInvoice,
                        label: _buildDomainSegmentLabel(
                          title: '세금계산서',
                          count: taxCount,
                        ),
                      ),
                      ButtonSegment(
                        value: IssuanceDomain.performanceBond,
                        label: _buildDomainSegmentLabel(
                          title: '이행증권',
                          count: bondCount,
                        ),
                      ),
                    ],
                    selected: {_domain},
                    onSelectionChanged: (v) =>
                        setState(() => _domain = v.first),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app_rounded, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          '아래 입력칸을 눌러 작성하세요',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(inputDecorationTheme: inputTheme),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      child: _domain == IssuanceDomain.taxInvoice
                          ? _buildTaxForm()
                          : _buildBondForm(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_quickActionsOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _quickActionsOpen = false),
                child: const SizedBox.expand(),
              ),
            ),
          Positioned(
            right: 16,
            bottom: actionsBottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_quickActionsOpen)
                  Container(
                    width: 182,
                    constraints: const BoxConstraints(maxHeight: 300),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: quickActions
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Material(
                                  color: item.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: item.onTap,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            item.icon,
                                            size: 18,
                                            color: item.color,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.label,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: scheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 18,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'issuance_create_open_menu',
                      mini: true,
                      backgroundColor: scheme.primary,
                      foregroundColor: Colors.white,
                      onPressed: () => setState(
                        () => _quickActionsOpen = !_quickActionsOpen,
                      ),
                      tooltip: _quickActionsOpen ? '닫기' : '열기',
                      child: Icon(
                        _quickActionsOpen
                            ? Icons.close_rounded
                            : Icons.menu_open_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton.extended(
                      onPressed: _saving ? null : _submit,
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? '저장 중...' : '저장'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxForm() {
    return Form(
      key: _taxFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            title: '기본 정보',
            child: Column(
              children: [
                TextFormField(
                  controller: _taxCustomerName,
                  decoration: const InputDecoration(labelText: '고객명(현장명) *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '고객명을 입력하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _taxRegistrationNumber,
                  decoration: const InputDecoration(
                    labelText: '종사업자번호',
                    hintText: '000-00-00000',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _taxIssueDate,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: '발행요청일 *'),
                  onTap: () => _pickDate(_taxIssueDate),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '발행요청일을 선택하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _taxTotalAmount,
                  decoration: const InputDecoration(
                    labelText: '부가세 포함 총액(원) *',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    const _ThousandsFormatter(),
                  ],
                  validator: (v) =>
                      _parseMoney(v ?? '') <= 0 ? '총액을 입력하세요.' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '항목 설정',
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('발행 퍼센트'),
                    Expanded(
                      child: Slider(
                        value: _taxPercentage.toDouble(),
                        min: 1,
                        max: 100,
                        divisions: 99,
                        label: '$_taxPercentage%',
                        onChanged: (v) =>
                            setState(() => _taxPercentage = v.round()),
                      ),
                    ),
                    Text('$_taxPercentage%'),
                  ],
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '항목 구분 *',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTypeChip(
                      label: '선급금',
                      selected: _taxItemType == '선급금',
                      selectedBg: Colors.blue.shade100,
                      selectedFg: Colors.blue.shade900,
                      onTap: () => setState(() => _taxItemType = '선급금'),
                    ),
                    _buildTypeChip(
                      label: '중도금',
                      selected: _taxItemType == '중도금',
                      selectedBg: Colors.amber.shade100,
                      selectedFg: Colors.amber.shade900,
                      onTap: () => setState(() => _taxItemType = '중도금'),
                    ),
                    _buildTypeChip(
                      label: '잔금',
                      selected: _taxItemType == '잔금',
                      selectedBg: Colors.green.shade100,
                      selectedFg: Colors.green.shade900,
                      onTap: () => setState(() => _taxItemType = '잔금'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _taxItemName,
                  decoration: const InputDecoration(
                    labelText: '품목명 *',
                    hintText: '스피드도어/오버헤드도어/차고문/셔터/기타',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '품목명을 입력하세요.' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '지사/옵션',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _taxBranch,
                  items: _branchOptions
                      .map(
                        (e) =>
                            DropdownMenuItem<String>(value: e, child: Text(e)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _taxBranch = v),
                  decoration: const InputDecoration(labelText: '지사 *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '지사를 선택하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _taxEmail,
                  decoration: const InputDecoration(labelText: '이메일'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  value: _taxMesRegistered,
                  onChanged: (v) => setState(() => _taxMesRegistered = v),
                  title: const Text('MES 등록 여부'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _taxUrgent,
                  onChanged: (v) => setState(() => _taxUrgent = v),
                  title: const Text('긴급 발급요청'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '사업자등록증 첨부',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _taxBizFiles
                      .map(
                        (f) => Chip(
                          backgroundColor: Colors.indigo.withValues(
                            alpha: 0.08,
                          ),
                          side: BorderSide(
                            color: Colors.indigo.withValues(alpha: 0.25),
                          ),
                          label: Text(f.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final files = await _pickFiles(imageOnly: true);
                    if (files.isEmpty) return;
                    setState(() => _taxBizFiles = files);
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text('사업자등록증 첨부 (${_taxBizFiles.length}) *'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBondForm() {
    return Form(
      key: _bondFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            title: '증권 종류 *',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const ['계약이행', '선급금', '하자이행'].map((type) {
                final selected = _bondType == type;
                final selectedBg = switch (type) {
                  '계약이행' => Colors.indigo.shade100,
                  '선급금' => Colors.orange.shade100,
                  '하자이행' => Colors.teal.shade100,
                  _ => Colors.blueGrey.shade100,
                };
                final selectedFg = switch (type) {
                  '계약이행' => Colors.indigo.shade900,
                  '선급금' => Colors.orange.shade900,
                  '하자이행' => Colors.teal.shade900,
                  _ => Colors.blueGrey.shade900,
                };
                return ChoiceChip(
                  label: Text(type),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: selectedBg,
                  side: BorderSide(
                    color: selected
                        ? selectedFg.withValues(alpha: 0.35)
                        : Colors.grey.shade300,
                  ),
                  labelStyle: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? selectedFg : Colors.black87,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _bondType = type;
                      _applyBondDefaultsByType(type);
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '기본 정보',
            child: Column(
              children: [
                TextFormField(
                  controller: _bondCompanyName,
                  decoration: const InputDecoration(labelText: '업체명 *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '업체명을 입력하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bondEmail,
                  decoration: const InputDecoration(labelText: '이메일'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bondContractAmount,
                  decoration: const InputDecoration(
                    labelText: '계약금액(부가세 포함) *',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    const _ThousandsFormatter(),
                  ],
                  validator: (v) =>
                      _parseMoney(v ?? '') <= 0 ? '계약금액을 입력하세요.' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '보증/기간 정보',
            child: Column(
              children: [
                TextFormField(
                  controller: _bondGuaranteeRate,
                  decoration: const InputDecoration(labelText: '보증금율(%) *'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim()) ?? 0;
                    return (n <= 0 || n > 100) ? '0~100 범위로 입력하세요.' : null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bondGuaranteePeriod,
                  decoration: const InputDecoration(
                    labelText: '보증기간(달) *',
                    hintText: '예: 1, 6, 12',
                  ),
                  onTap: () {
                    if (_bondGuaranteePeriod.text.trim() == '1') {
                      _bondGuaranteePeriod.clear();
                    }
                  },
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => _parseGuaranteePeriodYears(v ?? '') <= 0
                      ? '보증기간(달)을 입력하세요. (예: 1)'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bondContractDate,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: '시공 시작일 *'),
                  onTap: () => _pickDate(_bondContractDate),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '시공 시작일을 선택하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bondConstructionEndDate,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: '시공 종료일 *'),
                  onTap: () => _pickDate(
                    _bondConstructionEndDate,
                    firstDate: DateTime.tryParse(_bondContractDate.text.trim()),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '시공 종료일을 선택하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bondRequestDeadline,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: '요청기한'),
                  onTap: () => _pickDate(_bondRequestDeadline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '첨부 파일',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _bondBizFiles
                      .map(
                        (f) => Chip(
                          backgroundColor: Colors.deepOrange.withValues(
                            alpha: 0.08,
                          ),
                          side: BorderSide(
                            color: Colors.deepOrange.withValues(alpha: 0.25),
                          ),
                          label: Text(f.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final files = await _pickFiles(imageOnly: false);
                    if (files.isEmpty) return;
                    setState(() => _bondBizFiles = files);
                  },
                  icon: const Icon(Icons.badge_outlined),
                  label: Text('사업자등록증 첨부 (${_bondBizFiles.length}) *'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _bondContractFiles
                      .map(
                        (f) => Chip(
                          backgroundColor: Colors.deepOrange.withValues(
                            alpha: 0.08,
                          ),
                          side: BorderSide(
                            color: Colors.deepOrange.withValues(alpha: 0.25),
                          ),
                          label: Text(f.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final files = await _pickFiles(imageOnly: false);
                    if (files.isEmpty) return;
                    setState(() => _bondContractFiles = files);
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: Text('계약서 첨부 (${_bondContractFiles.length}) *'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required bool selected,
    required Color selectedBg,
    required Color selectedFg,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: selectedBg,
      side: BorderSide(
        color: selected
            ? selectedFg.withValues(alpha: 0.35)
            : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? selectedFg : Colors.black87,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildDomainSegmentLabel({
    required String title,
    required int? count,
  }) {
    final countText = count == null ? '…' : '$count';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            countText,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _CreateQuickActionItem {
  const _CreateQuickActionItem({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
}

class _ThousandsFormatter extends TextInputFormatter {
  const _ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final number = int.tryParse(digits);
    if (number == null) return oldValue;
    final text = _format(number);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _format(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && idx % 3 == 1) {
        buf.write(',');
      }
    }
    return buf.toString();
  }
}
