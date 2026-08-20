import 'dart:async';

import 'package:coad_customer_calls/core/utils/business_card_permissions.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/form_section.dart';
import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_detail_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/kakao_address_field.dart';
import 'package:coad_customer_calls/data/kakao_local_client.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SupportUrgency { high, mid, low }

class CustomerSupportIntakeScreen extends ConsumerStatefulWidget {
  const CustomerSupportIntakeScreen({super.key, this.site});

  final SupportSiteSample? site;

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
  double? _addressLat;
  double? _addressLng;
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

  BusinessCard? get _matchedCard => _matchedByPhone ?? _matchedByName;

  @override
  void initState() {
    super.initState();
    final site = widget.site;
    if (site != null) {
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AS 접수')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                const SupportComingSoonBanner(
                  message: '간단 접수 골격입니다. 저장은 다음 작업에서 붙입니다.',
                ),
                const SizedBox(height: 16),
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
                  title: '현장 · 고객',
                  icon: Icons.person_outline_rounded,
                  step: 2,
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
                  onSelected: (KakaoPlaceHit hit) {
                    setState(() {
                      _addressLat = hit.lat;
                      _addressLng = hit.lng;
                    });
                  },
                ),
                if (_addressLat != null && _addressLng != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      '위치 ${_addressLat!.toStringAsFixed(5)}, ${_addressLng!.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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
                  step: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _issueCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: '증상을 짧게 적어 주세요'),
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
                  onPressed: () => showSupportSkeletonSnack(context, '접수 저장'),
                  child: const Text('저장'),
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
