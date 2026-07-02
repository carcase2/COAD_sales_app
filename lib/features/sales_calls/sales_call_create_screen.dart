import 'dart:io';
import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/searchable_region_picker.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/data/sales_call_consultation.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_editor_screen.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/sales_call_draft.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -- New Global State for Selections --
// We keep them in the state class

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
  final _regionCtrl = TextEditingController();
  
  void _onPhoneChanged(String value) {
    // 숫자만 추출
    String digits = value.replaceAll(RegExp(r'\D'), '');
    String formatted = '';
    
    if (digits.length <= 3) {
      formatted = digits;
    } else if (digits.length <= 7) {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else if (digits.length <= 11) {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } else {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, 11)}';
    }

    if (formatted != value) {
      _phoneCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

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

  void _ensureDefaultClassification(MasterDataBundle master) {
    if (_productId == null && master.productCategories.isNotEmpty) {
      _productId = master.productCategories
          .firstWhere(
            (e) => e.name.contains('스피드도어'),
            orElse: () => master.productCategories.first,
          )
          .id;
    }
    if (_methodId == null && master.inquiryMethods.isNotEmpty) {
      _methodId = master.inquiryMethods
          .firstWhere(
            (e) => e.name.contains('유선'),
            orElse: () => master.inquiryMethods.first,
          )
          .id;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _inquiryCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(MasterDataBundle master) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목을 확인해 주세요.')),
      );
      return;
    }
    if (_regionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배정될 지역을 선택해주세요.')),
      );
      return;
    }
    if (_inquiryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문의내용 본문을 입력해주세요.')),
      );
      return;
    }
    final reg = registrationStatus(isSimpleInquiry: _isSimpleInquiry);

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
        'status_id': reg.statusId,
        'call_stage': reg.callStage,
        if (user != null) 'created_by': user.id,
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
        final effectiveManager = (e['effective_manager'] ?? e['manager'] ?? '')
            .toString()
            .trim();
        // 임시 담당 오버레이는 표시 전용이며 저장은 assigned_to만 사용한다.
        if (effectiveManager.isNotEmpty) {
          body['assigned_to'] = effectiveManager;
        }
        if (e['branch_type'] != null) body['region_branch_type'] = e['branch_type'];
      }

      if (_uploadedImageUrls.isNotEmpty) {
        body['images'] = List<String>.from(_uploadedImageUrls);
      }

      final draft = SalesCallDraft(
        customerName: (body['customer_name'] ?? '').toString(),
        customerPhone: (body['customer_phone'] ?? '').toString(),
        inquiryContent: (body['inquiry_content'] ?? '').toString(),
        regionId: (body['region_id'] ?? '').toString(),
        regionSido: (body['region_sido'] ?? '').toString(),
        regionName: (body['region_name'] ?? '').toString(),
        assignedTo: (body['assigned_to'] ?? '').toString(),
        productCategoryId: body['product_category_id']?.toString(),
        inquiryMethodId: body['inquiry_method_id']?.toString(),
        statusId: reg.statusId,
        createdBy: body['created_by']?.toString(),
        callStage: body['call_stage'],
        images: _uploadedImageUrls,
      );

      final created = await ref.read(salesCallsRepositoryProvider).createSalesCall(draft);
      // 로컬 알림 표시 실패가 접수 저장 성공을 덮어쓰지 않도록 분리한다.
      try {
        await NotificationService.showSalesCallRegisteredAlert(
          callId: created.id,
          customerName: created.customerName ?? '',
          phone: created.customerPhone ?? '',
          assigneeName: user?.name,
        );
      } catch (e) {
        debugPrint('[local-registered-alert] failed: $e');
      }
      // 백엔드 트리거가 누락된 환경에서도 새 통화 푸시가 가도록 Edge Function을 직접 호출
      try {
        final res = await Supabase.instance.client.functions.invoke(
          'notify-new-call',
          body: {
            'type': 'INSERT',
            'record': {
              'id': created.id,
              'customer_name': created.customerName,
              'customer_phone': created.customerPhone,
              'inquiry_content': created.inquiryContent,
              'product_category_id': created.productCategoryId,
              'region_sido': created.regionSido,
              'region_name': created.regionName,
              'assigned_to': created.assignedTo,
            },
          },
        );
        debugPrint('[notify-new-call] status=${res.status} data=${res.data}');
        if (res.status >= 400) {
          debugPrint('[notify-new-call] push invoke returned error status');
        }
      } catch (e, st) {
        debugPrint('[notify-new-call] invoke failed: $e');
        debugPrint('$st');
        // 푸시 실패가 접수 저장 흐름을 막지 않도록 무시
      }
      
      if (!mounted) return;
      navigateToHomeAndRefresh(
        context,
        ref,
        message: '접수가 완료되었습니다.',
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
      debugPrint('[SalesCallCreateScreen._submit] failed: $e');
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

  /// 작성 중 내용이 있는지 — 이탈 확인 다이얼로그 표시 기준.
  bool get _hasUnsavedInput =>
      _nameCtrl.text.trim().isNotEmpty ||
      _phoneCtrl.text.trim().isNotEmpty ||
      _inquiryCtrl.text.trim().isNotEmpty ||
      _uploadedImageUrls.isNotEmpty;

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedInput || _submitting) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('작성 취소'),
        content: const Text('작성 중인 접수 내용이 있습니다.\n저장하지 않고 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 작성'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final masterAsync = ref.watch(salesCallCreateMasterDataProvider);
    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      // 컨트롤러 입력은 rebuild를 트리거하지 않으므로 항상 수동 pop 경로로 처리.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('새 접수 등록', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text(
              '한 화면에서 입력 · 아래로 스크롤',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            if (await _confirmDiscard() && context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () async {
              if (await _confirmDiscard() && context.mounted) {
                navigateToHomeAndRefresh(context, ref);
              }
            },
            tooltip: '홈으로 이동',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: masterAsync.when(
                data: (master) => _buildUnifiedForm(master, user?.name ?? '작성자'),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(koreanErrorMessage(e), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () =>
                              ref.invalidate(salesCallCreateMasterDataProvider),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            masterAsync.maybeWhen(
              data: (master) => _buildFixedFooter(master),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildUnifiedForm(MasterDataBundle master, String authorName) {
    final scheme = Theme.of(context).colorScheme;
    _ensureDefaultClassification(master);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _buildSectionHeader('분류', Icons.dashboard_customize_outlined, scheme),
          const SizedBox(height: 12),
          _buildStepSubsectionTitle('제품군', scheme),
          const SizedBox(height: 8),
          _buildChoiceChipGroup(
            items: master.productCategories,
            selectedValue: _productId,
            onSelected: (id) => setState(() => _productId = id),
            selectedColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          _buildStepSubsectionTitle('문의 경로', scheme),
          const SizedBox(height: 8),
          _buildChoiceChipGroup(
            items: master.inquiryMethods,
            selectedValue: _methodId,
            onSelected: (id) => setState(() => _methodId = id),
            selectedColor: const Color(0xFF0EA5E9),
          ),
          const SizedBox(height: 12),
          _buildSimpleInquiryToggle(scheme),
          const SizedBox(height: 20),
          _buildSectionDivider(scheme),
          _buildSectionHeader('고객', Icons.contact_mail_outlined, scheme),
          const SizedBox(height: 12),
          _buildCard(
            scheme: scheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '연락처 · 고객명',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _aiBusy || _uploadBusy
                          ? null
                          : () => _scanBusinessCard(master),
                      icon: _aiBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.contact_page_outlined, size: 16),
                      label: const Text('명함', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  label: '연락처 *',
                  controller: _phoneCtrl,
                  hint: '010-0000-0000',
                  keyboardType: TextInputType.phone,
                  onChanged: _onPhoneChanged,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '번호를 입력해주세요' : null,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: '고객명/상호명',
                  controller: _nameCtrl,
                  hint: '고객성함 또는 회사명',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(
            scheme: scheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '지역 배정 *',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 10),
                SearchableRegionPicker(
                  regions: master.regions,
                  value: _regionId,
                  decoration: _inputDecoration('지역 검색 · 선택').copyWith(
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  ),
                  onChanged: (v) => setState(() => _regionId = v),
                  validator: (v) => v == null ? '지역을 선택해주세요' : null,
                ),
                if (_regionId != null) ...[
                  const SizedBox(height: 10),
                  _buildRegionSummary(master, scheme),
                ],
                const SizedBox(height: 12),
                _buildTextField(
                  label: '등록 담당자',
                  initialValue: authorName,
                  readOnly: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionDivider(scheme),
          _buildSectionHeader('문의', Icons.edit_note_rounded, scheme),
          const SizedBox(height: 12),
          _buildTextField(
            label: '문의 내용 *',
            controller: _inquiryCtrl,
            maxLines: 5,
            hint: '고객 요청·문의 내용을 입력하세요',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '문의내용을 입력해주세요' : null,
          ),
          const SizedBox(height: 12),
          _buildCard(
            scheme: scheme,
            child: SalesCallAttachmentsStrip(
              urls: _uploadedImageUrls,
              editable: true,
              uploadBusy: _uploadBusy,
              progressLabel:
                  _uploadTotal > 0 ? '전송 중 ($_uploadCurrent/$_uploadTotal)' : null,
              onAdd: () => _pickAndUpload(master),
              onRemoveAt: (i) => setState(() => _uploadedImageUrls.removeAt(i)),
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }

  Widget _buildSectionDivider(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(color: scheme.outlineVariant.withValues(alpha: 0.35)),
    );
  }

  Widget _buildCard({required ColorScheme scheme, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }

  Widget _buildRegionSummary(MasterDataBundle master, ColorScheme scheme) {
    try {
      final selectedRegion = master.regions.firstWhere((r) => r.id == _regionId);
      final sido = selectedRegion.extra['sido']?.trim() ?? '-';
      final region = selectedRegion.extra['region']?.trim() ?? '-';
      final effectiveManager =
          selectedRegion.extra['effective_manager']?.trim() ??
              selectedRegion.extra['manager']?.trim() ??
              '미지정';
      final originalManager =
          selectedRegion.extra['original_manager']?.trim() ??
              selectedRegion.extra['manager']?.trim() ??
              '미지정';
      final isOverridden = selectedRegion.extra['is_overridden'] == 'true';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Expanded(child: _buildDetailItem('시/도', sido, scheme)),
            Expanded(child: _buildDetailItem('지역', region, scheme)),
            Expanded(
              child: _buildDetailItem(
                isOverridden ? '임시 담당' : '담당',
                isOverridden ? '$effectiveManager\n(원:$originalManager)' : effectiveManager,
                scheme,
                isHighlight: true,
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildSimpleInquiryToggle(ColorScheme scheme) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _isSimpleInquiry = !_isSimpleInquiry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isSimpleInquiry
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isSimpleInquiry ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _isSimpleInquiry,
              onChanged: (v) => setState(() => _isSimpleInquiry = v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('단순 문의 즉시 종료', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    '배정 없이 리드 단계에서 바로 종결',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChipGroup({
    required List<NamedMasterRow> items,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
    required Color selectedColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final selected = selectedValue == item.id;
        return FilterChip(
          label: Text(
            item.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          selected: selected,
          showCheckmark: true,
          checkmarkColor: selectedColor,
          selectedColor: selectedColor.withValues(alpha: 0.18),
          side: BorderSide(
            color: selected
                ? selectedColor
                : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onSelected(item.id);
          },
        );
      }).toList(),
    );
  }

  Widget _buildFixedFooter(MasterDataBundle master) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: _submitting
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  _submit(master);
                },
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '접수 등록',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, ColorScheme scheme, {bool isHighlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w800, 
            color: isHighlight ? scheme.primary : scheme.onSurface,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ─── 유틸 ───
  Widget _buildSectionHeader(String title, IconData icon, ColorScheme scheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: scheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 22, color: scheme.primary),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildStepSubsectionTitle(String title, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          maxLines: maxLines,
          readOnly: readOnly,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15),
          decoration: _inputDecoration(hint ?? ''),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 2)),
      filled: true,
      fillColor: scheme.surface,
    );
  }
}
