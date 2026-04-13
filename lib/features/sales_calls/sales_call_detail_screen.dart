import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SalesCallDetailScreen extends ConsumerStatefulWidget {
  const SalesCallDetailScreen({super.key, required this.id, this.initial});

  final String id;
  final SalesCall? initial;

  @override
  ConsumerState<SalesCallDetailScreen> createState() => _SalesCallDetailScreenState();
}

class _SalesCallDetailScreenState extends ConsumerState<SalesCallDetailScreen> {
  SalesCall? _model;
  bool _loading = true;
  String? _loadError;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _inquiryCtrl;
  late TextEditingController _assignedCtrl;
  late TextEditingController _stageCtrl;
  late TextEditingController _nextDateCtrl;

  String? _productId;
  String? _regionId;
  String? _methodId;
  int? _statusId;
  bool _isEditMode = false;

  final _newConsultationCtrl = TextEditingController();

  bool _saving = false;
  List<String> _imageUrls = [];
  bool _uploadBusy = false;
  int _uploadTotal = 0;
  int _uploadCurrent = 0;

  // 상담 이력 스와이프 관련 상태
  late PageController _historyPageController;
  int _selectedHistoryIdx = 0;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _model = i;
    _imageUrls = List<String>.from(i?.images ?? const []);
    _nameCtrl = TextEditingController(text: i?.customerName ?? '');
    _phoneCtrl = TextEditingController(text: i?.customerPhone ?? '');
    _inquiryCtrl = TextEditingController(text: i?.inquiryContent ?? '');
    _assignedCtrl = TextEditingController(text: i?.assignedTo ?? '');
    _stageCtrl = TextEditingController(text: i?.callStage ?? '');
    _nextDateCtrl = TextEditingController(text: i?.nextScheduledDate ?? '');
    _productId = i?.productCategoryId;
    _regionId = i?.regionId;
    _methodId = i?.inquiryMethodId;
    _statusId = i?.statusId;
    _historyPageController = PageController(initialPage: (i?.callHistory.length ?? 1) - 1);
    _selectedHistoryIdx = (i?.callHistory.length ?? 1) - 1;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final fresh = await ref.read(salesCallsRepositoryProvider).fetchCallById(widget.id);
      _applyModel(fresh);
    } catch (e) {
      if (_model == null) {
        setState(() => _loadError = koreanErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyModel(SalesCall m) {
    setState(() {
      _model = m;
      _nameCtrl.text = m.customerName ?? '';
      _phoneCtrl.text = m.customerPhone ?? '';
      _inquiryCtrl.text = m.inquiryContent ?? '';
      _assignedCtrl.text = m.assignedTo ?? '';
      _stageCtrl.text = m.callStage ?? '';
      _nextDateCtrl.text = m.nextScheduledDate ?? '';
      _productId = m.productCategoryId;
      _regionId = m.regionId;
      _methodId = m.inquiryMethodId;
      _statusId = m.statusId;
      _imageUrls = List<String>.from(m.images);
      
      // 최신 이력이 추가되었을 경우 첫 번째 페이지(최신)로 이동
      if (m.callHistory.isNotEmpty) {
        _selectedHistoryIdx = 0;
        if (_historyPageController.hasClients) {
          _historyPageController.jumpToPage(0);
        } else {
          _historyPageController = PageController(initialPage: _selectedHistoryIdx);
        }
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _inquiryCtrl.dispose();
    _assignedCtrl.dispose();
    _stageCtrl.dispose();
    _nextDateCtrl.dispose();
    _newConsultationCtrl.dispose();
    _historyPageController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _bodyFromForm(MasterDataBundle master) {
    final body = <String, dynamic>{
      'customer_phone': _phoneCtrl.text.trim(),
      'customer_name': _nameCtrl.text.trim(),
      'inquiry_content': _inquiryCtrl.text.trim(),
      if (_productId != null) 'product_category_id': _productId,
      if (_regionId != null) 'region_id': _regionId,
      if (_methodId != null) 'inquiry_method_id': _methodId,
      if (_statusId != null) 'status_id': _statusId,
      if (_assignedCtrl.text.trim().isNotEmpty) 'assigned_to': _assignedCtrl.text.trim(),
      if (_stageCtrl.text.trim().isNotEmpty) 'call_stage': _stageCtrl.text.trim(),
      if (_nextDateCtrl.text.trim().isNotEmpty)
        'next_scheduled_date': _nextDateCtrl.text.trim(),
    };

    NamedMasterRow? regionRow;
    if (_regionId != null) {
      for (final r in master.regions) {
        if (r.id == _regionId) {
          regionRow = r;
          break;
        }
      }
    }
    if (regionRow != null) {
      final e = regionRow.extra;
      if (e['sido'] != null) body['region_sido'] = e['sido'];
      if (e['region'] != null) body['region_name'] = e['region'];
      if (e['manager'] != null) body['region_manager'] = e['manager'];
      if (e['branch_type'] != null) body['region_branch_type'] = e['branch_type'];
    } else {
      final m = _model;
      if (m != null) {
        if (m.regionSido != null) body['region_sido'] = m.regionSido;
        if (m.regionName != null) body['region_name'] = m.regionName;
        if (m.regionManager != null) body['region_manager'] = m.regionManager;
        if (m.regionBranchType != null) {
          body['region_branch_type'] = m.regionBranchType;
        }
      }
    }
    body['images'] = _imageUrls;
    return body;
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

    setState(() {
      _uploadBusy = true;
      _uploadTotal = paths.length;
      _uploadCurrent = 0;
    });

    final site = _siteNameForUpload(master);
    final uploader = ref.read(b2UploadRepositoryProvider);

    try {
      // 병렬 업로드 수행
      await Future.wait(paths.map((path) async {
        try {
          final url = await uploader.uploadSalesCallFile(
            filePath: path,
            siteName: site,
            customerPhone: _phoneCtrl.text,
          );
          if (mounted) {
            setState(() {
              _imageUrls = [..._imageUrls, url];
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

  Future<void> _save(MasterDataBundle master) async {
    if (_isEditMode && !_formKey.currentState!.validate()) return;
    
    setState(() => _saving = true);
    try {
      final repo = ref.read(salesCallsRepositoryProvider);
      
      if (_isEditMode) {
        final updated = await repo.updateCall(widget.id, _bodyFromForm(master));
        _applyModel(updated);
      } else {
        // Only saving new consultation and next date
        final now = DateTime.now();
        final timestamp = "[${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}]";
        final currentStageLabel = _getCurrentStage(_model?.callStage);
        
        final newContent = _newConsultationCtrl.text.trim();
        if (newContent.isEmpty) {
          throw Exception('상담 내용을 입력해주세요.');
        }

        // 1. History 추가 (상담내용 입력 시 항상 이력으로 저장)
        final user = ref.read(authControllerProvider);
        final currentStageNum = _getStageInt(_model?.callStage);
        
        await repo.addCallHistory(widget.id, {
          'consultation_content': newContent, // 스키마 반영: consultation_content
          'call_date': now.toIso8601String().split('T').first,
          'call_time': "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}", // HH:mm:ss
          'call_stage': currentStageNum, // 스키마 반영: 정수형
          'status_id': _statusId,
          'created_by': user?.name ?? 'system', // 스키마 반영: 작성자
          'status': _getStatusNameById(master, _statusId), // 스키마의 status (text) 필드 대응
        });

        // 2. 메인 정보 업데이트
        final nextStage = _getNextStage(_model?.callStage);
        
        final body = {
          'next_scheduled_date': _nextDateCtrl.text.trim(),
          'status_id': _statusId,
          'call_stage': nextStage,
        };

        final updated = await repo.updateCall(widget.id, body);
        _applyModel(updated);
      }

      if (mounted) {
        setState(() {
          _newConsultationCtrl.clear();
          _isEditMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상담 내용 및 이력이 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(koreanErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _getCurrentStage(String? current) {
    if (current == null || current.isEmpty || current == '접수' || current == '0') return '1차';
    return current;
  }

  int _getStageInt(String? current) {
    if (current == null || current.isEmpty || current == '접수' || current == '0') return 1;
    final match = RegExp(r'(\d+)').firstMatch(current);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 1;
  }

  String _getNextStage(String? current) {
    if (current == null || current.isEmpty || current == '접수' || current == '0') return '2차';
    final match = RegExp(r'(\d+)').firstMatch(current);
    if (match != null) {
      final num = int.parse(match.group(1)!);
      return '${num + 1}차';
    }
    return '2차';
  }

  String _getStatusNameById(MasterDataBundle master, int? id) {
    if (id == null) return '미결정';
    final mapping = {
      1: '미결정',
      3: '수주',
      2: '미수주',
      6: '기타',
      4: '단순문의',
      5: '설계문의',
    };
    return mapping[id] ?? '미결정';
  }

  @override
  Widget build(BuildContext context) {
    final masterAsync = ref.watch(masterDataProvider);

    if (_loadError != null && _model == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('통화 상세')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!),
                const SizedBox(height: 12),
                FilledButton(onPressed: _bootstrap, child: const Text('다시 시도')),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading && _model == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('통화 상세'),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.view_headline_rounded : Icons.edit_note_rounded),
            onPressed: () => setState(() => _isEditMode = !_isEditMode),
            tooltip: _isEditMode ? '조회 모드로 변경' : '전체 정보 수정',
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      floatingActionButton: (!_isEditMode && _model != null)
          ? FloatingActionButton.extended(
              onPressed: () => masterAsync.whenData((m) => _showConsultationDialog(m)),
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('상담내용 입력'),
            )
          : null,
      body: masterAsync.when(
        data: (master) => _buildScrollable(master),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(koreanErrorMessage(e))),
      ),
    );
  }

  Widget _buildScrollable(MasterDataBundle master) {
    final m = _model;
    final scheme = Theme.of(context).colorScheme;

    Widget sectionTitle(String title, IconData icon) {
      return Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12, left: 4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: scheme.primary),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (m != null) _buildHeroHeader(m, scheme),

          sectionTitle('핵심 문의 및 제품', Icons.rocket_launch_rounded),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  '제품명', 
                  m?.productCategoryName ?? '미지정', 
                  Icons.category_rounded, 
                  scheme,
                  bgColor: scheme.primary.withOpacity(0.05),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  '지역', 
                  m?.regionLabel ?? '미지정', 
                  Icons.location_on_rounded, 
                  scheme,
                  bgColor: Colors.orange.withOpacity(0.05),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            '문의내용', 
            m?.inquiryContent ?? '상세 문의 내용이 없습니다.', 
            Icons.notes_rounded, 
            scheme,
            multiLine: true,
          ),

          sectionTitle('진행 상태 및 일정', Icons.speed_rounded),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  '현재 성과', 
                  m?.statusLabel ?? '미확인', 
                  Icons.stars_rounded, 
                  scheme,
                  labelColor: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  '현재 단계', 
                  m?.callStage ?? '접수', 
                  Icons.stairs_outlined, 
                  scheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            '${_getNextStage(m?.callStage)} 예정일', 
            m?.nextScheduledDate ?? '예정 없음', 
            Icons.event_available_rounded, 
            scheme,
            labelColor: Colors.deepOrangeAccent,
          ),

          sectionTitle('상담 이력 (단계별)', Icons.history_rounded),
          if (m != null && m.callHistory.isNotEmpty)
            _buildHistorySwiper(m.callHistory, scheme)
          else
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: scheme.shadow.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Center(
                child: Text('기록된 상담 이력이 없습니다.', style: TextStyle(color: Colors.black38)),
              ),
            ),

          sectionTitle('첨부 파일 자료', Icons.attach_file_rounded),
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
              urls: _imageUrls,
              editable: true,
              uploadBusy: _uploadBusy,
              progressLabel: _uploadTotal > 0 ? '전송 중 ($_uploadCurrent/$_uploadTotal)' : null,
              onAdd: () => _pickAndUpload(master),
              onRemoveAt: (i) {
                setState(() {
                  _imageUrls = List<String>.from(_imageUrls)..removeAt(i);
                });
              },
            ),
          ),

          if (_isEditMode)
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 48),
              child: SizedBox(
                height: 58,
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(master),
                  icon: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_as_rounded),
                  label: Text(
                    _saving ? '저장 중...' : '전체 정보 수정 저장', 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(SalesCall m, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 배지 (긴 텍스트 대응을 위해 상단 독립 배치)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              m.statusLabel ?? '접수',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          // 현장명 및 상호명
          Text(
            m.customerName ?? '(이름 없음)',
            style: const TextStyle(
              fontSize: 28, 
              fontWeight: FontWeight.w900, 
              color: Colors.white, 
              letterSpacing: -0.8,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // 전화번호
          Text(
            m.customerPhone ?? '연락처 없음',
            style: TextStyle(
              fontSize: 18, 
              color: Colors.white.withOpacity(0.9), 
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildLargeQuickAction(Icons.call, '전화', () => LauncherUtils.makePhoneCall(m.customerPhone ?? '')),
              const SizedBox(width: 12),
              _buildLargeQuickAction(Icons.message_rounded, '문자', () => LauncherUtils.sendSMS(m.customerPhone ?? '')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeQuickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, ColorScheme scheme, {bool multiLine = false, Color? bgColor, Color? labelColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: labelColor ?? scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: labelColor ?? scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (multiLine)
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                height: 1.5,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> h, ColorScheme scheme) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (h['call_stage'] != null) ? "${h['call_stage']}차" : (h['stage'] ?? '기록').toString(),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: scheme.primary),
                      ),
                    ),
                  ],
                ),
                Text(
                  formatSeoulDate(h['call_date'] ?? h['created_at']),
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              (h['consultation_content'] ?? h['consultation_result'] ?? h['content'] ?? h['note'] ?? h['memo'] ?? '').toString(),
              style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF333333)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySwiper(List<Map<String, dynamic>> history, ColorScheme scheme) {
    return Column(
      children: [
        // ─── 차수 선택 칩 바 ───
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: history.length,
            itemBuilder: (context, index) {
              final h = history[index];
              final isSelected = _selectedHistoryIdx == index;
              final stage = h['call_stage'] != null ? "${h['call_stage']}차" : (h['stage'] ?? '${index + 1}차').toString();
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(stage),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedHistoryIdx = index);
                      _historyPageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  showCheckmark: false,
                  selectedColor: scheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // ─── 상담 상세 카드 View ───
        SizedBox(
          height: 220, // 고정 높이 또는 동적 조정 필요
          child: PageView.builder(
            controller: _historyPageController,
            itemCount: history.length,
            onPageChanged: (idx) {
              setState(() => _selectedHistoryIdx = idx);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildHistoryCard(history[index], scheme),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(history.length, (index) {
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectedHistoryIdx == index 
                    ? scheme.primary 
                    : scheme.outlineVariant.withOpacity(0.5),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _showConsultationDialog(MasterDataBundle master) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final m = _model;
          final scheme = Theme.of(context).colorScheme;
          
          // 선택된 상태에 따른 배경색 정의 (투명해지지 않도록 불투명한 연한 색상 적용)
          Color bgColor = Colors.white;
          if (_statusId == 3) { // 수주
            bgColor = const Color(0xFFE8F5E9);
          } else if (_statusId == 2) { // 미수주
            bgColor = const Color(0xFFFFEBEE);
          } else if (_statusId == 1) { // 미결정
            bgColor = const Color(0xFFFFF8E1);
          } else if (_statusId == 4) { // 단순문의
            bgColor = const Color(0xFFE3F2FD);
          } else if (_statusId == 5) { // 설계문의
            bgColor = const Color(0xFFEDE7F6);
          } else if (_statusId == 6) { // 기타
            bgColor = const Color(0xFFECEFF1);
          }
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_getCurrentStage(m?.callStage)} 상담내용 입력',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Context Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('모델: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                Expanded(child: Text(m?.productCategoryName ?? '미지정', style: const TextStyle(color: Colors.black54))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('문의내용:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text(
                              m?.inquiryContent ?? '문의 내용이 없습니다.',
                              style: const TextStyle(color: Colors.black54, height: 1.4, fontSize: 13),
                            ),
                            if (m != null && m.callHistory.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Text(
                                '이전(${m.callHistory.last['call_stage'] ?? '직전'}) 상담 내용:',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.callHistory.last['content']?.toString() ?? '',
                                style: const TextStyle(color: Colors.black54, height: 1.4, fontSize: 13),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('상담내용 *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _newConsultationCtrl,
                        minLines: 5,
                        maxLines: 15,
                        decoration: InputDecoration(
                          hintText: '고객와의 상담 내용을 자세히 입력하세요...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('상담 결과 *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      _buildStatusGrid(scheme, setModalState),
                      const SizedBox(height: 24),
                      Text('${_getNextStage(m?.callStage)} 상담 예정일 *', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nextDateCtrl,
                        readOnly: true,
                        onTap: () async {
                           final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setModalState(() {
                              _nextDateCtrl.text = date.toIso8601String().split('T').first;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          hintText: '연도. 월. 일.',
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: FilledButton(
                      onPressed: _saving ? null : () async {
                        await _save(master);
                        if (mounted) Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _saving ? '저장 중...' : '상담내용 저장',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusGrid(ColorScheme scheme, [void Function(void Function())? setModalState]) {
    final statuses = [
      {'id': 1, 'name': '미결정', 'color': const Color(0xFFF2A900)},
      {'id': 3, 'name': '수주', 'color': const Color(0xFF2E7D32)},
      {'id': 2, 'name': '미수주', 'color': const Color(0xFFC62828)},
      {'id': 6, 'name': '기타', 'color': const Color(0xFF546E7A)},
      {'id': 4, 'name': '단순문의', 'color': const Color(0xFF1565C0)},
      {'id': 5, 'name': '설계문의', 'color': const Color(0xFF4527A0)},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((s) {
        final isSelected = _statusId == s['id'];
        final statusColor = s['color'] as Color;
        return GestureDetector(
          onTap: () {
            if (setModalState != null) {
              setModalState(() => _statusId = s['id'] as int);
            } else {
              setState(() => _statusId = s['id'] as int);
            }
          },
          child: Container(
            width: (MediaQuery.of(context).size.width - 48) / 2,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? statusColor : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? statusColor : Colors.grey.shade300),
              boxShadow: isSelected ? [
                BoxShadow(color: statusColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
              ] : null,
            ),
            child: Center(
              child: Text(
                s['name'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
