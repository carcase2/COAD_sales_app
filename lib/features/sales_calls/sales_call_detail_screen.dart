import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
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

  bool _saving = false;
  List<String> _imageUrls = [];
  bool _uploadBusy = false;
  int _uploadTotal = 0;
  int _uploadCurrent = 0;

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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(salesCallsRepositoryProvider).updateCall(
            widget.id,
            _bodyFromForm(master),
          );
      _applyModel(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장했습니다.')),
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
        padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (m != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '기본 접수 정보',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('통화일: ${formatSeoulDate(m.callDate)} ${m.callTime ?? ''}'.trim(), style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  if (m.createdAt != null)
                    Text(
                      '최초 등록: ${formatSeoulDateTime(DateTime.tryParse(m.createdAt!))}',
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  if (m.updatedAt != null)
                    Text(
                      '마지막 수정: ${formatSeoulDateTime(DateTime.tryParse(m.updatedAt!))}',
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),

          sectionTitle('고객 정보', Icons.person),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: '고객명', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge_outlined)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '전화번호 *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_android)),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '전화번호는 필수입니다.';
                      if (!isValidKoreanPhone(v)) return '전화번호 형식을 확인하세요.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),

          sectionTitle('상담 및 현황', Icons.support_agent),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _inquiryCtrl,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: '문의 및 상담 내용',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _statusId ?? 1,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '진행 상태', border: OutlineInputBorder(), prefixIcon: Icon(Icons.check_circle_outline)),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('미결정/미통화 (1)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 2, child: Text('미수주 (2)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 3, child: Text('수주 (3)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 4, child: Text('단순문의 (4)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 5, child: Text('설계문의 (5)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _statusId = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _assignedCtrl,
                          decoration: const InputDecoration(labelText: '담당자', border: OutlineInputBorder(), prefixIcon: Icon(Icons.assignment_ind_outlined)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stageCtrl,
                          decoration: const InputDecoration(labelText: '콜 차수 (예: 1차)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nextDateCtrl,
                    decoration: const InputDecoration(labelText: '다음 예정일 (YYYY-MM-DD)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                  ),
                ],
              ),
            ),
          ),

          sectionTitle('부가 정보', Icons.tune),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    value: _productId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '분류 (제품군)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('선택 안 함', overflow: TextOverflow.ellipsis)),
                      ...master.productCategories.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _productId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: _regionId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '지역', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('선택 안 함', overflow: TextOverflow.ellipsis)),
                      ...master.regions.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _regionId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: _methodId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '문의 유입 경로', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('선택 안 함', overflow: TextOverflow.ellipsis)),
                      ...master.inquiryMethods.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _methodId = v),
                  ),
                ],
              ),
            ),
          ),

          sectionTitle('첨부 파일', Icons.photo_library_outlined),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
          ),

          if (m != null && m.callHistory.isNotEmpty) ...[
            sectionTitle('이전 상담 이력', Icons.history),
            ...m.callHistory.map(
              (h) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: scheme.primary.withOpacity(0.2)),
                ),
                child: ListTile(
                  leading: Icon(Icons.record_voice_over, color: scheme.onSurfaceVariant),
                  title: Text(
                    [
                      h['call_date'] ?? h['created_at'] ?? '',
                      h['stage'] ?? h['call_stage'] ?? '',
                    ].where((e) => e.toString().isNotEmpty).join(' '),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    (h['content'] ?? h['note'] ?? h['memo'] ?? '').toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _saving ? null : () => _save(master),
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_saving ? '저장 중...' : '변경 내용 저장', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
