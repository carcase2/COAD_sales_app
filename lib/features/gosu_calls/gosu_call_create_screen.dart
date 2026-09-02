import 'dart:async';
import 'dart:io';

import 'package:coad_customer_calls/core/constants/gosu_appsheet.dart';
import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/core/utils/business_card_image.dart';
import 'package:coad_customer_calls/core/utils/gosu_calls_utils.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/form_section.dart';
import 'package:coad_customer_calls/core/widgets/searchable_region_picker.dart';
import 'package:coad_customer_calls/features/customer_support/reception_kind_sheet.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_crop_screen.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_call_detail_screen.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_choice_chip.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_editor_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_source_sheet.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:coad_customer_calls/models/gosu_sales_call.dart';
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GosuCallCreateScreen extends ConsumerStatefulWidget {
  const GosuCallCreateScreen({
    super.key,
    this.embedded = false,
    this.unsavedRegistry,
  });

  final bool embedded;
  final ReceptionUnsavedRegistry? unsavedRegistry;

  @override
  ConsumerState<GosuCallCreateScreen> createState() =>
      _GosuCallCreateScreenState();
}

class _GosuCallCreateScreenState extends ConsumerState<GosuCallCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _inquiryCtrl = TextEditingController();
  final _closeNoteCtrl = TextEditingController();

  int _productId = kGosuProductCategories.first.id;
  int _methodId = kGosuInquiryMethods.first.id;
  String _inquiryKind = kGosuInquiryKindDefault;
  String? _regionId;
  bool _submitting = false;
  bool _closeImmediately = false;
  final List<String> _uploadedImageUrls = [];
  bool _uploadBusy = false;
  bool _aiBusy = false;
  int _uploadTotal = 0;
  int _uploadCurrent = 0;
  Timer? _phoneLookupDebounce;
  List<GosuSalesCall> _existingByPhone = [];
  bool _phoneLookupBusy = false;
  String? _lookedUpDigits;
  List<String> _assignees = [];
  String _assignedTo = '';

  @override
  void initState() {
    super.initState();
    widget.unsavedRegistry?.register(
      ReceptionKind.gosu,
      () => _hasUnsavedInput,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadAssignees());
    });
  }

  List<String> get _assigneeChoices => gosuAssigneeChoices(
    departmentNames: _assignees,
    assignedTo: _assignedTo,
  );

  Future<void> _loadAssignees() async {
    final names = await ref
        .read(gosuSalesCallsRepositoryProvider)
        .fetchAssignees();
    if (!mounted) return;
    setState(() => _assignees = names);
  }

  @override
  void dispose() {
    widget.unsavedRegistry?.unregister(ReceptionKind.gosu);
    _phoneLookupDebounce?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _inquiryCtrl.dispose();
    _closeNoteCtrl.dispose();
    super.dispose();
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
    _schedulePhoneLookup(formatted);
  }

  void _schedulePhoneLookup(String value) {
    _phoneLookupDebounce?.cancel();
    final digits = normalizePhoneDigits(value);
    if (digits.length < 8) {
      if (_existingByPhone.isNotEmpty || _phoneLookupBusy) {
        setState(() {
          _existingByPhone = [];
          _phoneLookupBusy = false;
        });
      }
      return;
    }
    _phoneLookupDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_lookupExistingByPhone(digits));
    });
  }

  Future<void> _lookupExistingByPhone(String digits) async {
    setState(() {
      _phoneLookupBusy = true;
      _lookedUpDigits = digits;
    });
    try {
      final found = await ref
          .read(gosuSalesCallsRepositoryProvider)
          .findByPhone(digits);
      if (!mounted || _lookedUpDigits != digits) return;
      setState(() {
        _existingByPhone = found;
        _phoneLookupBusy = false;
      });
    } catch (_) {
      if (!mounted || _lookedUpDigits != digits) return;
      setState(() {
        _existingByPhone = [];
        _phoneLookupBusy = false;
      });
    }
  }

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
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<List<String>> _pathsFromPickedFiles(List<PlatformFile> files) async {
    final temp = await getTemporaryDirectory();
    final paths = <String>[];
    for (final file in files) {
      final existing = file.path;
      if (existing != null &&
          existing.isNotEmpty &&
          isAllowedPickerPath(existing)) {
        paths.add(existing);
        continue;
      }
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final name = file.name.trim().isEmpty
          ? 'file_${DateTime.now().millisecondsSinceEpoch}'
          : file.name.trim();
      if (!isAllowedPickerPath(name)) continue;
      final out = File(
        p.join(temp.path, '${DateTime.now().millisecondsSinceEpoch}_$name'),
      );
      await out.writeAsBytes(bytes, flush: true);
      paths.add(out.path);
    }
    return paths;
  }

  Future<String?> _pickCardImage(SalesCallImageSource source) async {
    if (source == SalesCallImageSource.camera) {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      return shot?.path;
    }
    if (source == SalesCallImageSource.gallery) {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      return shot?.path;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final paths = await _pathsFromPickedFiles(result.files);
    return paths.isEmpty ? null : paths.first;
  }

  Future<void> _scanBusinessCard() async {
    final source = await showSalesCallImageSourceSheet(context, title: '명함 인식');
    if (source == null) return;
    var path = await _pickCardImage(source);
    if (path == null || !mounted) return;
    final cropped = await cropBusinessCardImage(context, imagePath: path);
    if (cropped == null || !mounted) return;
    path = cropped;

    setState(() => _aiBusy = true);
    try {
      final prepared = await prepareBusinessCardImage(path);
      path = prepared.path;
      final aiResult = await ref
          .read(aiExtractorServiceProvider)
          .extractBusinessCard(prepared.bytes, filePath: prepared.path);
      if (!mounted) return;
      setState(() {
        if (aiResult.name.isNotEmpty && aiResult.company.isNotEmpty) {
          _nameCtrl.text = '${aiResult.name} (${aiResult.company})';
        } else if (aiResult.company.isNotEmpty) {
          _nameCtrl.text = aiResult.company;
        } else if (aiResult.name.isNotEmpty) {
          _nameCtrl.text = aiResult.name;
        }
        if (aiResult.phone.isNotEmpty) {
          _onPhoneChanged(formatKoreanPhoneHyphenated(aiResult.phone));
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('명함 정보가 자동으로 입력되었습니다.')));
      }
      setState(() {
        _uploadBusy = true;
        _uploadTotal = 1;
        _uploadCurrent = 0;
      });
      final url = await ref
          .read(b2UploadRepositoryProvider)
          .uploadGosuCallFile(
            filePath: path,
            customerPhone: _phoneCtrl.text,
          );
      if (!mounted) return;
      setState(() {
        _uploadedImageUrls.add(url);
        _uploadCurrent = 1;
      });
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

  Future<void> _pickAndUpload() async {
    final source = await showSalesCallImageSourceSheet(
      context,
      includeFiles: true,
    );
    if (source == null) return;
    List<String> paths = [];
    if (source == SalesCallImageSource.camera) {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (shot == null) return;
      paths = [shot.path];
    } else if (source == SalesCallImageSource.gallery) {
      final shots = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (shots.isEmpty) return;
      paths = shots.map((e) => e.path).toList();
    } else {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'heic',
          'pdf',
        ],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      paths = await _pathsFromPickedFiles(result.files);
    }
    if (paths.isEmpty) return;
    if (paths.length == 1 && isImageFile(paths.first)) {
      if (!mounted) return;
      final edited = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageEditorScreen(initialImage: File(paths.first)),
        ),
      );
      paths = [edited?.path ?? paths.first];
    }
    setState(() {
      _uploadBusy = true;
      _uploadTotal = paths.length;
      _uploadCurrent = 0;
    });
    final uploader = ref.read(b2UploadRepositoryProvider);
    try {
      for (final path in paths) {
        try {
          final url = await uploader.uploadGosuCallFile(
            filePath: path,
            customerPhone: _phoneCtrl.text,
          );
          if (!mounted) return;
          setState(() {
            _uploadedImageUrls.add(url);
            _uploadCurrent++;
          });
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '업로드 실패 (${p.basename(path)}): ${koreanErrorMessage(e)}',
              ),
            ),
          );
        }
      }
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

  Future<void> _submit(MasterDataBundle master) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('필수 항목을 확인해 주세요.')));
      return;
    }
    if (_inquiryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문의내용 본문을 입력해주세요.')));
      return;
    }
    final assigneeError = validateGosuAssignees(_assignedTo);
    if (assigneeError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(assigneeError)));
      return;
    }
    if (_closeImmediately && _closeNoteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 접수 시 처리·안내 내용을 입력해주세요.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = ref.read(authControllerProvider);
      NamedMasterRow? regionRow;
      if (_regionId != null) {
        for (final r in master.regions) {
          if (r.id == _regionId) {
            regionRow = r;
            break;
          }
        }
      }
      final category = kGosuProductCategories.firstWhere(
        (c) => c.id == _productId,
        orElse: () => kGosuProductCategories.first,
      );
      final method = kGosuInquiryMethods.firstWhere(
        (m) => m.id == _methodId,
        orElse: () => kGosuInquiryMethods.first,
      );
      final sido = regionRow?.extra['sido'];
      final regionName = regionRow?.extra['region'];
      final manager =
          regionRow?.extra['effective_manager'] ?? regionRow?.extra['manager'];
      final created = await ref
          .read(gosuSalesCallsRepositoryProvider)
          .createCall(
            customerName: _nameCtrl.text.trim(),
            customerPhone: _phoneCtrl.text.trim(),
            inquiryContent: _inquiryCtrl.text.trim(),
            productCategoryName: category.name,
            productCategoryId: null,
            inquiryMethodName: method.name,
            inquiryMethodId: gosuInquiryMethodIdForStorage(method.id),
            inquiryKind: normalizeGosuInquiryKind(_inquiryKind),
            regionId: int.tryParse(_regionId ?? ''),
            regionSido: sido,
            regionName: regionName,
            regionManager: manager,
            regionBranchType: regionRow?.extra['branch_type'],
            regionLabel: regionRow == null
                ? null
                : '${sido ?? ''}: ${regionName ?? ''}',
            assignedTo: formatGosuAssignees(parseGosuAssignees(_assignedTo)),
            createdBy: user?.name ?? '시스템',
            images: _uploadedImageUrls,
            closeImmediately: _closeImmediately,
            closeNote: _closeNoteCtrl.text,
          );
      unawaited(
        NotificationService.invokeGosuReceptionPush(
          gosuId: created.id,
          customerName: created.customerName ?? '',
          phone: created.customerPhone ?? '',
          inquiryContent: created.inquiryContent,
          assignedTo: created.assignedTo,
          createdBy: created.createdBy,
          regionSido: created.regionSido,
          regionName: created.regionName,
        ),
      );
      if (!mounted) return;
      invalidateHomeSalesCaches(ref.invalidate);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              GosuCallDetailScreen(id: created.id, initial: created),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterAsync = ref.watch(salesCallCreateMasterDataProvider);
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.gosuAccent(scheme);
    final body = masterAsync.when(
      loading: () => const AppLoading(message: '지역 정보를 불러오는 중…'),
      error: (e, _) => AppErrorState(
        message: koreanErrorMessage(e),
        onRetry: () => ref.invalidate(salesCallCreateMasterDataProvider),
      ),
      data: (master) => Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            FormSectionHeader(
              step: 1,
              title: '분류',
              icon: Icons.category_outlined,
            ),
            const SizedBox(height: 10),
            const Text('제품군', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kGosuProductCategories)
                  GosuChoiceChip(
                    label: c.name,
                    selected: _productId == c.id,
                    selectedColor: gosuChipColorFromHex(c.colorHex),
                    onSelected: (_) => setState(() => _productId = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('문의종류', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              '미선택 시 단순문의로 저장됩니다.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in kGosuInquiryKinds)
                  GosuChoiceChip(
                    label: k.name,
                    selected: _inquiryKind == k.name,
                    selectedColor: gosuChipColorFromHex(k.colorHex),
                    onSelected: (_) => setState(() => _inquiryKind = k.name),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('문의방법', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in kGosuInquiryMethods)
                  GosuChoiceChip(
                    label: m.name,
                    selected: _methodId == m.id,
                    selectedColor: gosuChipColorFromHex(m.colorHex),
                    onSelected: (_) => setState(() => _methodId = m.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FormSectionHeader(
              step: 2,
              title: '고객',
              icon: Icons.person_outline_rounded,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _aiBusy || _uploadBusy ? null : _scanBusinessCard,
                icon: _aiBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.contact_page_outlined, size: 18),
                label: const Text('명함', style: TextStyle(fontSize: 13)),
              ),
            ),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '고객명/상호명'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              onChanged: _onPhoneChanged,
              decoration: InputDecoration(
                labelText: '연락처 *',
                suffixIcon: IconButton(
                  tooltip: '붙여넣기',
                  onPressed: () async {
                    final digits = await LauncherUtils.clipboardPhoneDigits();
                    if (!mounted || digits == null) return;
                    _onPhoneChanged(formatKoreanPhoneHyphenated(digits));
                  },
                  icon: const Icon(Icons.content_paste_rounded),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '연락처를 입력해주세요' : null,
            ),
            if (_phoneLookupBusy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_existingByPhone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '기존 자동문의고수 ${_existingByPhone.length}건',
                style: TextStyle(fontWeight: FontWeight.w800, color: accent),
              ),
              for (final c in _existingByPhone.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.displayName),
                  subtitle: Text('${c.callDate ?? ''} · ${c.displayRegion}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            GosuCallDetailScreen(id: c.id, initial: c),
                      ),
                    );
                  },
                ),
            ],
            const SizedBox(height: 12),
            SearchableRegionPicker(
              regions: master.regions,
              value: _regionId,
              decoration: const InputDecoration(labelText: '지역 검색 · 선택'),
              onChanged: (v) => setState(() => _regionId = v),
            ),
            const SizedBox(height: 12),
            const Text('담당자 *', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              '여러 명 선택 가능 · 1명 이상 필수',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (_assigneeChoices.isEmpty)
              Text(
                '자동문의고수 부서 담당자가 없습니다',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in _assigneeChoices)
                    GosuChoiceChip(
                      label: name,
                      selected: parseGosuAssignees(_assignedTo).contains(name),
                      onSelected: (_) => setState(
                        () => _assignedTo = toggleGosuAssignee(
                          _assignedTo,
                          name,
                          required: true,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            FormSectionHeader(
              step: 3,
              title: '문의 · 첨부',
              icon: Icons.edit_note_rounded,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _inquiryCtrl,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '문의 내용 *',
                hintText: '고객 요청·문의 내용을 입력하세요',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '문의내용을 입력해주세요' : null,
            ),
            const SizedBox(height: 12),
            SalesCallAttachmentsStrip(
              urls: _uploadedImageUrls,
              editable: true,
              uploadBusy: _uploadBusy,
              progressLabel: _uploadTotal > 0
                  ? '전송 중 ($_uploadCurrent/$_uploadTotal)'
                  : null,
              onAdd: _pickAndUpload,
              onRemoveAt: (i) => setState(() => _uploadedImageUrls.removeAt(i)),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '접수 후 종료',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('단순 안내로 바로 종결'),
              value: _closeImmediately,
              activeThumbColor: Colors.white,
              activeTrackColor: accent,
              onChanged: (v) => setState(() => _closeImmediately = v),
            ),
            if (_closeImmediately)
              TextField(
                controller: _closeNoteCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '종료 안내 내용 *'),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : () => _submit(master),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                minimumSize: const Size.fromHeight(AppTokens.primaryCtaHeight),
              ),
              child: Text(_submitting ? '저장 중…' : '접수 등록'),
            ),
          ],
        ),
      ),
    );
    if (widget.embedded) return body;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          Navigator.of(this.context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('자동문의고수 접수'),
          backgroundColor: accent,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmDiscard() && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: body,
      ),
    );
  }
}
