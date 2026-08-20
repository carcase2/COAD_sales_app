import 'dart:async';
import 'dart:io';

import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/core/utils/business_card_permissions.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/form_section.dart';
import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_detail_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/kakao_address_field.dart';
import 'package:coad_customer_calls/features/customer_support/support_first_consultation_sheet.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_editor_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_source_sheet.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum SupportUrgency { high, mid, low }

Color supportUrgencyColor(ColorScheme scheme, SupportUrgency urgency) =>
    switch (urgency) {
      SupportUrgency.high => scheme.error,
      SupportUrgency.mid => const Color(0xFFD97706),
      SupportUrgency.low => AppTokens.success(scheme),
    };

String supportUrgencyLabel(SupportUrgency urgency) => switch (urgency) {
  SupportUrgency.high => '상',
  SupportUrgency.mid => '중',
  SupportUrgency.low => '하',
};

class SupportIssueFields {
  const SupportIssueFields({
    this.urgency = SupportUrgency.mid,
    this.productName = '',
    this.siteName = '',
    this.body = '',
  });

  final SupportUrgency urgency;
  final String productName;
  final String siteName;
  final String body;
}

SupportIssueFields parseSupportIssueBody(String issue) {
  var urgency = SupportUrgency.mid;
  var productName = '';
  var siteName = '';
  final rest = <String>[];
  for (final raw in issue.split('\n')) {
    final line = raw.trimRight();
    final urgencyMatch = RegExp(
      r'^\[긴급도\s*(상|중|하)\]\s*(.*)$',
    ).firstMatch(line.trim());
    if (urgencyMatch != null) {
      urgency = switch (urgencyMatch.group(1)) {
        '상' => SupportUrgency.high,
        '하' => SupportUrgency.low,
        _ => SupportUrgency.mid,
      };
      productName = (urgencyMatch.group(2) ?? '').trim();
      continue;
    }
    final siteMatch = RegExp(r'^현장:\s*(.*)$').firstMatch(line.trim());
    if (siteMatch != null) {
      siteName = (siteMatch.group(1) ?? '').trim();
      continue;
    }
    rest.add(raw);
  }
  return SupportIssueFields(
    urgency: urgency,
    productName: productName,
    siteName: siteName,
    body: rest.join('\n').trim(),
  );
}

class CustomerSupportIntakeScreen extends ConsumerStatefulWidget {
  const CustomerSupportIntakeScreen({super.key, this.site, this.existing});

  final SupportSiteSample? site;
  final SupportCallLog? existing;

  @override
  ConsumerState<CustomerSupportIntakeScreen> createState() =>
      _CustomerSupportIntakeScreenState();
}

