import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:file_picker/file_picker.dart';
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SalesCallCreateScreen extends ConsumerStatefulWidget {
  const SalesCallCreateScreen({super.key});

  @override
  ConsumerState<SalesCallCreateScreen> createState() => _SalesCallCreateScreenState();
}

class _SalesCallCreateScreenState extends ConsumerState<SalesCallCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _inquiryCtrl = TextEditingController();
  final _regionCtrl = TextEditingController(); // Search-like field if needed, but we keep the logic
  
  String? _productId;
  String? _regionId;
  String? _methodId;
  int? _statusId = 1;
  bool _submitting = false;
  bool _isSimpleInquiry = false;
  final List<String> _uploadedImageUrls = [];
  bool _uploadBusy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _inquiryCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(MasterDataBundle master) async {
    if (!_formKey.currentState!.validate()) return;
    
    // 단순문의로 바로 마무리 체크 시 status_id = 4 (단순문의) 강제 설정 로직 예시
    final targetStatusId = _isSimpleInquiry ? 4 : (_statusId ?? 1);

    setState(() => _submitting = true);
    try {
      final user = ref.read(authControllerProvider);
      final body = <String, dynamic>{
        'customer_name': _nameCtrl.text.trim().isEmpty ? '상호없음' : _nameCtrl.text.trim(),
        'customer_phone': _phoneCtrl.text.trim(),
        'inquiry_content': _inquiryCtrl.text.trim(),
        if (_productId != null) 'product_category_id': _productId,
        if (_regionId != null) 'region_id': _regionId,
        if (_methodId != null) 'inquiry_method_id': _methodId,
        'status_id': targetStatusId,
        if (user != null) 'created_by': user.id,
        'call_stage': _isSimpleInquiry ? '종료' : '1차',
      };

      NamedMasterRow? regionRow;
      if (_regionId != null) {
        for (final r in master.regions) {
          if (r.id == _regionId) { regionRow = r; break; }
        }
      }
      if (regionRow != null) {
        final e = regionRow.extra;
        if (e['sido'] != null) body['region_sido'] = e['sido'];
        if (e['region'] != null) body['region_name'] = e['region'];
        if (e['manager'] != null) body['region_manager'] = e['manager'];
        if (e['branch_type'] != null) body['region_branch_type'] = e['branch_type'];
      }

      if (_uploadedImageUrls.isNotEmpty) {
        body['images'] = List<String>.from(_uploadedImageUrls);
      }

      final created = await ref.read(salesCallsRepositoryProvider).createCall(body);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SalesCallDetailScreen(id: created.id, initial: created),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _siteNameForUpload(MasterDataBundle master) {
    if (_regionId == null) return 'coad_home';
    for (final r in master.regions) {
      if (r.id == _regionId && r.name.trim().isNotEmpty) return r.name.trim();
    }
    return 'coad_home';
  }

  Future<void> _pickAndUpload(MasterDataBundle master) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'heic', 'heif', 'tif', 'tiff', 'pdf',
      ],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploadBusy = true);
    final site = _siteNameForUpload(master);
    final uploader = ref.read(b2UploadRepositoryProvider);

    try {
      for (final f in result.files) {
        final path = f.path;
        if (path == null) continue;
        if (!isAllowedPickerPath(path)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('건너뜀: ${f.name} (지원하지 않는 형식)')),
            );
          }
          continue;
        }
        try {
          final url = await uploader.uploadSalesCallFile(filePath: path, siteName: site);
          if (mounted) setState(() => _uploadedImageUrls.add(url));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(koreanErrorMessage(e))),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _uploadBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterAsync = ref.watch(masterDataProvider);
    final user = ref.watch(authControllerProvider);

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('새 통화 등록'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: masterAsync.when(
        data: (master) => _buildForm(master, user?.name ?? '작성자'),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(koreanErrorMessage(e))),
      ),
    );
  }

  Widget _buildForm(MasterDataBundle master, String authorName) {
    // 기본값 자동 설정 로직 (처음 로드 시 1회)
    if (_productId == null && master.productCategories.isNotEmpty) {
      final speedDoor = master.productCategories.firstWhere((e) => e.name.contains('스피드도어'), orElse: () => master.productCategories.first);
      _productId = speedDoor.id;
    }
    if (_methodId == null && master.inquiryMethods.isNotEmpty) {
      final yuseon = master.inquiryMethods.firstWhere((e) => e.name.contains('유선'), orElse: () => master.inquiryMethods.first);
      _methodId = yuseon.id;
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── 제품군 (세로 배치로 공간 확보) ───
          Text('제품군', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildGrid(
            context: context,
            items: master.productCategories,
            selectedValue: _productId,
            onSelected: (id) => setState(() => _productId = id),
            selectedColor: const Color(0xFFC62828),
            crossAxisCount: 3,
            childAspectRatio: 2.8,
          ),

          const SizedBox(height: 24),

          // ─── 문의방법 (제품군 아래로 이동) ───
          Text('문의방법 *', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildGrid(
            context: context,
            items: master.inquiryMethods,
            selectedValue: _methodId,
            onSelected: (id) => setState(() => _methodId = id),
            selectedColor: const Color(0xFFE65100),
            crossAxisCount: 3,
            childAspectRatio: 2.8,
          ),

          const SizedBox(height: 32),

          // ─── 고객명 & 연락처 ───
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: '고객명/상호명',
                  controller: _nameCtrl,
                  hint: '고객명 또는 상호명을 입력하세요',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: '연락처 *',
                  controller: _phoneCtrl,
                  hint: '010-1234-5678',
                  validator: (v) => (v == null || v.trim().isEmpty) ? '번호 필수' : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── 지역 & 작성자 ───
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '지역 *',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: _regionId,
                      decoration: _inputDecoration('지역명을 선택하세요'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('반드시 선택하세요')),
                        ...master.regions.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name, style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() => _regionId = v),
                      validator: (v) => v == null ? '지역 필수' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: '작성자',
                  initialValue: authorName,
                  readOnly: true,
                  hint: '로그인한 사용자로 자동 설정',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── 문의 내용 ───
          _buildTextField(
            label: '문의 내용 *',
            controller: _inquiryCtrl,
            maxLines: 5,
            hint: '고객 문의 내용을 간단히 입력해 주세요.',
            validator: (v) => (v == null || v.trim().isEmpty) ? '내용 필수' : null,
          ),

          const SizedBox(height: 20),

          Text(
            '첨부 (사진·PDF)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SalesCallAttachmentsStrip(
                urls: _uploadedImageUrls,
                editable: true,
                uploadBusy: _uploadBusy,
                onAdd: () => _pickAndUpload(master),
                onRemoveAt: (i) => setState(() => _uploadedImageUrls.removeAt(i)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── 단순문의 처리 옵션 ───
          Row(
            children: [
              Checkbox(
                value: _isSimpleInquiry,
                onChanged: (v) => setState(() => _isSimpleInquiry = v ?? false),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이번 통화는 단순문의로 바로 마무리',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '체크하면 상담결과가 단순문의로 저장되어 추가 상담 없이 완료됩니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 48),

          // ─── 하단 액션 버튼 ───
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : () => _submit(master),
                  child: _submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text('등록'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGrid({
    required BuildContext context,
    required List<NamedMasterRow> items,
    required String? selectedValue,
    required Function(String) onSelected,
    required Color selectedColor,
    required int crossAxisCount,
    double childAspectRatio = 2.5,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, idx) {
        final item = items[idx];
        final isSelected = selectedValue == item.id;
        return InkWell(
          onTap: () => onSelected(item.id),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : scheme.surface,
              border: Border.all(
                color: isSelected ? selectedColor : scheme.outlineVariant.withValues(alpha: 0.65),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : scheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          maxLines: maxLines,
          readOnly: readOnly,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: _inputDecoration(hint),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        fontSize: 13,
      ),
    );
  }
}
