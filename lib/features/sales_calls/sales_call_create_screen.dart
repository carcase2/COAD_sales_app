import 'dart:io';
import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_editor_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
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
  int _uploadTotal = 0;
  int _uploadCurrent = 0;
  bool _aiBusy = false;

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
        'call_stage': _isSimpleInquiry ? '종료' : null,
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
    } on OfflineException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 목록으로 돌아감
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.blueGrey,
          duration: const Duration(seconds: 4),
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

    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => isAllowedPickerPath(p))
        .toList();

    if (paths.isEmpty) return;

    // 이미지만 골라내서 편집 기회 제공 (1건일 때만 우선 자동 제안)
    List<String> finalPaths = [];
    if (paths.length == 1 && isImageFile(paths.first)) {
      final editedFile = await Navigator.push<File?>(
        context,
        MaterialPageRoute(builder: (_) => ImageEditorScreen(initialImage: File(paths.first))),
      );
      finalPaths = [editedFile?.path ?? paths.first];
    } else {
      finalPaths = List.from(paths);
    }

    setState(() {
      _uploadBusy = true;
      _uploadTotal = finalPaths.length;
      _uploadCurrent = 0;
    });

    final site = _siteNameForUpload(master);
    final uploader = ref.read(b2UploadRepositoryProvider);

    try {
      // 병렬 업로드 수행
      await Future.wait(finalPaths.map((path) async {
        try {
          final url = await uploader.uploadSalesCallFile(
            filePath: path,
            siteName: site,
            customerPhone: _phoneCtrl.text,
          );
          if (mounted) {
            setState(() {
              _uploadedImageUrls.add(url);
              _uploadCurrent++;
            });
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('업로드 실패 (${p.basename(path)}): ${koreanErrorMessage(e)}')),
            );
          }
        }
      }));
    } finally {
      if (mounted) {
        setState(() {
          _uploadBusy = false;
          _uploadTotal = 0;
          _uploadCurrent = 0;
        });
      }
    }
  }

  Future<void> _scanBusinessCard(MasterDataBundle master) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.first.path;
    if (path == null) return;

    setState(() => _aiBusy = true);
    
    try {
      // 1. 이미지 읽기
      final bytes = await File(path).readAsBytes();

      // 2. AI 분석 요청
      final aiResult = await ref.read(aiExtractorServiceProvider).extractBusinessCard(bytes);

      if (mounted) {
        setState(() {
          if (aiResult.name.isNotEmpty) _nameCtrl.text = aiResult.name;
          if (aiResult.phone.isNotEmpty) _phoneCtrl.text = aiResult.phone;
          // 상호명은 고객명 칸에 이름과 같이 넣거나, 이름이 있으면 회사명을 우선시할 수 있음
          if (aiResult.company.isNotEmpty && aiResult.name.isEmpty) {
            _nameCtrl.text = aiResult.company;
          } else if (aiResult.company.isNotEmpty && aiResult.name.isNotEmpty) {
            _nameCtrl.text = '${aiResult.name} (${aiResult.company})';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('명함 정보가 자동으로 입력되었습니다.')),
        );
      }

      // 3. 사진 자동 첨부 (기존 업로드 로직 재활용)
      final site = _siteNameForUpload(master);
      final uploader = ref.read(b2UploadRepositoryProvider);
      
      setState(() {
        _uploadBusy = true;
        _uploadTotal = 1;
        _uploadCurrent = 0;
      });

      final url = await uploader.uploadSalesCallFile(
        filePath: path,
        siteName: site,
        customerPhone: _phoneCtrl.text,
      );

      if (mounted) {
        setState(() => _uploadedImageUrls.add(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('명함 인식 실패: ${koreanErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _aiBusy = false;
          _uploadBusy = false;
          _uploadTotal = 0;
          _uploadCurrent = 0;
        });
      }
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
        title: const Text('새 통화 등록', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
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
      bottomNavigationBar: masterAsync.when(
        data: (master) => _buildFixedFooter(master),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildFixedFooter(MasterDataBundle master) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('취소'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _submitting ? null : () => _submit(master),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('접수 등록', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(MasterDataBundle master, String authorName) {
    final scheme = Theme.of(context).colorScheme;
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
          _buildFormSectionTitle('제품군 분류', Icons.category_outlined, scheme),
          const SizedBox(height: 16),
          _buildGrid(
            context: context,
            items: master.productCategories,
            selectedValue: _productId,
            onSelected: (id) => setState(() => _productId = id),
            selectedColor: scheme.primary,
            crossAxisCount: 3,
            childAspectRatio: 2.8,
          ),

          const SizedBox(height: 32),

          // ─── 문의방법 (제품군 아래로 이동) ───
          _buildFormSectionTitle('문의 경로 *', Icons.campaign_outlined, scheme),
          const SizedBox(height: 16),
          _buildGrid(
            context: context,
            items: master.inquiryMethods,
            selectedValue: _methodId,
            onSelected: (id) => setState(() => _methodId = id),
            selectedColor: scheme.secondary,
            crossAxisCount: 3,
            childAspectRatio: 2.8,
          ),

          const SizedBox(height: 40),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 32),

          // ─── 고객명 & 연락처 ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildFormSectionTitle('고객 및 연락처 정보', Icons.person_outline, scheme),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: _aiBusy || _uploadBusy ? null : () => _scanBusinessCard(master),
                  icon: _aiBusy 
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.contact_page_outlined, size: 16),
                  label: const Text('명함 스캔', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: scheme.primary,
                    backgroundColor: scheme.primary.withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: '고객명/상호명',
                  controller: _nameCtrl,
                  hint: '고객명 입력',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: '연락처 *',
                  controller: _phoneCtrl,
                  hint: '010-0000-0000',
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: _regionId,
                      isExpanded: true,
                      decoration: _inputDecoration('지역 선택'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null, 
                          child: Text('지역을 선택하세요', style: TextStyle(fontSize: 13)),
                        ),
                        ...master.regions.map((e) => DropdownMenuItem<String?>(
                          value: e.id, 
                          child: Text(e.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        )),
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
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ─── 문의 내용 ───
          _buildFormSectionTitle('문의 내용 요약 *', Icons.edit_note_rounded, scheme),
          const SizedBox(height: 12),
          _buildTextField(
            label: '',
            controller: _inquiryCtrl,
            maxLines: 5,
            hint: '고객의 요청 사항을 기록하세요...',
            validator: (v) => (v == null || v.trim().isEmpty) ? '내용 필수' : null,
          ),

          const SizedBox(height: 32),

          _buildFormSectionTitle('첨부 파일 자료', Icons.attach_file_rounded, scheme),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SalesCallAttachmentsStrip(
                urls: _uploadedImageUrls,
                editable: true,
                uploadBusy: _uploadBusy,
                progressLabel: _uploadTotal > 0 ? '전송 중 ($_uploadCurrent/$_uploadTotal)' : null,
                onAdd: () => _pickAndUpload(master),
                onRemoveAt: (i) => setState(() => _uploadedImageUrls.removeAt(i)),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ─── 단순문의 처리 옵션 ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _isSimpleInquiry,
                    onChanged: (v) => setState(() => _isSimpleInquiry = v ?? false),
                    activeColor: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '단순 문의로 상담 종료',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '체크 시 진행 단계가 자동으로 종료됩니다.',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildFormSectionTitle(String title, IconData icon, ColorScheme scheme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