class _CustomerSupportIntakeScreenState
    extends ConsumerState<CustomerSupportIntakeScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  SupportUrgency _urgency = SupportUrgency.mid;
  String? _productId;
  double? _addressLat;
  double? _addressLng;
  bool _submitting = false;
  Timer? _nameLookupDebounce;
  Timer? _phoneLookupDebounce;
  BusinessCard? _matchedByName;
  BusinessCard? _matchedByPhone;
  bool _phoneFromCard = false;
  bool _nameFromCard = false;
  bool _applyingPhone = false;
  bool _applyingName = false;
  bool _nameLookupBusy = false;
  bool _phoneLookupBusy = false;
  String? _lookedUpName;
  String? _lookedUpPhoneDigits;
  String? _pendingProductName;
  final List<String> _attachmentUrls = [];
  bool _uploadBusy = false;
  int _uploadTotal = 0;
  int _uploadCurrent = 0;

  BusinessCard? get _matchedCard => _matchedByPhone ?? _matchedByName;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final site = widget.site;
    if (existing != null) {
      final parsed = parseSupportIssueBody(existing.issue);
      _nameCtrl.text = existing.customerName;
      _phoneCtrl.text = formatKoreanPhoneHyphenated(existing.customerPhone);
      _siteCtrl.text = parsed.siteName;
      _addressCtrl.text = existing.address ?? '';
      _issueCtrl.text = parsed.body;
      _urgency = parsed.urgency;
      _pendingProductName = parsed.productName;
      _attachmentUrls.addAll(existing.firstImageUrls);
    } else if (site != null) {
      _nameCtrl.text = site.name;
      _phoneCtrl.text = formatKoreanPhoneHyphenated(site.phone);
      _siteCtrl.text = site.name;
      _addressCtrl.text = site.address;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleNameLookup(_nameCtrl.text);
      _schedulePhoneLookup(_phoneCtrl.text);
    });
  }

  @override
  void dispose() {
    _nameLookupDebounce?.cancel();
    _phoneLookupDebounce?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _siteCtrl.dispose();
    _addressCtrl.dispose();
    _issueCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (!_applyingName) _nameFromCard = false;
    _scheduleNameLookup(value);
  }

  void _scheduleNameLookup(String value) {
    _nameLookupDebounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      if (_matchedByName != null || _nameLookupBusy) {
        setState(() {
          _matchedByName = null;
          _nameLookupBusy = false;
          _lookedUpName = null;
        });
      }
      return;
    }
    _nameLookupDebounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_lookupCardByName(q));
    });
  }

  Future<void> _lookupCardByName(String name) async {
    final user = ref.read(authControllerProvider);
    if (user == null || !canAccessBusinessCards(user)) return;
    setState(() {
      _nameLookupBusy = true;
      _lookedUpName = name;
    });
    try {
      final found = await ref
          .read(businessCardRepositoryProvider)
          .findByName(user: user, name: name);
      if (!mounted || _lookedUpName != name) return;
      final match = bestBusinessCardNameMatch(name, found);
      setState(() {
        _matchedByName = match;
        _nameLookupBusy = false;
      });
      if (match == null) return;
      final phone = match.primaryPhone.trim();
      if (phone.isEmpty) return;
      if (_phoneCtrl.text.trim().isNotEmpty && !_phoneFromCard) return;
      _applyPhoneFromCard(phone);
    } catch (_) {
      if (!mounted || _lookedUpName != name) return;
      setState(() {
        _matchedByName = null;
        _nameLookupBusy = false;
      });
    }
  }

  void _schedulePhoneLookup(String value) {
    _phoneLookupDebounce?.cancel();
    final digits = normalizePhoneDigits(value);
    if (digits.length < 8) {
      if (_matchedByPhone != null || _phoneLookupBusy) {
        setState(() {
          _matchedByPhone = null;
          _phoneLookupBusy = false;
          _lookedUpPhoneDigits = null;
        });
      }
      return;
    }
    _phoneLookupDebounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_lookupCardByPhone(digits));
    });
  }

  Future<void> _lookupCardByPhone(String digits) async {
    final user = ref.read(authControllerProvider);
    if (user == null || !canAccessBusinessCards(user)) return;
    setState(() {
      _phoneLookupBusy = true;
      _lookedUpPhoneDigits = digits;
    });
    try {
      final found = await ref
          .read(businessCardRepositoryProvider)
          .findByPhone(user: user, phone: digits);
      if (!mounted || _lookedUpPhoneDigits != digits) return;
      final match = found.isEmpty ? null : found.first;
      setState(() {
        _matchedByPhone = match;
        _phoneLookupBusy = false;
      });
      if (match == null) return;
      final name = match.name.trim();
      if (name.isEmpty) return;
      if (_nameCtrl.text.trim().isNotEmpty && !_nameFromCard) return;
      _applyNameFromCard(name);
    } catch (_) {
      if (!mounted || _lookedUpPhoneDigits != digits) return;
      setState(() {
        _matchedByPhone = null;
        _phoneLookupBusy = false;
      });
    }
  }

  void _applyPhoneFromCard(String phone) {
    _applyingPhone = true;
    _phoneFromCard = true;
    final formatted = formatKoreanPhoneHyphenated(phone);
    _phoneCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _applyingPhone = false;
  }

  void _applyNameFromCard(String name) {
    _applyingName = true;
    _nameFromCard = true;
    _nameCtrl.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    _applyingName = false;
  }

  void _onPhoneChanged(String value) {
    if (!_applyingPhone) _phoneFromCard = false;
    final formatted = formatKoreanPhoneHyphenated(value);
    if (formatted != value) {
      _phoneCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      return;
    }
    if (!_applyingPhone) _schedulePhoneLookup(formatted);
  }

  void _ensureDefaultProduct(MasterDataBundle master) {
    if (_productId != null || master.productCategories.isEmpty) return;
    final pending = (_pendingProductName ?? '').trim();
    if (pending.isNotEmpty) {
      for (final item in master.productCategories) {
        if (item.name == pending) {
          _productId = item.id;
          return;
        }
      }
    }
    _productId = master.productCategories
        .firstWhere(
          (e) => e.name.contains('스피드도어'),
          orElse: () => master.productCategories.first,
        )
        .id;
  }

  Future<void> _submit() async {
    final master = ref.read(masterDataProvider).valueOrNull;
    if (master != null) _ensureDefaultProduct(master);
    final site = _siteCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final issue = _issueCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    if (_productId == null) {
      _toast('제품군을 선택해 주세요.');
      return;
    }
    if (site.isEmpty && name.isEmpty) {
      _toast('현장명 또는 이름을 입력해 주세요.');
      return;
    }
    if (phone.isEmpty) {
      _toast('전화번호를 입력해 주세요.');
      return;
    }
    if (_uploadBusy) {
      _toast('파일 업로드가 끝날 때까지 기다려 주세요.');
      return;
    }
    var productName = '';
    if (master != null) {
      for (final p in master.productCategories) {
        if (p.id == _productId) {
          productName = p.name;
          break;
        }
      }
    }
    final urgencyLabel = switch (_urgency) {
      SupportUrgency.high => '상',
      SupportUrgency.mid => '중',
      SupportUrgency.low => '하',
    };
    final issueBody = [
      '[긴급도 $urgencyLabel] $productName',
      if (site.isNotEmpty) '현장: $site',
      if (issue.isNotEmpty) issue,
    ].join('\n');
    final user = ref.read(authControllerProvider);
    final draft = SupportCallLogDraft(
      customerName: name.isEmpty ? site : name,
      customerPhone: phone,
      issue: issueBody,
      address: address.isEmpty ? null : address,
      latitude: _addressLat,
      longitude: _addressLng,
      createdBy: user?.name ?? user?.id,
      firstImageUrls: List<String>.from(_attachmentUrls),
    );
    setState(() => _submitting = true);
    try {
      final repo = ref.read(supportCallLogRepositoryProvider);
      if (_isEdit) {
        final updated = await repo.update(widget.existing!.id, draft);
        ref.invalidate(supportHomeStatsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('A/S 접수가 수정되었습니다.')));
        Navigator.of(context).pop(updated);
        return;
      }
      final created = await repo.create(draft);
      ref.invalidate(supportHomeStatsProvider);
      unawaited(_notifyAdmins(created));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('A/S 접수가 저장되었습니다.')));
      await showSupportFirstConsultationSheet(context, log: created);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast(koreanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _notifyAdmins(SupportCallLog created) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'notify-as-reception',
        body: {
          'record': {
            'id': created.id,
            'customer_name': created.customerName,
            'customer_phone': created.customerPhone,
            if (created.issue.trim().isNotEmpty) 'issue': created.issue.trim(),
            if ((created.createdBy ?? '').trim().isNotEmpty)
              'created_by': created.createdBy!.trim(),
          },
        },
      );
      debugPrint('[notify-as-reception] status=${res.status} data=${res.data}');
    } catch (e, st) {
      debugPrint('[notify-as-reception] invoke failed: $e');
      debugPrint('$st');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUpload() async {
    final source = await showSalesCallImageSourceSheet(
      context,
      title: '파일 추가',
      includeFiles: true,
    );
    if (source == null) return;
    if (source == SalesCallImageSource.camera) {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (shot == null) return;
      await _uploadPaths([shot.path]);
      return;
    }
    if (source == SalesCallImageSource.gallery) {
      final shots = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (shots.isEmpty) return;
      await _uploadPaths(shots.map((e) => e.path).toList());
      return;
    }
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
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final paths = await _pathsFromPickedFiles(result.files);
    if (paths.isEmpty) {
      _toast('이미지 또는 PDF만 첨부할 수 있습니다.');
      return;
    }
    await _uploadPaths(paths);
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

  Future<void> _uploadPaths(List<String> paths) async {
    var finalPaths = paths;
    if (paths.length == 1 && isImageFile(paths.first)) {
      final edited = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageEditorScreen(initialImage: File(paths.first)),
        ),
      );
      finalPaths = [edited?.path ?? paths.first];
    }
    setState(() {
      _uploadBusy = true;
      _uploadTotal = finalPaths.length;
      _uploadCurrent = 0;
    });
    final uploader = ref.read(b2UploadRepositoryProvider);
    try {
      await Future.wait(
        finalPaths.map((path) async {
          try {
            final url = await uploader.uploadSupportCallFile(
              filePath: path,
              customerPhone: _phoneCtrl.text,
            );
            if (!mounted) return;
            setState(() {
              _attachmentUrls.add(url);
              _uploadCurrent++;
            });
          } catch (e) {
            if (!mounted) return;
            _toast('${p.basename(path)} 업로드 실패: ${koreanErrorMessage(e)}');
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
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final master = ref.watch(masterDataProvider).valueOrNull;
    if (master != null) {
      _ensureDefaultProduct(master);
    }
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'AS 접수 수정' : 'AS 접수 (테스트중)')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                const FormSectionHeader(
                  title: '긴급도',
                  icon: Icons.priority_high_rounded,
                  step: 1,
                ),
                const SizedBox(height: 8),
                _UrgencyRow(
                  value: _urgency,
                  onChanged: (v) => setState(() => _urgency = v),
                ),
                const SizedBox(height: 20),
                const FormSectionHeader(
                  title: '제품군',
                  icon: Icons.dashboard_customize_outlined,
                  step: 2,
                ),
                const SizedBox(height: 8),
                if (master == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else
                  _ProductChipGroup(
                    items: master.productCategories,
                    selectedId: _productId,
                    onSelected: (id) => setState(() => _productId = id),
                  ),
                const SizedBox(height: 20),
                const FormSectionHeader(
                  title: '현장 · 고객',
                  icon: Icons.person_outline_rounded,
                  step: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _siteCtrl,
                  decoration: const InputDecoration(labelText: '현장명'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                KakaoAddressField(
                  controller: _addressCtrl,
                  onSelected: (hit) {
                    _addressLat = hit.lat;
                    _addressLng = hit.lng;
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: '이름',
                    hintText: '이름 넣으면 명함에서 전화를 채웁니다',
                    suffixIcon: _nameLookupBusy
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _matchedCard == null
                        ? null
                        : Icon(
                            Icons.contact_page_rounded,
                            color: AppTokens.customerSupportAccent(scheme),
                          ),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: _onNameChanged,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: '전화번호',
                    hintText: '010-1234-5678',
                    helperText: _phoneFromCard
                        ? '명함에서 자동 입력됨'
                        : _matchedByPhone != null
                        ? '명함에서 찾음'
                        : null,
                    suffixIcon: _phoneLookupBusy
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _matchedByPhone == null
                        ? null
                        : Icon(
                            Icons.contact_page_rounded,
                            color: AppTokens.customerSupportAccent(scheme),
                          ),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: _onPhoneChanged,
                ),
                if (_matchedCard != null) ...[
                  const SizedBox(height: 8),
                  _MatchedCardBanner(
                    card: _matchedCard!,
                    phoneFilled: _phoneFromCard,
                    nameFilled: _nameFromCard,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BusinessCardDetailScreen(
                          cardId: _matchedCard!.id,
                          initial: _matchedCard,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const FormSectionHeader(
                  title: '문의 내용',
                  icon: Icons.notes_rounded,
                  step: 4,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _issueCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: '증상을 짧게 적어 주세요'),
                ),
                const SizedBox(height: 12),
                SalesCallAttachmentsStrip(
                  urls: _attachmentUrls,
                  editable: true,
                  uploadBusy: _uploadBusy,
                  progressLabel: _uploadTotal > 0
                      ? '전송 중 ($_uploadCurrent/$_uploadTotal)'
                      : null,
                  onAdd: _pickAndUpload,
                  onAddCamera: () async {
                    final shot = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (shot == null) return;
                    await _uploadPaths([shot.path]);
                  },
                  onRemoveAt: (i) =>
                      setState(() => _attachmentUrls.removeAt(i)),
                ),
                const SizedBox(height: 16),
                _AuthorBar(name: user?.name),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(96, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: _urgencyFill(scheme, _urgency),
                    foregroundColor: _urgencyOnFill(scheme, _urgency),
                  ),
                  onPressed: _submitting || _uploadBusy
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          unawaited(_submit());
                        },
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? '수정 저장' : '저장'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _urgencyFill(ColorScheme scheme, SupportUrgency urgency) =>
    switch (urgency) {
      SupportUrgency.high => scheme.error,
      SupportUrgency.mid => const Color(0xFFD97706),
      SupportUrgency.low => AppTokens.success(scheme),
    };

Color _urgencyOnFill(ColorScheme scheme, SupportUrgency urgency) {
  switch (urgency) {
    case SupportUrgency.high:
      return scheme.onError;
    case SupportUrgency.mid:
    case SupportUrgency.low:
      return Colors.white;
  }
}

class _ProductChipGroup extends StatelessWidget {
  const _ProductChipGroup({
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<NamedMasterRow> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedColor = AppTokens.success(scheme);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          FilterChip(
            label: Text(
              item.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selectedId == item.id
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
            selected: selectedId == item.id,
            showCheckmark: true,
            checkmarkColor: selectedColor,
            selectedColor: selectedColor.withValues(alpha: 0.18),
            side: BorderSide(
              color: selectedId == item.id
                  ? selectedColor
                  : scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              onSelected(item.id);
            },
          ),
      ],
    );
  }
}

class _UrgencyRow extends StatelessWidget {
  const _UrgencyRow({required this.value, required this.onChanged});

  final SupportUrgency value;
  final ValueChanged<SupportUrgency> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final item in SupportUrgency.values) ...[
          if (item != SupportUrgency.values.first) const SizedBox(width: 8),
          Expanded(
            child: _UrgencyButton(
              label: switch (item) {
                SupportUrgency.high => '상',
                SupportUrgency.mid => '중',
                SupportUrgency.low => '하',
              },
              selected: value == item,
              fill: _urgencyFill(scheme, item),
              onFill: _urgencyOnFill(scheme, item),
              onTap: () => onChanged(item),
            ),
          ),
        ],
      ],
    );
  }
}

class _UrgencyButton extends StatelessWidget {
  const _UrgencyButton({
    required this.label,
    required this.selected,
    required this.fill,
    required this.onFill,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color fill;
  final Color onFill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? fill : fill.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: selected ? onFill : fill,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchedCardBanner extends StatelessWidget {
  const _MatchedCardBanner({
    required this.card,
    required this.phoneFilled,
    this.nameFilled = false,
    required this.onTap,
  });

  final BusinessCard card;
  final bool phoneFilled;
  final bool nameFilled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final company = card.company.trim();
    final subtitle = [
      if (phoneFilled) '전화번호 자동 입력',
      if (nameFilled) '이름 자동 입력',
      if (company.isNotEmpty) company,
      if (card.isBlacklisted) '블랙리스트',
    ].join(' · ');
    return Material(
      color: card.isBlacklisted
          ? scheme.errorContainer.withValues(alpha: 0.7)
          : accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Icon(
                Icons.contact_page_rounded,
                color: card.isBlacklisted ? scheme.error : accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '명함 있음 · ${card.displayName}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: card.isBlacklisted
                            ? scheme.onErrorContainer
                            : scheme.onSurface,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthorBar extends StatelessWidget {
  const _AuthorBar({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display = (name ?? '').trim().isEmpty ? '-' : name!.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.person_rounded, color: scheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '작성자',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
