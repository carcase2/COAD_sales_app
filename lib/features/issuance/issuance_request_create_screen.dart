import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:coad_customer_calls/core/utils/korean_amount_words.dart';
import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
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
  static const _taxItemNameOptions = ['스피드도어', '오버헤드도어', '차고문', '셔터'];
  final _taxItemName = TextEditingController(text: '셔터');
  final _taxEmail = TextEditingController();
  final _taxPercentageCtrl = TextEditingController(text: '100');
  int _taxPercentage = 100;
  String _taxItemType = '선급금';
  String _taxItemNameChoice = '셔터';
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
  final _formScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _domain = widget.initialDomain;
    _taxIssueDate.text = _nowYmdHm();
    _bondContractDate.text = _todayYmd();
    _bondConstructionEndDate.text = _todayYmd();
    _taxTotalAmount.addListener(_onMoneyFieldChanged);
    _bondContractAmount.addListener(_onMoneyFieldChanged);
    _loadBranches();
  }

  void _onMoneyFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _taxTotalAmount.removeListener(_onMoneyFieldChanged);
    _bondContractAmount.removeListener(_onMoneyFieldChanged);
    _taxCustomerName.dispose();
    _taxRegistrationNumber.dispose();
    _taxIssueDate.dispose();
    _taxTotalAmount.dispose();
    _taxItemName.dispose();
    _taxEmail.dispose();
    _taxPercentageCtrl.dispose();
    _bondCompanyName.dispose();
    _bondEmail.dispose();
    _bondContractAmount.dispose();
    _bondGuaranteeRate.dispose();
    _bondGuaranteePeriod.dispose();
    _bondContractDate.dispose();
    _bondConstructionEndDate.dispose();
    _bondRequestDeadline.dispose();
    _formScrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollFormToTop() async {
    if (!_formScrollController.hasClients) return;
    await _formScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String? _firstBondValidationMessage() {
    if (_bondCompanyName.text.trim().isEmpty) {
      return '업체명을 입력하세요.';
    }
    if (_parseMoney(_bondContractAmount.text) <= 0) {
      return '계약금액을 입력하세요.';
    }
    final rate = double.tryParse(_bondGuaranteeRate.text.trim()) ?? 0;
    if (rate <= 0 || rate > 100) {
      return '보증금율은 0~100 사이로 입력하세요.';
    }
    if (_parseGuaranteePeriodMonths(_bondGuaranteePeriod.text) <= 0) {
      return '보증기간(달)을 입력하세요. (예: 1, 6, 12)';
    }
    if (_bondContractDate.text.trim().isEmpty) {
      return '시공 시작일을 선택하세요.';
    }
    if (_bondConstructionEndDate.text.trim().isEmpty) {
      return '시공 종료일을 선택하세요.';
    }
    return null;
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

  String _nowYmdHm() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')} '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  /// 발행요청일시 텍스트("2026-06-10 13:30")에서 날짜 부분만 (DATE 컬럼용).
  String _taxIssueDateOnly() {
    final raw = _taxIssueDate.text.trim();
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  /// 발행요청일시 → ISO timestamp (requester_date 컬럼용).
  String _taxIssueDateTimeIso() {
    final parsed = DateTime.tryParse(_taxIssueDate.text.trim());
    return (parsed ?? DateTime.now()).toIso8601String();
  }

  /// 품목명 칩 색상 (bg, fg).
  (Color, Color) _itemNameChipColors(String option) {
    switch (option) {
      case '스피드도어':
        return (Colors.blue.shade100, Colors.blue.shade900);
      case '오버헤드도어':
        return (Colors.green.shade100, Colors.green.shade900);
      case '차고문':
        return (Colors.orange.shade100, Colors.orange.shade900);
      case '셔터':
        return (Colors.purple.shade100, Colors.purple.shade900);
      default:
        return (Colors.blueGrey.shade100, Colors.blueGrey.shade900);
    }
  }

  static final _branchChipPalette = <(Color, Color)>[
    (Colors.indigo.shade100, Colors.indigo.shade900),
    (Colors.teal.shade100, Colors.teal.shade900),
    (Colors.deepOrange.shade100, Colors.deepOrange.shade900),
    (Colors.pink.shade100, Colors.pink.shade900),
    (Colors.lightGreen.shade100, Colors.green.shade900),
    (Colors.cyan.shade100, Colors.cyan.shade900),
    (Colors.amber.shade100, Colors.brown.shade800),
    (Colors.deepPurple.shade100, Colors.deepPurple.shade900),
  ];

  /// 지사 칩 색상 — 순서대로 팔레트 순환.
  (Color, Color) _branchChipColors(int index) {
    return _branchChipPalette[index % _branchChipPalette.length];
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

  Widget _buildKoreanAmountHint(TextEditingController controller) {
    final label = koreanWonInWords(_parseMoney(controller.text));
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  /// DB `guarantee_period`는 **달(months) 정수** 컬럼.
  int _parseGuaranteePeriodMonths(String raw) {
    final text = raw.trim().toLowerCase().replaceAll(' ', '');
    if (text.isEmpty) return 0;
    if (text.endsWith('개월')) {
      return (double.tryParse(text.replaceAll('개월', '')) ?? 0).round();
    }
    if (text.endsWith('달')) {
      return (double.tryParse(text.replaceAll('달', '')) ?? 0).round();
    }
    if (text.endsWith('년')) {
      final years = double.tryParse(text.replaceAll('년', '')) ?? 0;
      return (years * 12).round();
    }
    return (double.tryParse(text) ?? 0).round();
  }

  /// 웹 `generateInvoiceNumber` 와 동일: `TAX-YYYYMM-랜덤4자리`.
  String _generateTaxInvoiceNumber() {
    final now = DateTime.now();
    final ym = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final random = _rand.nextInt(10000).toString().padLeft(4, '0');
    return 'TAX-$ym-$random';
  }

  Future<String> _generateBondNumber() async {
    const prefix = 'BOND';
    final now = DateTime.now();
    final ym = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final fullPrefix = '$prefix-$ym-';
    final rows = await _client
        .from('performance_bonds')
        .select('bond_number')
        .like('bond_number', '$fullPrefix%')
        .order('created_at', ascending: false)
        .limit(1);
    int next = 1;
    if (rows.isNotEmpty) {
      final last = (rows.first['bond_number'] ?? '').toString();
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

  Future<void> _pickDateTime(TextEditingController ctrl) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(ctrl.text) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    ctrl.text =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    setState(() {});
  }

  Future<String?> _validateCurrentForm() async {
    if (_domain == IssuanceDomain.taxInvoice) {
      if (!_taxFormKey.currentState!.validate()) {
        return '필수 입력값을 확인해주세요.';
      }
      if (_taxBizFiles.isEmpty) {
        return '사업자등록증 이미지를 1개 이상 첨부해주세요.';
      }
      if (_taxBranch == null || _taxBranch!.trim().isEmpty) {
        return '지사를 선택해주세요.';
      }
      return null;
    }

    final precheck = _firstBondValidationMessage();
    if (precheck != null) {
      await _scrollFormToTop();
      return precheck;
    }
    if (!_bondFormKey.currentState!.validate()) {
      await _scrollFormToTop();
      return '필수 입력값을 확인해 주세요.';
    }
    if (_bondBizFiles.isEmpty) {
      return '사업자등록증 파일을 1개 이상 첨부해주세요.';
    }
    if (_bondContractFiles.isEmpty) {
      return '계약서 파일을 1개 이상 첨부해주세요.';
    }
    final contractDate = DateTime.tryParse(_bondContractDate.text.trim());
    final endDate = DateTime.tryParse(_bondConstructionEndDate.text.trim());
    if (contractDate == null || endDate == null) {
      return '시공 시작일/종료일을 입력해주세요.';
    }
    if (endDate.isBefore(contractDate)) {
      return '시공 종료일은 시작일 이후여야 합니다.';
    }
    return null;
  }

  String _formatWonDisplay(int amount) {
    if (amount <= 0) return '-';
    final s = amount.toString();
    final chars = <String>[];
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      chars.add(s[i]);
      if (idx > 1 && idx % 3 == 1) chars.add(',');
    }
    return '${chars.join()}원';
  }

  String _fileNames(List<PlatformFile> files) =>
      files.isEmpty ? '-' : files.map((f) => f.name).join(', ');

  List<_ReviewSection> _buildReviewSections() {
    if (_domain == IssuanceDomain.taxInvoice) {
      final totalAmount = _parseMoney(_taxTotalAmount.text);
      final taxAmount = totalAmount ~/ 11;
      final supplyAmount = totalAmount - taxAmount;
      return [
        _ReviewSection(
          title: '기본 정보',
          rows: [
            ('구분', '세금계산서'),
            ('고객명(현장명)', _taxCustomerName.text.trim()),
            (
              '종사업자번호',
              _taxRegistrationNumber.text.trim().isEmpty
                  ? '-'
                  : _taxRegistrationNumber.text.trim(),
            ),
            ('발행요청일시', _taxIssueDate.text.trim()),
            ('부가세 포함 총액', _formatWonDisplay(totalAmount)),
            ('한글 금액', koreanWonInWords(totalAmount)),
            ('공급가액', _formatWonDisplay(supplyAmount)),
            ('세액', _formatWonDisplay(taxAmount)),
          ],
        ),
        _ReviewSection(
          title: '항목 설정',
          rows: [
            ('발행 퍼센트', '$_taxPercentage%'),
            ('항목 구분', _taxItemType),
            ('품목명', _taxItemName.text.trim()),
          ],
        ),
        _ReviewSection(
          title: '지사/옵션',
          rows: [
            ('지사', _taxBranch ?? '-'),
            (
              '이메일',
              _taxEmail.text.trim().isEmpty ? '-' : _taxEmail.text.trim(),
            ),
            ('MES 등록', _taxMesRegistered ? '예' : '아니오'),
            ('긴급 발급요청', _taxUrgent ? '예' : '아니오'),
          ],
        ),
        _ReviewSection(
          title: '첨부',
          rows: [('사업자등록증', _fileNames(_taxBizFiles))],
        ),
      ];
    }

    return [
      _ReviewSection(
        title: '증권 종류',
        rows: [('종류', _bondType)],
      ),
      _ReviewSection(
        title: '기본 정보',
        rows: [
          ('구분', '이행증권'),
          ('업체명', _bondCompanyName.text.trim()),
          (
            '이메일',
            _bondEmail.text.trim().isEmpty ? '-' : _bondEmail.text.trim(),
          ),
          (
            '계약금액(부가세 포함)',
            _formatWonDisplay(_parseMoney(_bondContractAmount.text)),
          ),
          (
            '한글 금액',
            koreanWonInWords(_parseMoney(_bondContractAmount.text)),
          ),
        ],
      ),
      _ReviewSection(
        title: '보증/기간',
        rows: [
          ('보증금율', '${_bondGuaranteeRate.text.trim()}%'),
          ('보증기간', '${_bondGuaranteePeriod.text.trim()}달'),
          ('시공 시작일', _bondContractDate.text.trim()),
          ('시공 종료일', _bondConstructionEndDate.text.trim()),
          (
            '요청기한',
            _bondRequestDeadline.text.trim().isEmpty
                ? '-'
                : _bondRequestDeadline.text.trim(),
          ),
        ],
      ),
      _ReviewSection(
        title: '첨부',
        rows: [
          ('사업자등록증', _fileNames(_bondBizFiles)),
          ('계약서', _fileNames(_bondContractFiles)),
        ],
      ),
    ];
  }

  Future<void> _onSavePressed() async {
    if (_saving) return;
    final user = ref.read(authControllerProvider);
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 정보가 필요합니다.')));
      return;
    }

    final validationError = await _validateCurrentForm();
    if (!mounted) return;
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final accent = _domain == IssuanceDomain.taxInvoice
        ? Colors.indigo.shade600
        : Colors.deepOrange.shade700;
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _IssuanceRequestReviewScreen(
          domain: _domain,
          accent: accent,
          sections: _buildReviewSections(),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _performSubmit(user.name);
  }

  Future<void> _performSubmit(String userName) async {
    setState(() => _saving = true);
    try {
      final _IssuanceSubmitResult result;
      if (_domain == IssuanceDomain.taxInvoice) {
        result = await _submitTax(userName);
      } else {
        result = await _submitBond(userName);
      }
      if (!mounted) return;
      await NotificationService.markIssuanceRequestSeen(
        prefs: ref.read(appDependenciesProvider).prefs,
        domain: result.domain,
        masterId: result.masterId,
        issueId: result.issueId,
      );
      ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.taxInvoice));
      ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.performanceBond));
      ref.invalidate(issuanceCancelledRowsProvider(IssuanceDomain.taxInvoice));
      ref.invalidate(issuanceCancelledRowsProvider(IssuanceDomain.performanceBond));
      ref.invalidate(issuanceRequestBadgeCountProvider);
      ref.invalidate(issuanceRequestTotalBadgeCountProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('발행요청이 등록되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(issuanceUserErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<_IssuanceSubmitResult> _submitTax(String userName) async {
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
    final invoiceNumber = _generateTaxInvoiceNumber();
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
          // issue_date 컬럼은 DATE 타입 — 날짜만 저장, 시간은 requester_date에.
          'issue_date': _taxIssueDateOnly(),
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
          // 발행요청일시(시간 포함)를 timestamp 컬럼인 requester_date에 저장.
          'requester_date': _taxIssueDateTimeIso(),
          'percentage': _taxPercentage,
          'mes_registered': _taxMesRegistered,
          'item_type': _taxItemType,
          'item_name': _taxItemName.text.trim(),
          'branch': _taxBranch,
          if (_taxEmail.text.trim().isNotEmpty) 'email': _taxEmail.text.trim(),
        })
        .select('id')
        .single();

    String? issueId;
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
      final issueInserted = await _client
          .from('tax_invoice_issues')
          .insert({
            'tax_invoice_id': invoiceId,
            'issue_date': _taxIssueDateOnly(),
            'issued_by': userName,
            'percentage': _taxPercentage,
            'issued_supply_amount': supplyAmount,
            'issued_tax_amount': taxAmount,
            'issued_total_amount': totalAmount,
            'invoice_image_url': null,
            'issue_order': currentMax + 1,
            'is_urgent': true,
          })
          .select('id')
          .single();
      issueId = issueInserted['id']?.toString();
    }

    return _IssuanceSubmitResult(
      domain: IssuanceDomain.taxInvoice,
      masterId: inserted['id'].toString(),
      issueId: issueId,
      displayName: _taxCustomerName.text.trim(),
    );
  }

  Future<_IssuanceSubmitResult> _submitBond(String userName) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final precheck = _firstBondValidationMessage();
    if (precheck != null) {
      await _scrollFormToTop();
      throw Exception(precheck);
    }
    if (!_bondFormKey.currentState!.validate()) {
      await _scrollFormToTop();
      throw Exception('필수 입력값을 확인해 주세요.');
    }
    if (_bondBizFiles.isEmpty) {
      throw Exception('사업자등록증 파일을 1개 이상 첨부해주세요.');
    }
    if (_bondContractFiles.isEmpty) throw Exception('계약서 파일을 1개 이상 첨부해주세요.');

    final contractAmount = _parseMoney(_bondContractAmount.text);
    final guaranteeRate = double.tryParse(_bondGuaranteeRate.text.trim()) ?? 0;
    final guaranteePeriod = _parseGuaranteePeriodMonths(
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

    final bondNumber = await _generateBondNumber();
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

    final issueInserted = await _client
        .from('performance_bond_issues')
        .insert({
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
        })
        .select('id')
        .single();

    return _IssuanceSubmitResult(
      domain: IssuanceDomain.performanceBond,
      masterId: inserted['id'].toString(),
      issueId: issueInserted['id']?.toString(),
      displayName: _bondCompanyName.text.trim().isNotEmpty
          ? _bondCompanyName.text.trim()
          : _bondType,
    );
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
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final actionsBottom = 12.0 + safeBottom;
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
            // 키보드가 떠도 전체 화면을 폼 스크롤에 쓸 수 있도록
            // 헤더·전환 버튼·항목 구분도 스크롤 영역 안에 둔다.
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(inputDecorationTheme: inputTheme),
              child: SingleChildScrollView(
                controller: _formScrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.25),
                        ),
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
                    const SizedBox(height: 12),
                    SegmentedButton<IssuanceDomain>(
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
                    const SizedBox(height: 10),
                    if (isTax) _buildTaxItemTypeSelector(accent),
                    if (!isTax) _buildBondTypeSelector(accent),
                    const SizedBox(height: 8),
                    _domain == IssuanceDomain.taxInvoice
                        ? _buildTaxForm()
                        : _buildBondForm(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: actionsBottom,
            child: FloatingActionButton.extended(
              onPressed: _saving ? null : _onSavePressed,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTaxUrgentCheckbox() {
    final urgentColor = Colors.red.shade600;
    return Container(
      decoration: BoxDecoration(
        color: _taxUrgent
            ? urgentColor.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _taxUrgent
              ? urgentColor.withValues(alpha: 0.6)
              : Colors.grey.shade300,
          width: _taxUrgent ? 1.6 : 1.2,
        ),
      ),
      child: CheckboxListTile(
        value: _taxUrgent,
        onChanged: (v) => setState(() => _taxUrgent = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: urgentColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        title: Row(
          children: [
            Text(
              '긴급 발급요청',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: _taxUrgent ? urgentColor : Colors.grey.shade800,
              ),
            ),
            const SizedBox(width: 6),
            if (_taxUrgent)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: urgentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '긴급',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '우선 처리가 필요한 경우 체크하세요',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildTaxForm() {
    return Form(
      key: _taxFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTaxUrgentCheckbox(),
          const SizedBox(height: 12),
          _sectionCard(
            title: '기본 정보',
            child: Column(
              children: [
                TextFormField(
                  controller: _taxCustomerName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '고객명(현장명) *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '고객명을 입력하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _taxRegistrationNumber,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '종사업자번호',
                    hintText: '000-00-00000',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _taxIssueDate,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: '발행요청일시 *',
                    suffixIcon: Icon(Icons.calendar_month_rounded, size: 20),
                  ),
                  onTap: () => _pickDateTime(_taxIssueDate),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '발행요청일시를 선택하세요.' : null,
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
                _buildKoreanAmountHint(_taxTotalAmount),
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
                        onChanged: (v) => setState(() {
                          _taxPercentage = v.round();
                          _taxPercentageCtrl.text = '$_taxPercentage';
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 78,
                      child: TextFormField(
                        controller: _taxPercentageCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: const InputDecoration(
                          suffixText: '%',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v.trim());
                          if (n == null) return;
                          final clamped = n.clamp(1, 100);
                          setState(() => _taxPercentage = clamped);
                        },
                        onEditingComplete: () {
                          // 범위 밖 입력(0, 999 등)은 확정 시 보정.
                          _taxPercentageCtrl.text = '$_taxPercentage';
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '품목명 *',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.indigo.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _taxItemNameOptions)
                        _buildTypeChip(
                          label: option,
                          selected: _taxItemNameChoice == option,
                          selectedBg: _itemNameChipColors(option).$1,
                          selectedFg: _itemNameChipColors(option).$2,
                          onTap: () => setState(() {
                            _taxItemNameChoice = option;
                            _taxItemName.text = option;
                          }),
                        ),
                      _buildTypeChip(
                        label: '기타(직접작성)',
                        selected: _taxItemNameChoice == '기타',
                        selectedBg: Colors.blueGrey.shade100,
                        selectedFg: Colors.blueGrey.shade900,
                        onTap: () => setState(() {
                          _taxItemNameChoice = '기타';
                          if (_taxItemNameOptions.contains(
                            _taxItemName.text.trim(),
                          )) {
                            _taxItemName.clear();
                          }
                        }),
                      ),
                    ],
                  ),
                ),
                if (_taxItemNameChoice == '기타') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _taxItemName,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '품목명 직접 입력 *',
                      hintText: '예: 방화문, 자동문',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '품목명을 입력하세요.' : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '지사/옵션',
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '지사 *',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.indigo.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _branchOptions.isEmpty
                      ? Text(
                          '지사 목록을 불러오는 중...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < _branchOptions.length; i++)
                              _buildTypeChip(
                                label: _branchOptions[i],
                                selected: _taxBranch == _branchOptions[i],
                                selectedBg: _branchChipColors(i).$1,
                                selectedFg: _branchChipColors(i).$2,
                                onTap: () => setState(
                                  () => _taxBranch = _branchOptions[i],
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taxEmail,
                  textInputAction: TextInputAction.done,
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

  Widget _buildTaxItemTypeSelector(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '항목 구분 *',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: accent,
              fontSize: 13,
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
                selectedBg: Colors.purple.shade100,
                selectedFg: Colors.purple.shade900,
                onTap: () => setState(() => _taxItemType = '잔금'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBondTypeSelector(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '증권 종류 *',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: accent,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['계약이행', '선급금', '하자이행'].map((type) {
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
              return _buildTypeChip(
                label: type,
                selected: selected,
                selectedBg: selectedBg,
                selectedFg: selectedFg,
                onTap: () {
                  setState(() {
                    _bondType = type;
                    _applyBondDefaultsByType(type);
                  });
                },
              );
            }).toList(),
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
            title: '기본 정보',
            child: Column(
              children: [
                TextFormField(
                  controller: _bondCompanyName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '업체명 *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '업체명을 입력하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bondEmail,
                  textInputAction: TextInputAction.next,
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
                _buildKoreanAmountHint(_bondContractAmount),
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
                  textInputAction: TextInputAction.next,
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
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '보증기간(달) *',
                    hintText: '예: 1, 6, 12',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => _parseGuaranteePeriodMonths(v ?? '') <= 0
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

class _ReviewSection {
  const _ReviewSection({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;
}

class _IssuanceRequestReviewScreen extends StatelessWidget {
  const _IssuanceRequestReviewScreen({
    required this.domain,
    required this.accent,
    required this.sections,
  });

  final IssuanceDomain domain;
  final Color accent;
  final List<_ReviewSection> sections;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isTax = domain == IssuanceDomain.taxInvoice;
    return Scaffold(
      appBar: AppBar(
        title: const Text('등록 내용 확인'),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Icon(
                  isTax ? Icons.receipt_long_rounded : Icons.gavel_rounded,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '아래 내용을 확인한 뒤 저장하세요.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: accent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                for (final section in sections) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final (label, value) in section.rows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 118,
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('수정'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('확인 · 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssuanceSubmitResult {
  const _IssuanceSubmitResult({
    required this.domain,
    required this.masterId,
    this.issueId,
    required this.displayName,
  });

  final IssuanceDomain domain;
  final String masterId;
  final String? issueId;
  final String displayName;
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
