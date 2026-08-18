import 'dart:async';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/form_section.dart';
import 'package:coad_customer_calls/core/widgets/searchable_region_picker.dart';
import 'package:coad_customer_calls/core/widgets/ux_action_dock.dart';
import 'package:coad_customer_calls/data/consultation_draft_store.dart';
import 'package:coad_customer_calls/data/sales_call_consultation.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_day_follow_pager_screen.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_display.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:coad_customer_calls/data/temp_manager_logic.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SalesCallDetailScreen extends ConsumerStatefulWidget {
  const SalesCallDetailScreen({
    super.key,
    required this.id,
    this.initial,
    this.openConsultation = false,
  });

  final String id;
  final SalesCall? initial;

  /// 목록에서 상담 아이콘으로 들어올 때 시트를 바로 연다.
  final bool openConsultation;

  /// [Navigator.pop] 결과 — 접수 삭제 완료. 목록에서 해당 행을 제거한다.
  static const Object deleted = Object();

  @override
  ConsumerState<SalesCallDetailScreen> createState() =>
      _SalesCallDetailScreenState();
}

class _SalesCallDetailScreenState extends ConsumerState<SalesCallDetailScreen> {
  SalesCall? _model;
  bool _loading = true;
  String? _loadError;
  bool _lastSaveQueuedOffline = false;
  bool _consultationSavedSinceOpen = false;
  bool _isPoppingDetail = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _inquiryCtrl;
  late TextEditingController _assignedCtrl;
  late TextEditingController _stageCtrl;

  /// 전체 수정 폼용 (상담 입력과 분리)
  late TextEditingController _nextDateCtrl;

  /// 상담 입력 시트 전용 — DB `next_scheduled_date`와 동기하지 않음
  late TextEditingController _consultationNextDateCtrl;
  int? _consultationDayFollowCount;
  bool _consultationDayFollowCountLoading = false;
  String? _consultationDayFollowCountYmd;

  String? _productId;
  String? _regionId;
  String? _methodId;
  int? _statusId;
  bool _isEditMode = false;

  final _newConsultationCtrl = TextEditingController();
  final _unsuccessfulReasonCtrl = TextEditingController();

  bool _saving = false;
  bool _deleting = false;
  List<String> _imageUrls = [];
  bool _uploadBusy = false;
  int _uploadTotal = 0;
  int _uploadCurrent = 0;
  bool _openedConsultationFromFlag = false;
  Timer? _consultationDraftDebounce;

