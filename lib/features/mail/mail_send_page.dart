import 'dart:async';

import 'package:coad_customer_calls/core/utils/business_card_permissions.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/data/mail_repository.dart';
import 'package:coad_customer_calls/features/mail/mail_compose.dart';
import 'package:coad_customer_calls/features/mail/mail_helpers.dart';
import 'package:coad_customer_calls/features/mail/mail_models.dart';
import 'package:coad_customer_calls/features/mail/mail_providers.dart';
import 'package:coad_customer_calls/features/mail/mail_recipient_sheet.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MailSendPage extends ConsumerStatefulWidget {
  const MailSendPage({super.key});

  @override
  ConsumerState<MailSendPage> createState() => _MailSendPageState();
}

class _MailSendPageState extends ConsumerState<MailSendPage> {
  final _toCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedFileIds = {};
  final Set<String> _collapsedGroups = {};
  final bool _notifyTelegram = true;
  bool _sending = false;
  bool _emailTouched = false;
  BusinessCard? _pickedCard;
  List<BusinessCard> _cardHits = const [];
  Timer? _cardDebounce;
  bool _didCollapseGroups = false;
  bool _manualEmail = false;
  MailReuseRequest? _pendingReuse;

  @override
  void dispose() {
    _cardDebounce?.cancel();
    _toCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  MailAssignee _lockedSender(MailCatalog catalog) {
    final me = ref.read(authControllerProvider);
    if (me != null) {
      for (final u in catalog.assignees) {
        if (u.id == me.id) return u;
      }
    }
    return MailAssignee(
      id: me?.id ?? '',
      name: me?.name ?? '',
      groupName: me?.groupName,
    );
  }

  void _syncLockedSender(MailCatalog catalog) {
    final s = _lockedSender(catalog);
    final phone = s.phone?.trim() ?? '';
    final email = s.email?.trim() ?? '';
    if (_phoneCtrl.text != phone) _phoneCtrl.text = phone;
    if (_emailCtrl.text != email) _emailCtrl.text = email;
  }

  void _ensureCollapsedGroups(MailCatalog catalog) {
    if (_didCollapseGroups) return;
    _didCollapseGroups = true;
    _collapsedGroups.addAll(catalog.groups.map((g) => g.id));
  }

  void _applyReuse(MailReuseRequest req, MailCatalog catalog) {
    _toCtrl.text = req.toEmail;
    _toCtrl.selection = TextSelection.collapsed(offset: _toCtrl.text.length);
    _pickedCard = null;
    _manualEmail = req.toEmail.contains('@');
    _cardHits = const [];
    _emailTouched = true;
    _selectedFileIds
      ..clear()
      ..addAll(matchAttachmentFileIds(catalog.files, req.attachments));
  }

  List<MailFile> _visibleItems(MailFileGroup group, String query) {
    var items = [...group.items];
    if (query.isNotEmpty) {
      final catMatch = group.name.toLowerCase().contains(query);
      if (!catMatch) {
        items = items
            .where(
              (f) =>
                  f.displayName.toLowerCase().contains(query) ||
                  f.originalName.toLowerCase().contains(query),
            )
            .toList();
      }
    }
    return items;
  }

  bool _groupMatches(MailFileGroup group, String query) {
    if (query.isEmpty) return true;
    if (group.name.toLowerCase().contains(query)) return true;
    return group.items.any(
      (f) =>
          f.displayName.toLowerCase().contains(query) ||
          f.originalName.toLowerCase().contains(query),
    );
  }

  void _toggleGroup(List<MailFile> items) {
    if (items.isEmpty) return;
    final ids = items.map((e) => e.id).toSet();
    final allOn = ids.every(_selectedFileIds.contains);
    setState(() {
      if (allOn) {
        _selectedFileIds.removeAll(ids);
      } else {
        _selectedFileIds.addAll(ids);
      }
    });
  }

  void _applyRecipientCard(BusinessCard card) {
    _pickedCard = card;
    _manualEmail = false;
    _toCtrl.text = card.email.trim();
    _toCtrl.selection = TextSelection.collapsed(offset: _toCtrl.text.length);
    _cardHits = const [];
    _emailTouched = true;
  }

  void _onRecipientChanged(String raw) {
    if (_pickedCard != null && _pickedCard!.email.trim() != raw.trim()) {
      _pickedCard = null;
    }
    setState(() {});
    _scheduleCardSearch(raw);
  }

  void _scheduleCardSearch(String raw) {
    _cardDebounce?.cancel();
    final user = ref.read(authControllerProvider);
    if (user == null || !canAccessBusinessCards(user)) {
      if (_cardHits.isNotEmpty) setState(() => _cardHits = const []);
      return;
    }
    final q = raw.trim();
    if (q.contains('@') || q.length < 2) {
      if (_cardHits.isNotEmpty) setState(() => _cardHits = const []);
      return;
    }
    _cardDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_searchRecipientCards(q));
    });
  }

  Future<void> _searchRecipientCards(String query) async {
    final user = ref.read(authControllerProvider);
    if (user == null || !canAccessBusinessCards(user)) return;
    try {
      final result = await ref
          .read(businessCardRepositoryProvider)
          .list(user: user, query: query, limit: 20);
      if (!mounted || _toCtrl.text.trim() != query) return;
      setState(() {
        _cardHits = businessCardsForMailRecipient(
          query,
          result.items,
          limit: 5,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cardHits = const []);
    }
  }

  Future<void> _pickRecipientCard() async {
    final user = ref.read(authControllerProvider);
    if (user == null || !canAccessBusinessCards(user)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('명함 수첩 권한이 없습니다.')));
      return;
    }
    final card = await showMailRecipientCardSheet(
      context,
      user: user,
      repo: ref.read(businessCardRepositoryProvider),
    );
    if (card == null || !mounted) return;
    setState(() => _applyRecipientCard(card));
  }

  Future<void> _confirmAndSend(MailCatalog catalog) async {
    final to = _toCtrl.text.trim();
    setState(() => _emailTouched = true);
    if (!MailCompose.isValidEmail(to) || _selectedFileIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !MailCompose.isValidEmail(to)
                ? '받는 사람 이메일을 확인해 주세요.'
                : '보낼 자료를 선택해 주세요.',
          ),
        ),
      );
      return;
    }
    final sender = _lockedSender(catalog);
    final selectedFiles = catalog.files
        .where((f) => _selectedFileIds.contains(f.id))
        .toList();
    final attachmentNames = selectedFiles.map((f) => f.displayName).toList();
    final subject = MailCompose.subject(senderName: sender.name);
    final body = MailCompose.body(
      senderName: sender.name,
      phone: _phoneCtrl.text,
      email: _emailCtrl.text,
      attachmentNames: attachmentNames,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final accent = AppTokens.mailAccent(scheme);
        final inset = MediaQuery.viewInsetsOf(ctx).bottom;
        final maxH = MediaQuery.sizeOf(ctx).height * 0.88;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '이대로 보낼까요?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ConfirmRow(
                          icon: Icons.south_west_rounded,
                          label: '받는 사람',
                          value: _pickedCard == null
                              ? to
                              : '${_pickedCard!.displayName} · $to',
                        ),
                        const SizedBox(height: 10),
                        _ConfirmRow(
                          icon: Icons.person_outline_rounded,
                          label: '보내는 사람',
                          value: sender.name.isEmpty ? '미지정' : sender.name,
                        ),
                        const SizedBox(height: 10),
                        _ConfirmRow(
                          icon: Icons.subject_rounded,
                          label: '제목',
                          value: subject,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '첨부 ${selectedFiles.length}개',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final f in selectedFiles)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.attach_file_rounded,
                                  size: 16,
                                  color: accent,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    f.displayName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          '메일 내용',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Text(
                              body,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('보내기'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            '취소',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    await _send(catalog);
  }

  Future<void> _send(MailCatalog catalog) async {
    final sender = _lockedSender(catalog);
    final stored = catalog.files
        .where((f) => _selectedFileIds.contains(f.id))
        .map(
          (f) => MailAttachment(
            name: f.originalName.trim().isEmpty
                ? f.displayName
                : f.originalName,
            url: f.url,
          ),
        )
        .toList();
    final names = catalog.files
        .where((f) => _selectedFileIds.contains(f.id))
        .map((f) => f.displayName)
        .toList();
    setState(() => _sending = true);
    try {
      final agents = ref.read(mailTelegramAgentsProvider).valueOrNull ?? [];
      final agent = MailCompose.resolveTelegramAgentName(sender.name, agents);
      await ref
          .read(mailRepositoryProvider)
          .sendMail(
            MailSendRequest(
              toEmail: _toCtrl.text,
              subject: MailCompose.subject(senderName: sender.name),
              body: MailCompose.body(
                senderName: sender.name,
                phone: _phoneCtrl.text,
                email: _emailCtrl.text,
                attachmentNames: names,
              ),
              attachments: stored,
              sender: sender,
              notifyTelegram: _notifyTelegram && agent.isNotEmpty,
              telegramAgentName: agent,
            ),
          );
      if (!mounted) return;
      setState(() {
        _toCtrl.clear();
        _selectedFileIds.clear();
        _emailTouched = false;
        _searchCtrl.clear();
        _pickedCard = null;
        _cardHits = const [];
      });
      ref.invalidate(mailSendsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메일을 보냈습니다.')));
    } on MailDeliveryUnconfirmedException catch (e) {
      if (!mounted) return;
      setState(() {
        _toCtrl.clear();
        _selectedFileIds.clear();
        _emailTouched = false;
        _searchCtrl.clear();
        _pickedCard = null;
        _cardHits = const [];
      });
      ref.invalidate(mailSendsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ref.invalidate(mailSendsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MailReuseRequest?>(mailReuseProvider, (prev, next) {
      if (next == null) return;
      final catalog = ref.read(mailCatalogProvider).valueOrNull;
      if (catalog != null) {
        setState(() => _applyReuse(next, catalog));
      } else {
        _pendingReuse = next;
      }
      ref.read(mailReuseProvider.notifier).state = null;
    });

    final catalogAsync = ref.watch(mailCatalogProvider);
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.mailAccent(scheme);
    return catalogAsync.when(
      loading: () => const AppLoading(message: '메일 자료를 불러오는 중…'),
      error: (e, _) => AppEmpty(
        icon: Icons.cloud_off_rounded,
        message: '메일 자료를 불러오지 못했습니다.',
        detail: '$e',
        actionLabel: '다시 시도',
        onAction: () => ref.invalidate(mailCatalogProvider),
      ),
      data: (catalog) {
        _syncLockedSender(catalog);
        _ensureCollapsedGroups(catalog);
        final sender = _lockedSender(catalog);
        if (_pendingReuse != null) {
          final req = _pendingReuse!;
          _pendingReuse = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _applyReuse(req, catalog));
          });
        }
        final query = _searchCtrl.text.trim().toLowerCase();
        final to = _toCtrl.text.trim();
        final emailOk = to.isEmpty || MailCompose.isValidEmail(to);
        final attachCount = _selectedFileIds.length;
        final ready =
            MailCompose.isValidEmail(to) && attachCount > 0 && !_sending;
        final visibleGroups = catalog.groups
            .where((g) => _groupMatches(g, query))
            .toList();
        final canUseCards = canAccessBusinessCards(
          ref.watch(authControllerProvider),
        );

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (_pickedCard != null)
                    _PickedRecipientTile(
                      card: _pickedCard!,
                      accent: accent,
                      onChange: _pickRecipientCard,
                      onClear: () => setState(() {
                        _pickedCard = null;
                        _toCtrl.clear();
                      }),
                    )
                  else if (canUseCards && !_manualEmail)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: _pickRecipientCard,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text(
                            '명함에서 고르기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _manualEmail = true),
                          child: const Text('이메일로 직접 입력'),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _toCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          autofocus: _manualEmail,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          onChanged: _onRecipientChanged,
                          onEditingComplete: () =>
                              setState(() => _emailTouched = true),
                          decoration: InputDecoration(
                            hintText: '받는 사람 이메일 또는 이름',
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                            ),
                            errorText: _emailTouched && !emailOk
                                ? '이메일 형식을 확인해 주세요'
                                : null,
                            suffixIcon: canUseCards
                                ? IconButton(
                                    tooltip: '명함',
                                    onPressed: _pickRecipientCard,
                                    icon: const Icon(Icons.badge_outlined),
                                  )
                                : null,
                          ),
                        ),
                        if (_cardHits.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final card in _cardHits)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.badge_outlined,
                                color: accent,
                              ),
                              title: Text(
                                [
                                  card.displayName,
                                  if (card.company.trim().isNotEmpty)
                                    card.company.trim(),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(card.email.trim()),
                              onTap: () =>
                                  setState(() => _applyRecipientCard(card)),
                            ),
                        ],
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 14),
                    child: Text(
                      sender.name.isEmpty
                          ? '로그인한 계정으로 보냅니다'
                          : '${sender.name}으로 보냅니다',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '자료',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (attachCount > 0)
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedFileIds.clear()),
                          child: Text('$attachCount개 해제'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '자료 검색',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (catalog.files.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Text(
                        '웹 자료실에 등록된 파일이 없습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else if (visibleGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Text(
                        '검색 결과가 없습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    ...visibleGroups.map((group) {
                      final items = _visibleItems(group, query);
                      if (items.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final selectedN = items
                          .where((f) => _selectedFileIds.contains(f.id))
                          .length;
                      final allOn = selectedN == items.length;
                      final open = !_collapsedGroups.contains(group.id);
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: allOn
                                  ? accent.withValues(alpha: 0.4)
                                  : scheme.outlineVariant.withValues(
                                      alpha: 0.45,
                                    ),
                            ),
                            color: allOn
                                ? accent.withValues(alpha: 0.05)
                                : scheme.surfaceContainerHighest.withValues(
                                    alpha: 0.28,
                                  ),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                                onTap: () => _toggleGroup(items),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    16,
                                    4,
                                    16,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: group.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          group.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        selectedN == 0
                                            ? '${items.length}개'
                                            : '$selectedN/${items.length}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: selectedN > 0
                                              ? accent
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        allOn
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        color: allOn ? accent : scheme.outline,
                                      ),
                                      IconButton(
                                        tooltip: open ? '접기' : '파일 고르기',
                                        onPressed: () => setState(() {
                                          if (open) {
                                            _collapsedGroups.add(group.id);
                                          } else {
                                            _collapsedGroups.remove(group.id);
                                          }
                                        }),
                                        icon: Icon(
                                          open
                                              ? Icons.expand_less_rounded
                                              : Icons.expand_more_rounded,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (open)
                                ...items.map((f) {
                                  final on = _selectedFileIds.contains(f.id);
                                  return InkWell(
                                    onTap: () => setState(() {
                                      if (on) {
                                        _selectedFileIds.remove(f.id);
                                      } else {
                                        _selectedFileIds.add(f.id);
                                      }
                                    }),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        10,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            on
                                                ? Icons.check_circle_rounded
                                                : Icons.circle_outlined,
                                            size: 22,
                                            color: on ? accent : scheme.outline,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              f.displayName,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: on
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            Material(
              elevation: 8,
              color: scheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: FilledButton(
                    onPressed: ready ? () => _confirmAndSend(catalog) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      disabledBackgroundColor: scheme.surfaceContainerHighest,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            attachCount == 0
                                ? '자료를 선택하세요'
                                : '자료 $attachCount개 보내기',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PickedRecipientTile extends StatelessWidget {
  const _PickedRecipientTile({
    required this.card,
    required this.accent,
    required this.onChange,
    required this.onClear,
  });

  final BusinessCard card;
  final Color accent;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: accent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onChange,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.16),
                foregroundColor: accent,
                child: Text(
                  card.initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        card.displayName,
                        if (card.company.trim().isNotEmpty) card.company.trim(),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      card.email.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '지우기',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
