import 'dart:io';

import 'package:coad_customer_calls/core/utils/business_card_image.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/cached_app_image.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_crop_screen.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_widgets.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_source_sheet.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class BusinessCardEditScreen extends ConsumerStatefulWidget {
  const BusinessCardEditScreen({super.key, this.existing});

  final BusinessCard? existing;

  @override
  ConsumerState<BusinessCardEditScreen> createState() =>
      _BusinessCardEditScreenState();
}

class _BusinessCardEditScreenState extends ConsumerState<BusinessCardEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _officeCtrl = TextEditingController();
  final _faxCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  BusinessCardVisibility _visibility = BusinessCardVisibility.team;
  bool _isBlacklisted = false;
  String _imageUrl = '';
  String? _localImagePath;
  bool _aiBusy = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _companyCtrl.text = e.company;
      _titleCtrl.text = e.title;
      _mobileCtrl.text = e.mobilePhone;
      _officeCtrl.text = e.officePhone;
      _faxCtrl.text = e.faxPhone;
      _emailCtrl.text = e.email;
      _addressCtrl.text = e.address;
      _memoCtrl.text = e.memo;
      _visibility = e.visibility;
      _isBlacklisted = e.isBlacklisted;
      _imageUrl = e.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _titleCtrl.dispose();
    _mobileCtrl.dispose();
    _officeCtrl.dispose();
    _faxCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<String?> _pickImagePath() async {
    final source = await showSalesCallImageSourceSheet(
      context,
      title: '명함 사진',
    );
    if (source == null) return null;
    if (source == SalesCallImageSource.camera) {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      return shot?.path;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    return result?.files.first.path;
  }

  Future<void> _scan() async {
    var path = await _pickImagePath();
    if (path == null || !mounted) return;
    final cropped = await cropBusinessCardImage(context, imagePath: path);
    if (cropped == null || !mounted) return;
    path = cropped;
    setState(() => _aiBusy = true);
    try {
      final prepared = await prepareBusinessCardImage(path);
      if (!mounted) return;
      setState(() => _localImagePath = prepared.path);
      final result = await ref
          .read(aiExtractorServiceProvider)
          .extractBusinessCard(prepared.bytes, filePath: prepared.path);
      if (!mounted) return;
      setState(() {
        if (result.name.isNotEmpty) _nameCtrl.text = result.name;
        if (result.company.isNotEmpty) _companyCtrl.text = result.company;
        if (result.title.isNotEmpty) _titleCtrl.text = result.title;
        if (result.phone.isNotEmpty) {
          _mobileCtrl.text = formatKoreanPhoneHyphenated(
            normalizePhoneDigits(result.phone),
          );
        }
        if (result.officePhone.isNotEmpty) {
          _officeCtrl.text = formatKoreanPhoneHyphenated(
            normalizePhoneDigits(result.officePhone),
          );
        }
        if (result.faxPhone.isNotEmpty) {
          _faxCtrl.text = formatKoreanPhoneHyphenated(
            normalizePhoneDigits(result.faxPhone),
          );
        }
        if (result.email.isNotEmpty) _emailCtrl.text = result.email;
        if (result.address.isNotEmpty) _addressCtrl.text = result.address;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인식 결과를 확인한 뒤 저장하세요.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('명함 인식 실패: ${koreanErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  BusinessCard _draftFromForm(String id) {
    String fmt(String raw) {
      final d = normalizePhoneDigits(raw);
      if (d.length < 8) return raw.trim();
      return formatKoreanPhoneHyphenated(d);
    }

    return BusinessCard(
      id: id,
      name: _nameCtrl.text,
      company: _companyCtrl.text,
      title: _titleCtrl.text,
      mobilePhone: fmt(_mobileCtrl.text),
      officePhone: fmt(_officeCtrl.text),
      faxPhone: fmt(_faxCtrl.text),
      email: _emailCtrl.text,
      address: _addressCtrl.text,
      memo: _memoCtrl.text,
      imageUrl: _imageUrl,
      visibility: _visibility,
      isBlacklisted: _isBlacklisted,
      createdBy: widget.existing?.createdBy ?? '',
      createdByName: widget.existing?.createdByName ?? '',
      updatedBy: '',
      updatedByName: '',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (_nameCtrl.text.trim().isEmpty && _companyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름 또는 회사명을 입력해 주세요.')),
      );
      return;
    }

    final user = ref.read(authControllerProvider);
    if (user == null) return;
    final repo = ref.read(businessCardRepositoryProvider);
    final draft = _draftFromForm(widget.existing?.id ?? '');

    final phone = draft.primaryPhone;
    if (phone.isNotEmpty) {
      try {
        final dupes = await repo.findByPhone(
          user: user,
          phone: phone,
          excludeId: widget.existing?.id,
        );
        if (dupes.isNotEmpty && mounted) {
          final names = dupes.map((c) => c.displayName).take(3).join(', ');
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('같은 번호 명함'),
              content: Text('이미 등록된 번호입니다.\n$names\n그래도 저장할까요?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('저장'),
                ),
              ],
            ),
          );
          if (ok != true) return;
        }
      } catch (_) {}
    }

    setState(() => _saving = true);
    try {
      var imageUrl = _imageUrl;
      if (_localImagePath != null) {
        imageUrl = await ref.read(b2UploadRepositoryProvider).uploadBusinessCardFile(
              filePath: _localImagePath!,
              userId: user.id,
            );
      }
      final firstMemo = _memoCtrl.text.trim();
      final toSave = draft.copyWith(imageUrl: imageUrl, memo: '');
      if (_isEdit) {
        await repo.update(
          user: user,
          card: toSave.copyWith(memo: widget.existing?.memo ?? ''),
        );
      } else {
        final created = await repo.create(user: user, draft: toSave);
        if (firstMemo.isNotEmpty) {
          await repo.addComment(
            user: user,
            cardId: created.id,
            body: firstMemo,
          );
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          _isEdit ? '명함 수정' : '명함 등록',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _saving || _aiBusy ? null : _save,
            child: Text(
              '저장',
              style: TextStyle(
                color: Colors.white.withValues(alpha: _saving ? 0.5 : 1),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _imageBlock(scheme),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _aiBusy || _saving ? null : _scan,
                icon: _aiBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.contact_page_outlined, size: 18),
                label: Text(_aiBusy ? '명함 인식 중…' : '명함 촬영·인식'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 20),
              _field('이름', _nameCtrl, hint: '홍길동'),
              const SizedBox(height: 12),
              _field('회사', _companyCtrl, hint: '회사명'),
              const SizedBox(height: 12),
              _field('직함', _titleCtrl, hint: '대표이사'),
              const SizedBox(height: 12),
              _field(
                '휴대폰',
                _mobileCtrl,
                hint: '010-0000-0000',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _field(
                '회사 전화',
                _officeCtrl,
                hint: '02-0000-0000',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _field(
                '팩스',
                _faxCtrl,
                hint: '02-0000-0000',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _field(
                '이메일',
                _emailCtrl,
                hint: 'name@company.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _field('주소', _addressCtrl, hint: '주소', maxLines: 2),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                _field(
                  '첫 메모 (선택)',
                  _memoCtrl,
                  hint: '저장 후에도 상세에서 계속 남길 수 있습니다',
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '블랙리스트',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                subtitle: const Text('거래 주의 대상으로 표시합니다.'),
                value: _isBlacklisted,
                onChanged: (v) => setState(() => _isBlacklisted = v),
                secondary: Icon(
                  Icons.block_rounded,
                  color: _isBlacklisted
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '공개 범위',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('팀 공유'),
                    avatar: const Icon(Icons.groups_outlined, size: 16),
                    showCheckmark: false,
                    selected: _visibility == BusinessCardVisibility.team,
                    onSelected: (_) {
                      setState(() => _visibility = BusinessCardVisibility.team);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('나만 보기'),
                    avatar: const Icon(Icons.lock_outline_rounded, size: 16),
                    showCheckmark: false,
                    selected: _visibility == BusinessCardVisibility.private,
                    onSelected: (_) {
                      setState(
                        () => _visibility = BusinessCardVisibility.private,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _visibility == BusinessCardVisibility.private
                    ? '본인과 관리자만 볼 수 있습니다.'
                    : '로그인한 영업 담당자가 검색·열람할 수 있습니다.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageBlock(ColorScheme scheme) {
    Widget child;
    if (_localImagePath != null) {
      child = Image.file(
        File(_localImagePath!),
        fit: BoxFit.cover,
        cacheWidth: 800,
        filterQuality: FilterQuality.low,
      );
    } else if (_imageUrl.isNotEmpty) {
      child = CachedAppImage(url: _imageUrl, fit: BoxFit.cover);
    } else {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined, size: 36, color: scheme.outline),
          const SizedBox(height: 8),
          Text(
            '명함 사진',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        height: 160,
        width: double.infinity,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: child,
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String hint = '',
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: businessCardInputDecoration(context, hint),
        ),
      ],
    );
  }
}