  // 상담 이력 스와이프 관련 상태
  late PageController _historyPageController;
  int _selectedHistoryIdx = 0;
  List<Map<String, dynamic>> _orderedCallHistory = [];
  int _historyViewKey = 0;

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
    _consultationNextDateCtrl = TextEditingController();
    _productId = i?.productCategoryId;
    _regionId = i?.regionId;
    _methodId = i?.inquiryMethodId;
    _statusId = i?.statusId;
    _orderedCallHistory = i != null
        ? orderCallHistoryForDisplay(i.callHistory)
        : [];
    _historyPageController = PageController(initialPage: 0);
    _selectedHistoryIdx = 0;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final fresh = await ref
          .read(salesCallsRepositoryProvider)
          .fetchCallById(widget.id);
      _applyModel(fresh);
    } catch (e) {
      if (_model == null) {
        setState(() => _loadError = koreanErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPhoneChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    String formatted;
    if (digits.length <= 3) {
      formatted = digits;
    } else if (digits.length <= 7) {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else if (digits.length <= 11) {
      formatted =
          '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } else {
      formatted =
          '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, 11)}';
    }
    if (formatted != value) {
      _phoneCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
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
      if (_isEditMode) {
        _nextDateCtrl.text = m.nextScheduledDate ?? '';
      }
      _productId = m.productCategoryId;
      _regionId = m.regionId;
      _methodId = m.inquiryMethodId;
      _statusId = m.statusId;
      _imageUrls = List<String>.from(m.images);
      // fromJson에서 이미 정렬됨 — 재정렬 시 _display_stage 중복 부여 방지
      _orderedCallHistory = List<Map<String, dynamic>>.from(m.callHistory);
      _selectedHistoryIdx = 0;
      _historyViewKey++;
      _historyPageController = PageController(initialPage: 0);
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
    _consultationNextDateCtrl.dispose();
    _consultationDraftDebounce?.cancel();
    _newConsultationCtrl.dispose();
    _unsuccessfulReasonCtrl.dispose();
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
      if (_assignedCtrl.text.trim().isNotEmpty)
        'assigned_to': _assignedCtrl.text.trim(),
      if (_stageCtrl.text.trim().isNotEmpty)
        'call_stage': _parseStageValue(_stageCtrl.text.trim()),
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
      if (e['branch_type'] != null)
        body['region_branch_type'] = e['branch_type'];
    } else {
      final m = _model;
      if (m != null) {
        if (m.regionSido != null) body['region_sido'] = m.regionSido;
        if (m.regionName != null) body['region_name'] = m.regionName;
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
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
        'webp',
        'svg',
        'heic',
        'heif',
        'tif',
        'tiff',
        'pdf',
      ],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => isAllowedPickerPath(p))
        .toList();
    await _uploadLocalPaths(master, paths);
  }

  Future<void> _captureAndUpload(MasterDataBundle master) async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (shot == null) return;
    await _uploadLocalPaths(master, [shot.path]);
  }

  Future<void> _uploadLocalPaths(
    MasterDataBundle master,
    List<String> paths,
  ) async {
    if (paths.isEmpty) return;

    setState(() {
      _uploadBusy = true;
      _uploadTotal = paths.length;
      _uploadCurrent = 0;
    });

    final site = _siteNameForUpload(master);
    final uploader = ref.read(b2UploadRepositoryProvider);
    var added = false;

    try {
      await Future.wait(
        paths.map((path) async {
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
              added = true;
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '업로드 실패 (${p.basename(path)}): ${koreanErrorMessage(e)}',
                  ),
                ),
              );
            }
          }
        }),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadBusy = false;
          _uploadTotal = 0;
          _uploadCurrent = 0;
        });
      }
    }
    if (added) await _persistImages();
  }

  Future<void> _removeImageAt(int index) async {
    if (index < 0 || index >= _imageUrls.length) return;
    setState(() {
      _imageUrls = List<String>.from(_imageUrls)..removeAt(index);
    });
    await _persistImages();
  }

  Future<void> _persistImages() async {
    try {
      final updated = await ref.read(salesCallsRepositoryProvider).updateCall(
        widget.id,
        {
          'images': List<String>.from(_imageUrls),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (!mounted) return;
      _applyModel(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('첨부 저장 실패: ${koreanErrorMessage(e)}')),
      );
    }
  }

  ConsultationDraftStore get _draftStore =>
      ConsultationDraftStore(ref.read(appDependenciesProvider).prefs);

  void _scheduleConsultationDraftSave() {
    _consultationDraftDebounce?.cancel();
    _consultationDraftDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persistConsultationDraft());
    });
  }

  Future<void> _persistConsultationDraft() {
    return _draftStore.save(
      widget.id,
      ConsultationDraft(
        content: _newConsultationCtrl.text,
        statusId: _statusId,
        nextDateYmd: _consultationNextDateCtrl.text.trim(),
        unsuccessfulReason: _unsuccessfulReasonCtrl.text,
      ),
    );
  }

  Future<void> _clearConsultationDraft() => _draftStore.clear(widget.id);

  void _maybeOpenConsultation(MasterDataBundle master) {
    if (_openedConsultationFromFlag || !widget.openConsultation) return;
    if (!_canEnterFurtherConsultation || _loading) return;
    _openedConsultationFromFlag = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showConsultationDialog(master);
    });
  }

  Future<void> _confirmDelete() async {
    final name = _model?.customerName?.trim();
    final label = (name != null && name.isNotEmpty) ? '$name 접수' : '이 접수';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('접수 삭제'),
        content: Text('$label를 삭제하시겠습니까?\n삭제 후에는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(salesCallsRepositoryProvider).deleteCall(widget.id);
      if (!mounted) return;
      invalidateHomeSalesCaches(ref.invalidate);
      final messenger = ScaffoldMessenger.of(context);
      // bool true 를 pop 하면 목록의 push<SalesCall?> 캐스팅이 깨져 UI가 멈춘다.
      _popDetail(SalesCallDetailScreen.deleted);
      messenger.showSnackBar(const SnackBar(content: Text('접수가 삭제되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<bool> _save(MasterDataBundle master) async {
    if (_isEditMode) {
      if (!(_formKey.currentState?.validate() ?? false)) return false;
      if (_regionId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('배정될 지역을 선택해주세요.')));
        return false;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(salesCallsRepositoryProvider);

      if (_isEditMode) {
        final updated = await repo.updateCall(widget.id, _bodyFromForm(master));
        _applyModel(updated);
      } else {
        final now = DateTime.now();
        final statusId = _statusId ?? CallStatusIds.undecided;
        final statusName = callStatusNameFromId(statusId);
        final historyCount = _model?.callHistory.length ?? 0;
        final stage = nextConsultationCallStage(historyCount);

        validateConsultationSubmit(
          consultationContent: _newConsultationCtrl.text,
          statusId: statusId,
          nextScheduledDateYmd: _consultationNextDateCtrl.text,
          unsuccessfulReason: _unsuccessfulReasonCtrl.text,
        );

        final user = ref.read(authControllerProvider);
        final historyPayload = buildCallHistoryInsert(
          salesCallId: widget.id,
          consultationContent: _newConsultationCtrl.text,
          statusId: statusId,
          statusName: statusName,
          callStage: stage,
          callDateYmd: now.toIso8601String().split('T').first,
          callTimeHms:
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
          nextScheduledDateYmd: _consultationNextDateCtrl.text,
          unsuccessfulReason: _unsuccessfulReasonCtrl.text,
          createdBy: user?.name ?? 'system',
        );

        final salesPayload = buildSalesCallUpdateAfterConsultation(
          statusId: statusId,
          callStage: stage,
          nextScheduledDateYmd: _consultationNextDateCtrl.text,
        );

        final updated = await repo.saveConsultationRound(
          callId: widget.id,
          historyData: historyPayload,
          salesCallBody: salesPayload,
        );
        _applyModel(updated);
        _consultationSavedSinceOpen = true;
        unawaited(_clearConsultationDraft());
        invalidateHomeSalesCaches(ref.invalidate);
      }

      if (mounted) {
        final wasEdit = _isEditMode;
        setState(() {
          _newConsultationCtrl.clear();
          _unsuccessfulReasonCtrl.clear();
          _consultationNextDateCtrl.clear();
          _isEditMode = false;
        });
        if (wasEdit) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('접수 정보가 수정되었습니다.')));
        }
      }
      _lastSaveQueuedOffline = false;
      return true;
    } on OfflineException {
      await refreshPendingSyncCount(ref);
      // 상담 내용은 로컬 큐에 저장됨 — 입력을 비우고 성공 흐름으로 종료.
      if (!_isEditMode) {
        _consultationSavedSinceOpen = true;
        unawaited(_clearConsultationDraft());
        invalidateHomeSalesCaches(ref.invalidate);
      }
      if (mounted) {
        setState(() {
          _newConsultationCtrl.clear();
          _unsuccessfulReasonCtrl.clear();
          _consultationNextDateCtrl.clear();
          _isEditMode = false;
        });
      }
      _lastSaveQueuedOffline = true;
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showConsultationSavingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                '저장 중입니다.',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '잠시만 기다려 주세요.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hideConsultationSavingDialog(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  int _parseStageValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == '접수') return 0;
    final m = RegExp(r'(\d+)').firstMatch(raw);
    if (m != null) return int.tryParse(m.group(1)!) ?? 0;
    return 0;
  }

  String _managerFromRegionId(MasterDataBundle master, String? regionId) {
    if (regionId == null || regionId.isEmpty) return '';
    for (final region in master.regions) {
      if (region.id != regionId) continue;
      final manager =
          (region.extra['manager'] ??
                  region.extra['original_manager'] ??
                  region.extra['effective_manager'] ??
                  '')
              .toString()
              .trim();
      return manager;
    }
    return '';
  }

  List<String> _managerOptionsFromMaster(MasterDataBundle master) {
    final set = <String>{};
    for (final region in master.regions) {
      final manager = (region.extra['manager'] ?? '').toString().trim();
      final original = (region.extra['original_manager'] ?? '')
          .toString()
          .trim();
      if (manager.isNotEmpty) set.add(manager);
      if (original.isNotEmpty) set.add(original);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// 웹과 동일: 다음 상담 차수 = 기존 이력 건수 + 1.
  /// 목록 `initial`에 이력이 비어 있어도 `call_stage`로 차수를 추정해 라벨 깜빡임을 줄임.
  int _nextConsultationStageNumber(SalesCall? call) {
    if (call == null) return 1;
    final fromHistory = call.callHistory.length + 1;
    final currentStage = _parseStageValue(call.callStage);
    final fromStage = currentStage <= 0 ? 1 : currentStage + 1;
    return fromHistory > fromStage ? fromHistory : fromStage;
  }

  String _inputStageLabel(SalesCall? call) =>
      '${_nextConsultationStageNumber(call)}차';

  /// 지금 입력하는 N차 상담 이후 예정일 = (N+1)차
  String _scheduledStageAfterInput(SalesCall? call) =>
      '${_nextConsultationStageNumber(call) + 1}차';

  DateTime _ymdToCalendarDate(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return DateTime.now();
    return DateTime(y, m, d);
  }

  String _calendarDateToYmd(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _resetConsultationFollowDateCount() {
    _consultationDayFollowCount = null;
    _consultationDayFollowCountLoading = false;
    _consultationDayFollowCountYmd = null;
  }

  Future<void> _pickConsultationNextDate({
    required BuildContext sheetContext,
    required void Function(void Function()) setModalState,
  }) async {
    final today = _ymdToCalendarDate(todayYmdSeoul());
    if (!sheetContext.mounted) return;
    final picked = _consultationNextDateCtrl.text.trim();
    final initial = picked.isNotEmpty ? _ymdToCalendarDate(picked) : today;
    final safeInitial = initial.isBefore(today) ? today : initial;
    final date = await showDatePicker(
      context: sheetContext,
      initialDate: safeInitial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      locale: const Locale('ko', 'KR'),
      helpText: '다음 상담 예정일',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (!sheetContext.mounted || date == null) return;

    await _applyConsultationFollowDate(
      sheetContext: sheetContext,
      setModalState: setModalState,
      ymd: _calendarDateToYmd(date),
    );
  }

  Future<void> _applyConsultationFollowDate({
    required BuildContext sheetContext,
    required void Function(void Function()) setModalState,
    required String ymd,
  }) async {
    setModalState(() {
      _consultationNextDateCtrl.text = ymd;
      _consultationDayFollowCountLoading = true;
      _consultationDayFollowCount = null;
      _consultationDayFollowCountYmd = ymd;
    });
    _scheduleConsultationDraftSave();

    int? count;
    try {
      count = await ref
          .read(salesCallsRepositoryProvider)
          .countFollowUpsOnDate(ymd: ymd, excludeId: widget.id);
    } catch (_) {
      count = null;
    }
    if (!sheetContext.mounted) return;
    setModalState(() {
      if (_consultationDayFollowCountYmd == ymd) {
        _consultationDayFollowCountLoading = false;
        _consultationDayFollowCount = count;
      }
    });
  }

  String _getNextStage(String? current) {
    if (current == null || current.isEmpty || current == '접수' || current == '0')
      return '2차';
    final match = RegExp(r'(\d+)').firstMatch(current);
    if (match != null) {
      final num = int.parse(match.group(1)!);
      return '${num + 1}차';
    }
    return '2차';
  }

  String _formatReceptionDateTime(SalesCall? call) {
    if (call == null) return '—';
    return formatSalesCallReceptionDateTime(
      callDate: call.callDate,
      callTime: call.callTime,
      createdAt: call.createdAt,
    );
  }

  String _displayStatusLabel(SalesCall? call) {
    if (call == null) return '미확인';
    return call.effectiveStatusLabel(orderedHistory: _orderedCallHistory);
  }

  bool get _canEnterFurtherConsultation {
    final call = _model;
    if (call == null) return false;
    return call.canEnterFurtherConsultationRound(
      orderedHistory: _orderedCallHistory,
    );
  }

  String _attachmentSavePrefix(SalesCall? call) {
    final now = DateTime.now();
    final ymd = (call?.callDate?.trim().isNotEmpty ?? false)
        ? call!.callDate!.trim().replaceAll('-', '')
        : '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final site = (call?.customerName ?? '현장')
        .trim()
        .replaceAll(RegExp(r'[^0-9a-zA-Z가-힣_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return '${ymd}_${site.isEmpty ? '현장' : site}';
  }

  Color _colorForAssignee(String assignee, ColorScheme scheme) {
    if (assignee == '미지정') return scheme.outline;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
    ];
    final hash = assignee.runes.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }

  void _showTempOverrideInfoDialog(TempManagerOverride o) {
    final memo = (o.memo ?? '').trim();
    final start = (o.startDate ?? '').trim();
    final end = (o.endDate ?? '').trim();
    final period = (start.isNotEmpty || end.isNotEmpty)
        ? '${start.isNotEmpty ? start : '—'} ~ ${end.isNotEmpty ? end : '—'}'
        : '—';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('임시 담당 변경 상세'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이유',
                style: Theme.of(
                  ctx,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                memo.isNotEmpty ? memo : '—',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Text(
                '기간',
                style: Theme.of(
                  ctx,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(period, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 14),
              Text(
                '담당자 변경',
                style: Theme.of(
                  ctx,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${o.originalManager} → ${o.tempManager}',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  bool get _editDirty {
    final m = _model;
    if (!_isEditMode || m == null) return false;
    return _nameCtrl.text.trim() != (m.customerName ?? '').trim() ||
        _phoneCtrl.text.trim() != (m.customerPhone ?? '').trim() ||
        _inquiryCtrl.text.trim() != (m.inquiryContent ?? '').trim() ||
        _nextDateCtrl.text.trim() != (m.nextScheduledDate ?? '').trim() ||
        _productId != m.productCategoryId ||
        _regionId != m.regionId ||
        _methodId != m.inquiryMethodId ||
        _assignedCtrl.text.trim() != (m.assignedTo ?? '').trim();
  }

  Widget _withPopResult(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isPoppingDetail) return;
        if (_editDirty) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('수정 취소'),
              content: const Text('수정 중인 내용이 있습니다.\n저장하지 않고 닫으시겠습니까?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('계속 수정'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('닫기'),
                ),
              ],
            ),
          );
          if (ok != true || !mounted) return;
        }
        _popDetail();
      },
      child: child,
    );
  }

  void _popDetail([Object? explicitResult]) {
    if (!mounted) return;
    _isPoppingDetail = true;
    Navigator.of(
      context,
    ).pop(explicitResult ?? (_consultationSavedSinceOpen ? _model : null));
  }

  @override
  Widget build(BuildContext context) {
    final masterAsync = ref.watch(salesCallCreateMasterDataProvider);

    if (_loadError != null && _model == null) {
      return _withPopResult(
        Scaffold(
          appBar: AppBar(title: const Text('통화 상세')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _bootstrap,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_loading && _model == null) {
      return _withPopResult(
        const Scaffold(body: AppLoading(message: '접수 정보를 불러오는 중…')),
      );
    }

    return _withPopResult(
      Scaffold(
        appBar: AppBar(
          title: const Text('접수 상세'),
          titleSpacing: 0,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          actions: [
            if (_loading || _deleting)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loading || _deleting
                  ? null
                  : () => unawaited(_bootstrap()),
              tooltip: '새로고침',
            ),
            IconButton(
              icon: Icon(
                _isEditMode ? Icons.visibility_rounded : Icons.edit_rounded,
              ),
              tooltip: _isEditMode ? '조회' : '수정',
              onPressed: _deleting
                  ? null
                  : () {
                      setState(() {
                        _isEditMode = !_isEditMode;
                        if (_isEditMode) {
                          _nextDateCtrl.text = _model?.nextScheduledDate ?? '';
                        }
                      });
                    },
            ),
            PopupMenuButton<String>(
              enabled: !_deleting && !_loading,
              tooltip: '더보기',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'home') {
                  if (_consultationSavedSinceOpen) {
                    invalidateHomeSalesCaches(ref.invalidate);
                  }
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (value == 'delete') {
                  unawaited(_confirmDelete());
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'home',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.home_rounded),
                    title: Text('홈으로'),
                    dense: true,
                  ),
                ),
                if (_model != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      title: Text('접수 삭제', style: TextStyle(color: Colors.red)),
                      dense: true,
                    ),
                  ),
              ],
            ),
          ],
        ),
        // 하단 액션 독 — 한 손 조작 (전화·문자·상담 / 수정 저장)
        floatingActionButton: null,
        bottomNavigationBar: _isEditMode
            ? masterAsync.maybeWhen(
                data: (master) => UxActionDock(
                  children: [
                    UxDockButton(
                      icon: _saving
                          ? Icons.hourglass_top_rounded
                          : Icons.save_as_rounded,
                      label: _saving ? '저장 중…' : '수정 저장',
                      emphasized: true,
                      enabled: !_saving,
                      onPressed: _saving ? null : () => _save(master),
                    ),
                  ],
                ),
                orElse: () => null,
              )
            : (_model != null && !_loading)
            ? UxActionDock(
                // 상담 라벨이 길어 더 넓은 비율 부여
                flexes: _canEnterFurtherConsultation
                    ? const [2, 2, 3]
                    : const [1, 1],
                children: [
                  UxDockButton(
                    icon: Icons.call_rounded,
                    label: '전화',
                    emphasized: true,
                    color: AppTokens.success(Theme.of(context).colorScheme),
                    onPressed: () => LauncherUtils.makePhoneCall(
                      _model?.customerPhone ?? '',
                    ),
                  ),
                  UxDockButton(
                    icon: Icons.message_rounded,
                    label: '문자',
                    onPressed: () =>
                        LauncherUtils.sendSMS(_model?.customerPhone ?? ''),
                  ),
                  if (_canEnterFurtherConsultation)
                    UxDockButton(
                      icon: Icons.add_comment_rounded,
                      label: '${_inputStageLabel(_model)} 상담내용',
                      emphasized: true,
                      onPressed: () => masterAsync.whenData(
                        (m) => _showConsultationDialog(m),
                      ),
                    ),
                ],
              )
            : null,
        body: masterAsync.when(
          data: (master) => _buildScrollable(master),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(koreanErrorMessage(e), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(salesCallCreateMasterDataProvider),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollable(MasterDataBundle master) {
    _maybeOpenConsultation(master);
    final m = _model;
    final scheme = Theme.of(context).colorScheme;
    final assigneeLabel =
        (m?.assignedTo == null || m!.assignedTo!.trim().isEmpty)
        ? '미지정'
        : m.assignedTo!.trim();
    final assigneeColor = _colorForAssignee(assigneeLabel, scheme);
    final overrides =
        ref.watch(tempManagerOverridesProvider).valueOrNull ?? const [];
    final activeOverride = m == null
        ? null
        : findActiveTempOverrideForCall(m, overrides, DateTime.now());
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
          if (m != null)
            _buildHeroHeader(m, scheme, assigneeColor, activeOverride),

          if (_isEditMode) ...[
            _buildEditFormSection(master, scheme),
          ] else ...[
            sectionTitle('핵심 문의 및 제품', Icons.rocket_launch_rounded),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    '제품명',
                    m?.productCategoryName ?? '미지정',
                    Icons.category_rounded,
                    scheme,
                    bgColor: assigneeColor.withOpacity(0.08),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoTile(
                    '지역',
                    '${m?.regionSido != null ? '[${m!.regionSido}] ' : ''}${m?.regionName ?? ''}'
                            .trim()
                            .isEmpty
                        ? '미지정'
                        : '${m?.regionSido != null ? '[${m!.regionSido}] ' : ''}${m?.regionName ?? ''}'
                              .trim(),
                    Icons.location_on_rounded,
                    scheme,
                    bgColor: assigneeColor.withOpacity(0.08),
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
          ],

          sectionTitle('진행 상태 및 일정', Icons.speed_rounded),
          _buildInfoTile(
            '접수 일시',
            _formatReceptionDateTime(m),
            Icons.schedule_rounded,
            scheme,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  '현재 성과',
                  _displayStatusLabel(m),
                  Icons.stars_rounded,
                  scheme,
                  labelColor: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  '현재 단계',
                  (RegExp(r'^\d+$').hasMatch(m?.callStage ?? ''))
                      ? '${m!.callStage}차'
                      : (m?.callStage ?? '접수'),
                  Icons.stairs_outlined,
                  scheme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            '작성자',
            (m?.createdBy ?? '').trim().isEmpty ? '미기재' : m!.createdBy!.trim(),
            Icons.edit_note_rounded,
            scheme,
          ),
          if (m != null &&
              m.effectiveStatusId(orderedHistory: _orderedCallHistory) ==
                  CallStatusIds.lost) ...[
            const SizedBox(height: 12),
            _buildInfoTile(
              '미수주 사유',
              m.effectiveUnsuccessfulReason(
                    orderedHistory: _orderedCallHistory,
                  ) ??
                  '미기재',
              Icons.report_gmailerrorred_outlined,
              scheme,
              multiLine: true,
              labelColor: scheme.error,
              bgColor: scheme.errorContainer.withValues(alpha: 0.35),
            ),
          ],
          const SizedBox(height: 12),
          Builder(
            builder: (_) {
              final followYmd = m?.followCalendarDateKey;
              final overdueDays = followOverdueDays(
                followYmd,
                todayYmdSeoul(),
              );
              final value = followYmd == null
                  ? '예정 없음'
                  : overdueDays == null
                  ? formatYmdFlowLabelKo(followYmd)
                  : '${formatYmdFlowLabelKo(followYmd)} · $overdueDays일 지남';
              return _buildInfoTile(
                '${_getNextStage(m?.callStage)} 예정일',
                value,
                Icons.event_available_rounded,
                scheme,
                labelColor: overdueDays == null ? assigneeColor : scheme.error,
                bgColor: overdueDays == null
                    ? assigneeColor.withOpacity(0.08)
                    : scheme.errorContainer.withValues(alpha: 0.4),
                onTap: followYmd == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SalesCallDayFollowPagerScreen(
                              initialDateYmd: followYmd,
                              initialAssignee: m?.assignedTo,
                            ),
                          ),
                        );
                      },
              );
            },
          ),

          sectionTitle('상담 이력 (단계별)', Icons.history_rounded),
          if (_orderedCallHistory.isNotEmpty)
            _buildHistorySwiper(_orderedCallHistory, scheme)
          else
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: assigneeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: assigneeColor.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '기록된 상담 이력이 없습니다.',
                  style: TextStyle(color: Colors.black38),
                ),
              ),
            ),

          sectionTitle('첨부 파일 자료', Icons.attach_file_rounded),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: assigneeColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: assigneeColor.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SalesCallAttachmentsStrip(
              urls: _imageUrls,
              saveNamePrefix: _attachmentSavePrefix(m),
              editable: true,
              uploadBusy: _uploadBusy,
              progressLabel: _uploadTotal > 0
                  ? '전송 중 ($_uploadCurrent/$_uploadTotal)'
                  : null,
              onAdd: () => _pickAndUpload(master),
              onAddCamera: () => _captureAndUpload(master),
              onRemoveAt: (i) => unawaited(_removeImageAt(i)),
            ),
          ),

          // 하단 액션 독(전화·문자·상담 / 저장)에 콘텐츠가 가리지 않도록
          SizedBox(height: (_isEditMode || m != null) ? 100 + bottomInset : 24),
        ],
      ),
    );
  }

  Widget _buildEditFormSection(MasterDataBundle master, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            '연락처·지역·문의 내용을 고친 뒤 아래 저장을 누르세요.',
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
        FormCollapsibleSection(
          step: 1,
          title: '고객 · 연락처',
          icon: Icons.person_outline_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEditFieldLabel('연락처 *', scheme),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                onChanged: _onPhoneChanged,
                decoration: _editInputDecoration('010-0000-0000', scheme),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '연락처를 입력해주세요' : null,
              ),
              const SizedBox(height: 12),
              _buildEditFieldLabel('고객명/상호명', scheme),
              TextFormField(
                controller: _nameCtrl,
                decoration: _editInputDecoration('고객성함 또는 회사명', scheme),
              ),
            ],
          ),
        ),
        FormCollapsibleSection(
          step: 2,
          title: '분류 · 지역 · 담당',
          icon: Icons.category_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEditFieldLabel('제품군', scheme),
              _buildMasterChoiceChips(
                items: master.productCategories,
                selectedValue: _productId,
                selectedColor: AppTokens.success(scheme),
                onSelected: (id) => setState(() => _productId = id),
              ),
              const SizedBox(height: 12),
              _buildEditFieldLabel('문의 경로', scheme),
              _buildMasterChoiceChips(
                items: master.inquiryMethods,
                selectedValue: _methodId,
                selectedColor: AppTokens.info(scheme),
                onSelected: (id) => setState(() => _methodId = id),
              ),
              const SizedBox(height: 16),
              _buildEditFieldLabel('지역 배정 *', scheme),
              SearchableRegionPicker(
                regions: master.regions,
                value: _regionId,
                decoration: _editInputDecoration('지역 검색 · 선택', scheme),
                onChanged: (v) {
                  setState(() {
                    _regionId = v;
                    final manager = _managerFromRegionId(master, v);
                    if (manager.isNotEmpty) {
                      _assignedCtrl.text = manager;
                    }
                  });
                },
                validator: (v) => v == null ? '지역을 선택해주세요' : null,
              ),
              const SizedBox(height: 16),
              _buildEditFieldLabel('담당자', scheme),
              Builder(
                builder: (ctx) {
                  final managerOptions = _managerOptionsFromMaster(master);
                  final current = _assignedCtrl.text.trim();
                  final selectedValue = managerOptions.contains(current)
                      ? current
                      : null;
                  return DropdownButtonFormField<String>(
                    value: selectedValue,
                    isExpanded: true,
                    decoration: _editInputDecoration('담당자 선택', scheme),
                    hint: const Text('담당자를 선택하세요'),
                    items: managerOptions
                        .map(
                          (m) => DropdownMenuItem<String>(
                            value: m,
                            child: Text(m),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _assignedCtrl.text = (v ?? '').trim();
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ),
        FormCollapsibleSection(
          step: 3,
          title: '문의 내용',
          icon: Icons.edit_note_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEditFieldLabel('문의 내용 *', scheme),
              TextFormField(
                controller: _inquiryCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: _editInputDecoration('고객 요청·문의 내용', scheme),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '문의내용을 입력해주세요' : null,
              ),
              const SizedBox(height: 16),
              _buildEditFieldLabel('다음 상담 예정일', scheme),
              TextFormField(
                controller: _nextDateCtrl,
                readOnly: true,
                onTap: () async {
                  final today = _ymdToCalendarDate(todayYmdSeoul());
                  final current = _nextDateCtrl.text.trim();
                  final initial = current.isNotEmpty
                      ? _ymdToCalendarDate(current)
                      : today;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial.isBefore(today) ? today : initial,
                    firstDate: DateTime(2020),
                    lastDate: today.add(const Duration(days: 365)),
                    locale: const Locale('ko', 'KR'),
                  );
                  if (picked == null) return;
                  setState(() {
                    _nextDateCtrl.text = _calendarDateToYmd(picked);
                  });
                },
                decoration: _editInputDecoration('날짜를 선택하세요', scheme).copyWith(
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditFieldLabel(String label, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  InputDecoration _editInputDecoration(String hint, ColorScheme scheme) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    );
  }

  Widget _buildMasterChoiceChips({
    required List<NamedMasterRow> items,
    required String? selectedValue,
    required Color selectedColor,
    required ValueChanged<String> onSelected,
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
          selectedColor: selectedColor.withValues(alpha: 0.18),
          side: BorderSide(
            color: selected
                ? selectedColor
                : scheme.outlineVariant.withValues(alpha: 0.6),
          ),
          onSelected: (_) => onSelected(item.id),
        );
      }).toList(),
    );
  }

  Widget _buildHeroHeader(
    SalesCall m,
    ColorScheme scheme,
    Color assigneeColor,
    TempManagerOverride? activeOverride,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [assigneeColor, assigneeColor.withOpacity(0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: assigneeColor.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _displayStatusLabel(m),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (m.displayInquiryMethod != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          m.displayInquiryMethod!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 담당자 명시 (색상 적용)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _colorForAssignee(
                    m.assignedTo ?? '미지정',
                    scheme,
                  ).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      m.assignedTo ?? '담당 미지정',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    if (activeOverride != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: '임시 담당 변경 상세',
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            _showTempOverrideInfoDialog(activeOverride),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 현장명 및 상호명
          Text(
            m.customerName ?? '(이름 없음)',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          // 전화번호
          GestureDetector(
            onTap: () => LauncherUtils.makePhoneCall(m.customerPhone ?? ''),
            onLongPress: () =>
                LauncherUtils.copyPhone(context, m.customerPhone ?? ''),
            child: Text(
              m.customerPhone ?? '연락처 없음',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                decoration: (m.customerPhone ?? '').trim().isEmpty
                    ? TextDecoration.none
                    : TextDecoration.underline,
                decorationColor: Colors.white70,
              ),
            ),
          ),
          if ((m.inquiryContent ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              m.inquiryContent!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.white.withOpacity(0.88),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          // 전화/문자는 하단 액션 독으로 이동 — 헤로는 상태·이름 중심
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon,
    ColorScheme scheme, {
    bool multiLine = false,
    Color? bgColor,
    Color? labelColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: bgColor ?? scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: labelColor ?? scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: labelColor ?? scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
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
        ),
      ),
    );
  }

  String? _firstNonEmptyDate(dynamic value) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty || s == 'null' || s == '-') return null;
    return s;
  }

  String? _scheduledDateFromMap(Map<String, dynamic> h) {
    return _firstNonEmptyDate(h['scheduled_date']) ??
        _firstNonEmptyDate(h['next_scheduled_date']) ??
        _firstNonEmptyDate(h['expected_date']) ??
        _firstNonEmptyDate(h['planned_date']) ??
        _firstNonEmptyDate(h['target_date']);
  }

  String? _resolveScheduledDateForHistory(
    List<Map<String, dynamic>> history,
    int index,
  ) {
    // 각 차수 카드에서 "다음 차수 예정일"을 표시하기 위해 현재 이력의 예정일 값을 사용.
    return _scheduledDateFromMap(history[index]);
  }

  int _stageNumberForHistory(Map<String, dynamic> h) =>
      displayStageFromHistoryMap(h);

  String? _resolveScheduledDateForStage(
    List<Map<String, dynamic>> history,
    int stage,
  ) {
    if (stage <= 1) return null;
    final prevStage = stage - 1;
    final len = history.length;
    for (var i = 0; i < len; i++) {
      final item = history[i];
      if (_stageNumberForHistory(item) != prevStage) continue;
      final scheduled = _scheduledDateFromMap(item);
      if (scheduled != null) return scheduled;
    }
    return null;
  }

  String _consultationContentFromHistoryMap(Map<String, dynamic> h) =>
      (h['consultation_content'] ??
              h['consultation_result'] ??
              h['content'] ??
              h['note'] ??
              h['memo'] ??
              '')
          .toString();

  int? _diffDaysBetween(String? scheduledRaw, String? actualRaw) {
    if (scheduledRaw == null || actualRaw == null) return null;
    DateTime? parseYmdOnly(String raw) {
      final src = raw.trim();
      if (src.isEmpty) return null;
      final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(src);
      if (m == null) return null;
      final y = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final d = int.tryParse(m.group(3)!);
      if (y == null || mo == null || d == null) return null;
      return DateTime(y, mo, d);
    }

    final scheduled = parseYmdOnly(scheduledRaw);
    final actual = parseYmdOnly(actualRaw);
    if (scheduled == null || actual == null) return null;
    return actual.difference(scheduled).inDays;
  }

  Widget _buildHistoryCard(
    List<Map<String, dynamic>> history,
    int index,
    ColorScheme scheme,
  ) {
    final h = history[index];
    final content = _consultationContentFromHistoryMap(h);
    final actualRaw =
        _firstNonEmptyDate(h['call_date']) ??
        _firstNonEmptyDate(h['created_at']);
    final actualDate = formatSeoulDate(actualRaw);
    final scheduledRaw = _resolveScheduledDateForHistory(history, index);
    final scheduledDate = scheduledRaw == null
        ? '없음'
        : formatSeoulDate(scheduledRaw);
    final stageNum = _stageNumberForHistory(h);
    final scheduledForCurrentStage = _resolveScheduledDateForStage(
      history,
      stageNum,
    );
    final diffDays = _diffDaysBetween(scheduledForCurrentStage, actualRaw);
    final currentStageLabel = displayStageLabelFromHistoryMap(h);
    final scheduledStageLabel = '${stageNum + 1}차 예정일';
    final showScheduledLine = scheduledRaw != null;
    final showDiffLine = stageNum > 1 && diffDays != null;
    final histStatusId = statusIdFromHistoryMap(h);
    final lostReason = histStatusId == CallStatusIds.lost
        ? unsuccessfulReasonFromHistoryMap(h)
        : null;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        displayStageLabelFromHistoryMap(h),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (showScheduledLine) ...[
                        Text(
                          '$scheduledStageLabel: $scheduledDate',
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        '$currentStageLabel 통화일: $actualDate',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (showDiffLine) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$stageNum차 예정일 대비 ${diffDays >= 0 ? '+' : ''}$diffDays일',
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: diffDays == 0
                                ? scheme.primary
                                : (diffDays > 0
                                      ? scheme.error
                                      : Colors.teal.shade700),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.isEmpty ? '기록된 상담 내용이 없습니다.' : content,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (lostReason != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          '미수주 사유',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.error,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lostReason,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySwiper(
    List<Map<String, dynamic>> history,
    ColorScheme scheme,
  ) {
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
              final stage = displayStageLabelFromHistoryMap(h);

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
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // ─── 상담 상세 카드 View ───
        SizedBox(
          height: 280,
          child: PageView.builder(
            key: ValueKey('history-$_historyViewKey-${history.length}'),
            controller: _historyPageController,
            itemCount: history.length,
            onPageChanged: (idx) {
              setState(() => _selectedHistoryIdx = idx);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildHistoryCard(history, index, scheme),
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

  /// 상담 시트 닫기 전 — 작성 중 내용이 있으면 확인.
  Future<bool> _confirmDiscardConsultation(BuildContext sheetContext) async {
    final hasInput =
        _newConsultationCtrl.text.trim().isNotEmpty ||
        _unsuccessfulReasonCtrl.text.trim().isNotEmpty ||
        _consultationNextDateCtrl.text.trim().isNotEmpty;
    if (!hasInput) return true;
    final ok = await showDialog<bool>(
      context: sheetContext,
      builder: (ctx) => AlertDialog(
        title: const Text('작성 취소'),
        content: const Text('작성 중인 상담 내용이 있습니다.\n저장하지 않고 닫으시겠습니까?'),
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
            child: const Text('닫기'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _showConsultationDialog(MasterDataBundle master) async {
    final draft = _draftStore.load(widget.id);
    if (draft != null) {
      _newConsultationCtrl.text = draft.content;
      _unsuccessfulReasonCtrl.text = draft.unsuccessfulReason ?? '';
      _consultationNextDateCtrl.text = draft.nextDateYmd ?? '';
      _statusId = draft.statusId ?? CallStatusIds.undecided;
      final ymd = _consultationNextDateCtrl.text.trim();
      if (ymd.isNotEmpty) {
        _consultationDayFollowCountYmd = ymd;
        _consultationDayFollowCountLoading = false;
        try {
          _consultationDayFollowCount = await ref
              .read(salesCallsRepositoryProvider)
              .countFollowUpsOnDate(ymd: ymd, excludeId: widget.id);
        } catch (_) {
          _consultationDayFollowCount = null;
        }
      } else {
        _resetConsultationFollowDateCount();
      }
    } else {
      _newConsultationCtrl.clear();
      _consultationNextDateCtrl.clear();
      _unsuccessfulReasonCtrl.clear();
      _resetConsultationFollowDateCount();
      _statusId = CallStatusIds.undecided;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      // 바깥 탭·아래로 스와이프로 작성 중 상담 내용이 사라지지 않도록.
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final m = _model;
          final scheme = Theme.of(context).colorScheme;
          final media = MediaQuery.of(context);
          final keyboardH = media.viewInsets.bottom;
          final keyboardOpen = keyboardH > 80;
          // padding(bottom: keyboard)로 키보드 위를 확보하고, 시트 높이는 그 안에서의 비율만 사용.
          final availableH = (media.size.height - keyboardH).clamp(360.0, media.size.height);
          final sheetHeight = (availableH * 0.96).clamp(360.0, availableH);
          final contentRequired = consultationContentRequiredForStatus(
            _statusId ?? CallStatusIds.undecided,
          );
          final needsDate = statusRequiresNextScheduledDate(
            _statusId ?? CallStatusIds.undecided,
          );
          final isLost = _statusId == CallStatusIds.lost;

          // 선택된 상태에 따른 배경색 정의 (투명해지지 않도록 불투명한 연한 색상 적용)
          Color bgColor = Colors.white;
          if (_statusId == 3) {
            // 수주
            bgColor = const Color(0xFFE8F5E9);
          } else if (_statusId == CallStatusIds.lost) {
            bgColor = const Color(0xFFFFEBEE);
          } else if (_statusId == 1) {
            // 미결정
            bgColor = const Color(0xFFFFF8E1);
          } else if (_statusId == 4) {
            // 단순문의
            bgColor = const Color(0xFFE3F2FD);
          } else if (_statusId == 5) {
            // 설계문의
            bgColor = const Color(0xFFEDE7F6);
          } else if (_statusId == 6) {
            // 기타
            bgColor = const Color(0xFFECEFF1);
          }

          InputDecoration multiLineDecoration(String hint) {
            return InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }

          Future<void> pickNextDate() => _pickConsultationNextDate(
            sheetContext: sheetContext,
            setModalState: setModalState,
          );

          Widget multiLineField({
            required TextEditingController controller,
            required String hint,
            ValueChanged<String>? onChanged,
          }) {
            // expands 대신 고정 minLines — 높이가 0으로 접히지 않음.
            // 필드 내부 스크롤로 여러 줄 입력·윗줄 확인 가능.
            return TextFormField(
              controller: controller,
              minLines: keyboardOpen ? 4 : 6,
              maxLines: 12,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(fontSize: 16, height: 1.45),
              onChanged: onChanged,
              decoration: multiLineDecoration(hint),
            );
          }

          Widget contextBox() {
            return Container(
              padding: const EdgeInsets.all(12),
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
                      const Text(
                        '모델: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          m?.productCategoryName ?? '미지정',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '문의내용:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m?.inquiryContent ?? '문의 내용이 없습니다.',
                    style: const TextStyle(
                      color: Colors.black54,
                      height: 1.4,
                      fontSize: 13,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (m != null && m.callHistory.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Text(
                      '이전(${displayStageLabelFromHistoryMap(_orderedCallHistory.first)}) 상담내용:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (_orderedCallHistory.first['consultation_content'] ??
                                  _orderedCallHistory.first['content'])
                              ?.toString() ??
                          '',
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.4,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          }

          Widget dateField() {
            final ymd = _consultationNextDateCtrl.text.trim();
            final countForThisDate =
                ymd.isNotEmpty && _consultationDayFollowCountYmd == ymd;
            final loading = countForThisDate && _consultationDayFollowCountLoading;
            final showCount = countForThisDate && !loading;
            final chips = consultationQuickDateChips(todayYmdSeoul());
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips.map((chip) {
                    final selected = ymd == chip.ymd;
                    return ChoiceChip(
                      label: Text(chip.label),
                      selected: selected,
                      onSelected: (_) => unawaited(
                        _applyConsultationFollowDate(
                          sheetContext: sheetContext,
                          setModalState: setModalState,
                          ymd: chip.ymd,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _consultationNextDateCtrl,
                  readOnly: true,
                  onTap: pickNextDate,
                  decoration: InputDecoration(
                    hintText: '날짜를 선택하세요',
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (loading) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '이 날짜의 예정 건수를 확인하는 중...',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ] else if (showCount) ...[
                  const SizedBox(height: 8),
                  Text(
                    consultationFollowDateCountMessage(
                      ymd: ymd,
                      count: _consultationDayFollowCount,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: (_consultationDayFollowCount ?? 0) > 0
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: pickNextDate,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('다른 날짜 선택'),
                    ),
                  ),
                ],
              ],
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: keyboardH),
            child: Material(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: sheetHeight,
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              switch (_statusId) {
                                CallStatusIds.lost =>
                                  '${_inputStageLabel(m)} 미수주 등록',
                                CallStatusIds.won =>
                                  '${_inputStageLabel(m)} 수주 등록',
                                _ => '${_inputStageLabel(m)} 상담내용 입력',
                              },
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _saving
                                ? null
                                : () async {
                                    if (await _confirmDiscardConsultation(
                                          sheetContext,
                                        ) &&
                                        sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 키보드가 열리면 문의 요약은 접어 입력 영역을 확보한다.
                            if (!keyboardOpen) ...[
                              contextBox(),
                              const SizedBox(height: 12),
                            ],
                            const Text(
                              '상담 결과 *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildStatusGrid(
                              scheme,
                              setModalState,
                              true, // 시트 안에서는 항상 컴팩트 — 입력란 공간 확보
                            ),
                            if (contentRequired) ...[
                              const SizedBox(height: 16),
                              const Text(
                                '상담내용 *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              multiLineField(
                                controller: _newConsultationCtrl,
                                hint: '고객와의 상담내용을 자세히 입력하세요...',
                                onChanged: (_) =>
                                    _scheduleConsultationDraftSave(),
                              ),
                            ],
                            if (isLost) ...[
                              const SizedBox(height: 16),
                              const Text(
                                '미수주 사유 *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              multiLineField(
                                controller: _unsuccessfulReasonCtrl,
                                hint: '미수주 사유를 입력하세요',
                                onChanged: (_) {
                                  _scheduleConsultationDraftSave();
                                  setModalState(() {});
                                },
                              ),
                            ],
                            if (needsDate) ...[
                              const SizedBox(height: 16),
                              Text(
                                '${_scheduledStageAfterInput(m)} 상담 예정일 *',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              dateField(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: FilledButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  FocusManager.instance.primaryFocus
                                      ?.unfocus();
                                  _showConsultationSavingDialog(sheetContext);
                                  final ok = await _save(master);
                                  if (sheetContext.mounted) {
                                    _hideConsultationSavingDialog(
                                      sheetContext,
                                    );
                                  }
                                  if (ok && sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  if (ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _lastSaveQueuedOffline
                                              ? '오프라인 — 상담 내용이 기기에 저장되었습니다. 연결되면 자동 전송됩니다.'
                                              : '상담내용 및 이력이 저장되었습니다.',
                                        ),
                                        duration: _lastSaveQueuedOffline
                                            ? const Duration(seconds: 5)
                                            : const Duration(seconds: 4),
                                      ),
                                    );
                                  } else if (!ok) {
                                    setModalState(() {});
                                  }
                                },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _saving
                                ? '저장 중...'
                                : switch (_statusId) {
                                    CallStatusIds.lost => '미수주 저장',
                                    CallStatusIds.won => '수주 저장',
                                    _ => '상담내용 저장',
                                  },
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusGrid(
    ColorScheme scheme, [
    void Function(void Function())? setModalState,
    bool compact = false, // 키보드 열림 시 버튼 높이 축소
  ]) {
    final statuses = [
      {'id': 1, 'name': '미결정', 'color': const Color(0xFFF2A900)},
      {'id': 3, 'name': '수주', 'color': const Color(0xFF2E7D32)},
      {'id': 2, 'name': '미수주', 'color': const Color(0xFFC62828)},
      {'id': 6, 'name': '기타', 'color': const Color(0xFF546E7A)},
      {'id': 4, 'name': '단순문의', 'color': const Color(0xFF1565C0)},
      {'id': 5, 'name': '설계문의', 'color': const Color(0xFF4527A0)},
    ];

    final gap = compact ? 6.0 : 8.0;
    final vPad = compact ? 8.0 : 14.0;
    final fontSize = compact ? 13.0 : 14.0;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: statuses.map((s) {
        final isSelected = _statusId == s['id'];
        final statusColor = s['color'] as Color;
        return GestureDetector(
          onTap: () {
            void apply() {
              _statusId = s['id'] as int;
              if (!statusRequiresNextScheduledDate(_statusId!)) {
                _consultationNextDateCtrl.clear();
              }
              _scheduleConsultationDraftSave();
            }

            if (setModalState != null) {
              setModalState(apply);
            } else {
              setState(apply);
            }
          },
          child: Container(
            width: (MediaQuery.of(context).size.width - 48) / 2,
            padding: EdgeInsets.symmetric(vertical: vPad),
            decoration: BoxDecoration(
              color: isSelected ? statusColor : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? statusColor : Colors.grey.shade300,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                s['name'] as String,
                style: TextStyle(
                  fontSize: fontSize,
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
