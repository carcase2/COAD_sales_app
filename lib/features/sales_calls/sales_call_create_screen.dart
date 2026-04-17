import 'dart:io';
import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/searchable_region_picker.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_create_screen.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/main/main_tab_screen.dart';
import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_editor_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  
  int _currentStep = 0;
  bool _aiBusy = false;
  bool _quickActionsOpen = false;

  void _nextStep() {
    if (_currentStep == 1) {
      if (!_formKey.currentState!.validate()) return;
    }
    if (_currentStep < 2) {
      HapticFeedback.selectionClick();
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      HapticFeedback.selectionClick();
      setState(() => _currentStep--);
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
    // 3단계에서는 _formKey가 화면에 없으므로(1~2단계 폼) 수동 검증
    if (_regionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배정될 지역을 선택해주세요.')),
      );
      // 2단계로 돌려보내서 선택하게 유도
      setState(() => _currentStep = 1);
      return;
    }
    if (_inquiryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문의내용 본문을 입력해주세요.')),
      );
      return;
    }
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
        if (_isSimpleInquiry) 'call_stage': '종료',
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
      
      // 홈 화면 데이터 무기본화(새로고침 예약)
      ref.invalidate(todayStatsProvider);
      ref.invalidate(todayCallsContentProvider);
      ref.invalidate(rankingCallsProvider);

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
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final actionsBottom = 12.0 + safeBottom;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('새 통화 등록', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const MainTabScreen()),
                (route) => false,
              );
            },
            tooltip: '홈으로 이동',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: _buildStepIndicator(scheme),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: masterAsync.when(
                data: (master) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepContent(master, user?.name ?? '작성자'),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(koreanErrorMessage(e))),
              ),
            ),
            masterAsync.maybeWhen(
              data: (master) => _buildFixedFooter(master),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_quickActionsOpen)
            Container(
              width: 182,
              constraints: const BoxConstraints(maxHeight: 240),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
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
                  children: [
                    _quickActionTile(
                      icon: Icons.home_rounded,
                      label: '홈',
                      color: Colors.blueGrey.shade700,
                      onTap: () async {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                    ),
                    _quickActionTile(
                      icon: Icons.pending_actions_rounded,
                      label: '미통화',
                      color: Colors.orange.shade700,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SalesCallListScreen(
                              mode: ListQueryMode.incomplete,
                              date: todayYmdSeoul(),
                            ),
                          ),
                        );
                      },
                    ),
                    _quickActionTile(
                      icon: Icons.event_note_rounded,
                      label: '금일팔로우',
                      color: Colors.deepPurple.shade600,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SalesCallListScreen(
                              mode: ListQueryMode.incompleteByDate,
                              date: todayYmdSeoul(),
                              initialAssignee: '전체',
                            ),
                          ),
                        );
                      },
                    ),
                    _quickActionTile(
                      icon: Icons.calendar_view_week_rounded,
                      label: '달력',
                      color: Colors.green.shade700,
                      onTap: () async {
                        requestConsultationCalendarWeekNavigation(ref);
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                    ),
                    _quickActionTile(
                      icon: Icons.calculate_rounded,
                      label: '견적기',
                      color: Colors.teal.shade600,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('견적기')),
                              body: const QuoterScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                    _quickActionTile(
                      icon: Icons.receipt_long_rounded,
                      label: '발행요청',
                      color: Colors.indigo.shade600,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (_) => const IssuanceRequestCreateScreen(
                              initialDomain: IssuanceDomain.taxInvoice,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: actionsBottom),
            child: FloatingActionButton(
              heroTag: 'call_create_open_menu',
              mini: true,
              backgroundColor: scheme.primary,
              foregroundColor: Colors.white,
              tooltip: _quickActionsOpen ? '닫기' : '열기',
              onPressed: () => setState(() => _quickActionsOpen = !_quickActionsOpen),
              child: Icon(_quickActionsOpen ? Icons.close_rounded : Icons.menu_open_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            setState(() => _quickActionsOpen = false);
            await onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToStep(int targetIndex) {
    // 자유롭게 이동 가능하게 하되, 이동 시 키보드를 내림 (UX 개선)
    FocusScope.of(context).unfocus();
    setState(() => _currentStep = targetIndex);
  }

  bool _isStepCompleted(int index) {
    if (index == 0) return true; // 기본 분류는 보통 초기값이 있음
    if (index == 1) return _phoneCtrl.text.trim().isNotEmpty && _regionId != null;
    if (index == 2) return _inquiryCtrl.text.trim().isNotEmpty;
    return false;
  }

  Widget _buildStepIndicator(ColorScheme scheme) {
    final stepNames = ['분류', '정보', '내용'];
    // 각 스텝별 고유 색상 배정: 0(분류) - 에메랄드, 1(정보) - 스카이블루, 2(내용) - 프라이머리
    final colors = [
      const Color(0xFF10B981),
      const Color(0xFF0EA5E9),
      scheme.primary,
    ];

    return Row(
      children: List.generate(3, (index) {
        final isActive = _currentStep == index;
        final isCompleted = _isStepCompleted(index);
        final baseColor = colors[index];

        return Expanded(
          child: GestureDetector(
            onTap: () => _goToStep(index),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: isActive ? 6 : 4,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isActive 
                        ? baseColor 
                        : (isCompleted ? baseColor.withOpacity(0.5) : scheme.outlineVariant.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: isActive ? [
                      BoxShadow(color: baseColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                    ] : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isCompleted && !isActive) ...[
                      Icon(Icons.check_circle_rounded, size: 12, color: baseColor),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      stepNames[index],
                      style: TextStyle(
                        fontSize: isActive ? 12 : 11,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        color: isActive 
                            ? baseColor 
                            : (isCompleted ? baseColor : scheme.onSurfaceVariant.withOpacity(0.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent(MasterDataBundle master, String authorName) {
    switch (_currentStep) {
      case 0: return _buildClassificationStep(master);
      case 1: return _buildCustomerStep(master, authorName);
      case 2: return _buildConsultationStep(master);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildFixedFooter(MasterDataBundle master) {
    final scheme = Theme.of(context).colorScheme;
    final isLastStep = _currentStep == 2;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
          if (_currentStep > 0) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _prevStep();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('이전'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: isLastStep 
                ? (_submitting
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        _submit(master);
                      })
                : () {
                    HapticFeedback.lightImpact();
                    _nextStep();
                  },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isLastStep ? scheme.primary : scheme.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isLastStep ? '접수 등록' : '다음 단계', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    ));
  }

  // ─── Step 1: 분류 ───
  Widget _buildClassificationStep(MasterDataBundle master) {
    final scheme = Theme.of(context).colorScheme;
    
    // 기본값 설정
    if (_productId == null && master.productCategories.isNotEmpty) {
      final speedDoor = master.productCategories.firstWhere((e) => e.name.contains('스피드도어'), orElse: () => master.productCategories.first);
      _productId = speedDoor.id;
    }
    if (_methodId == null && master.inquiryMethods.isNotEmpty) {
      final yuseon = master.inquiryMethods.firstWhere((e) => e.name.contains('유선'), orElse: () => master.inquiryMethods.first);
      _methodId = yuseon.id;
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionHeader('기본 분류 선택', Icons.dashboard_customize_outlined, scheme),
        const SizedBox(height: 24),
        
        // 제품군
        _buildStepSubsectionTitle('제품군 카테고리', scheme),
        const SizedBox(height: 12),
        _buildGrid(
          context: context,
          items: master.productCategories,
          selectedValue: _productId,
          onSelected: (id) => setState(() => _productId = id),
          selectedColor: const Color(0xFF10B981), // Emerald
          crossAxisCount: 3, // 3열로 더 촘촘하게 표시
          childAspectRatio: 2.35,
        ),
        
        const SizedBox(height: 40),
        
        // 문의 경로
        _buildStepSubsectionTitle('문의 유입 경로', scheme),
        const SizedBox(height: 12),
        _buildGrid(
          context: context,
          items: master.inquiryMethods,
          selectedValue: _methodId,
          onSelected: (id) => setState(() => _methodId = id),
          selectedColor: const Color(0xFF0EA5E9), // Sky Blue
          crossAxisCount: 3, // 3열로 더 촘촘하게 표시
          childAspectRatio: 2.35,
        ),
        
        const SizedBox(height: 40),
        Text(
          '💡 제품군과 문의 경로를 선택하면 고객 정보를 입력할 수 있습니다.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ─── Step 2: 고객 정보 ───
  Widget _buildCustomerStep(MasterDataBundle master, String authorName) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('고객 및 지역 정보', Icons.contact_mail_outlined, scheme),
          const SizedBox(height: 24),
          
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: scheme.shadow.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '상세 고객 정보',
                          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _aiBusy || _uploadBusy ? null : () => _scanBusinessCard(master),
                        icon: _aiBusy 
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.contact_page_outlined, size: 16),
                        label: const Text('명함 스캔', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  _buildTextField(
                    label: '고객명/상호명',
                    controller: _nameCtrl,
                    hint: '고객성함 또는 회사명 입력',
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    label: '연락처 *',
                    controller: _phoneCtrl,
                    hint: '010-0000-0000',
                    keyboardType: TextInputType.phone,
                    onChanged: _onPhoneChanged,
                    validator: (v) => (v == null || v.trim().isEmpty) ? '번호를 입력해주세요' : null,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: scheme.shadow.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text('지역 및 배정 정보', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  SearchableRegionPicker(
                    regions: master.regions,
                    value: _regionId,
                    decoration: _inputDecoration('배정될 지역 검색 및 선택 *').copyWith(
                      fillColor: scheme.surfaceContainerHighest.withOpacity(0.3),
                    ),
                    onChanged: (v) => setState(() => _regionId = v),
                    validator: (v) => v == null ? '지역을 선택해주세요' : null,
                  ),
                  if (_regionId != null) ...[
                    const SizedBox(height: 16),
                    Builder(
                      builder: (ctx) {
                        try {
                          final selectedRegion = master.regions.firstWhere((r) => r.id == _regionId);
                          final sido = selectedRegion.extra['sido']?.trim() ?? '-';
                          final region = selectedRegion.extra['region']?.trim() ?? '-';
                          final manager = selectedRegion.extra['manager']?.trim() ?? '미지정';
                          
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: scheme.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(child: _buildDetailItem('선택 시/도', sido, scheme)),
                                Expanded(child: _buildDetailItem('상세 지역', region, scheme)),
                                Expanded(child: _buildDetailItem('담당 관리자', manager, scheme, isHighlight: true)),
                              ],
                            ),
                          );
                        } catch (_) {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  _buildTextField(
                    label: '등록 담당자',
                    initialValue: authorName,
                    readOnly: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 3: 상담 상세 ───
  Widget _buildConsultationStep(MasterDataBundle master) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionHeader('문의내용 및 자료', Icons.edit_note_rounded, scheme),
        const SizedBox(height: 24),
        
        _buildStepSubsectionTitle('문의 내용 본문 *', scheme),
        const SizedBox(height: 12),
        _buildTextField(
          label: '',
          controller: _inquiryCtrl,
          maxLines: 8,
          hint: '고객의 구체적인 요청 사항이나 문의내용을 기록하세요...',
          validator: (v) => (v == null || v.trim().isEmpty) ? '문의내용을 입력해주세요' : null,
        ),
        
        const SizedBox(height: 32),
        
        _buildStepSubsectionTitle('첨부 서류 및 현장 사진', scheme),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: scheme.shadow.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: SalesCallAttachmentsStrip(
            urls: _uploadedImageUrls,
            editable: true,
            uploadBusy: _uploadBusy,
            progressLabel: _uploadTotal > 0 ? '전송 중 ($_uploadCurrent/$_uploadTotal)' : null,
            onAdd: () => _pickAndUpload(master),
            onRemoveAt: (i) => setState(() => _uploadedImageUrls.removeAt(i)),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // 하단 체크박스
        GestureDetector(
          onTap: () => setState(() => _isSimpleInquiry = !_isSimpleInquiry),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isSimpleInquiry ? scheme.primaryContainer.withOpacity(0.3) : scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _isSimpleInquiry ? scheme.primary : scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _isSimpleInquiry,
                  onChanged: (v) => setState(() => _isSimpleInquiry = v ?? false),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('단순 문의로 상담 즉시 종료', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('배정 없이 이 기록을 리드 단계에서 즉시 종결 처리합니다.', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 1, // 다시 1줄로 시도 (칸이 넓어졌으므로)
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : scheme.onSurface,
                ),
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
