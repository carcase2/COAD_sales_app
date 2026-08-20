import 'dart:async';

import 'package:coad_customer_calls/core/utils/business_card_permissions.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/cached_app_image.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_edit_screen.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_widgets.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class BusinessCardDetailScreen extends ConsumerStatefulWidget {
  const BusinessCardDetailScreen({
    super.key,
    required this.cardId,
    this.initial,
  });

  final String cardId;
  final BusinessCard? initial;

  @override
  ConsumerState<BusinessCardDetailScreen> createState() =>
      _BusinessCardDetailScreenState();
}

class _BusinessCardDetailScreenState
    extends ConsumerState<BusinessCardDetailScreen> {
  BusinessCard? _card;
  List<BusinessCardComment> _comments = const [];
  bool _loading = true;
  bool _changed = false;
  Object? _error;
  final _commentCtrl = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _card = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    setState(() {
      _loading = _card == null;
      _error = null;
    });
    try {
      final repo = ref.read(businessCardRepositoryProvider);
      final card = await repo.getById(user: user, id: widget.cardId);
      final comments = await repo.listComments(user: user, cardId: widget.cardId);
      if (!mounted) return;
      setState(() {
        _card = card;
        _comments = comments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    final card = _card;
    if (card == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BusinessCardEditScreen(existing: card),
      ),
    );
    if (saved == true) {
      _changed = true;
      await _reload();
    }
  }

  Future<void> _delete() async {
    final user = ref.read(authControllerProvider);
    final card = _card;
    if (user == null || card == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('명함 삭제'),
        content: const Text('이 명함을 삭제할까요? 메모 기록도 함께 숨겨집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(businessCardRepositoryProvider).softDelete(
            user: user,
            card: card,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    }
  }

  Future<void> _setBlacklisted(bool value) async {
    final user = ref.read(authControllerProvider);
    final card = _card;
    if (user == null || card == null) return;
    try {
      final updated = await ref.read(businessCardRepositoryProvider).update(
            user: user,
            card: card.copyWith(isBlacklisted: value),
          );
      if (!mounted) return;
      setState(() {
        _card = updated;
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    }
  }

  Future<void> _postComment() async {
    final user = ref.read(authControllerProvider);
    final body = _commentCtrl.text.trim();
    if (user == null || body.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      final comment = await ref.read(businessCardRepositoryProvider).addComment(
            user: user,
            cardId: widget.cardId,
            body: body,
          );
      if (!mounted) return;
      _commentCtrl.clear();
      setState(() {
        _comments = [..._comments, comment];
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _editComment(BusinessCardComment comment) async {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    final ctrl = TextEditingController(text: comment.body);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모 수정'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (next == null || next.isEmpty) return;
    try {
      final updated = await ref.read(businessCardRepositoryProvider).updateComment(
            user: user,
            comment: comment,
            body: next,
          );
      if (!mounted) return;
      setState(() {
        _comments = _comments
            .map((c) => c.id == updated.id ? updated : c)
            .toList();
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    }
  }

  Future<void> _deleteComment(BusinessCardComment comment) async {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    try {
      await ref.read(businessCardRepositoryProvider).deleteComment(
            user: user,
            comment: comment,
          );
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((c) => c.id != comment.id).toList();
        _changed = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    }
  }

  Future<void> _openEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider);
    final card = _card;
    final canEdit = card != null && canEditBusinessCard(user, card);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(
            card?.displayName ?? '명함',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          centerTitle: true,
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          actions: [
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '수정',
                onPressed: _edit,
              ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: '삭제',
                onPressed: _delete,
              ),
          ],
        ),
        body: _buildBody(scheme, user),
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme, AppUser? user) {
    if (_loading) return const AppLoading(message: '명함을 불러오는 중…');
    if (_error != null && _card == null) {
      return AppErrorState(
        message: koreanErrorMessage(_error!),
        onRetry: () => unawaited(_reload()),
      );
    }
    final card = _card;
    if (card == null) {
      return const AppEmpty(message: '명함을 찾을 수 없습니다.');
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              if (card.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedAppImage(url: card.imageUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BusinessCardAvatar(card: card, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        if (card.subtitle.isNotEmpty)
                          Text(
                            card.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            BusinessCardVisibilityChip(
                              visibility: card.visibility,
                            ),
                            if (card.isBlacklisted)
                              BusinessCardBlacklistChip(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '블랙리스트',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                subtitle: Text(
                  canEditBusinessCard(user, card)
                      ? '거래 주의 대상으로 표시합니다.'
                      : '작성자 또는 관리자만 변경할 수 있습니다.',
                ),
                value: card.isBlacklisted,
                onChanged: canEditBusinessCard(user, card)
                    ? (v) => unawaited(_setBlacklisted(v))
                    : null,
                secondary: Icon(
                  Icons.block_rounded,
                  color: card.isBlacklisted ? scheme.error : scheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              if (card.mobilePhone.isNotEmpty)
                _contactTile(
                  icon: Icons.smartphone_outlined,
                  label: '휴대폰',
                  value: card.mobilePhone,
                  onTap: () => LauncherUtils.makePhoneCall(card.mobilePhone),
                  extra: IconButton(
                    tooltip: '문자',
                    icon: const Icon(Icons.sms_outlined),
                    onPressed: () => LauncherUtils.sendSMS(card.mobilePhone),
                  ),
                ),
              if (card.officePhone.isNotEmpty)
                _contactTile(
                  icon: Icons.phone_outlined,
                  label: '회사 전화',
                  value: card.officePhone,
                  onTap: () => LauncherUtils.makePhoneCall(card.officePhone),
                ),
              if (card.faxPhone.isNotEmpty)
                _contactTile(
                  icon: Icons.fax_outlined,
                  label: '팩스',
                  value: card.faxPhone,
                  onTap: () => LauncherUtils.copyPhone(context, card.faxPhone),
                ),
              if (card.email.isNotEmpty)
                _contactTile(
                  icon: Icons.mail_outline_rounded,
                  label: '이메일',
                  value: card.email,
                  onTap: () => unawaited(_openEmail(card.email)),
                ),
              if (card.address.isNotEmpty)
                _contactTile(
                  icon: Icons.place_outlined,
                  label: '주소',
                  value: card.address,
                  onTap: () => LauncherUtils.copyPhone(context, card.address),
                ),
              const SizedBox(height: 8),
              Text(
                '등록 ${card.createdByName} · ${formatSeoulDateTime(card.createdAt)}'
                '${card.updatedByName.isNotEmpty && card.updatedAt != card.createdAt ? '\n수정 ${card.updatedByName} · ${formatSeoulDateTime(card.updatedAt)}' : ''}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Text(
                '메모 기록 ${_memoCount(card)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              if (card.memo.isEmpty && _comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '아직 메모가 없습니다. 아래에 남겨 주세요.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (card.memo.isNotEmpty)
                _memoTile(
                  author: card.createdByName,
                  at: card.createdAt,
                  body: card.memo,
                  scheme: scheme,
                ),
              ..._comments.map((c) => _commentTile(c, user, scheme)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    minLines: 1,
                    maxLines: 3,
                    decoration: businessCardInputDecoration(
                      context,
                      '메모를 남겨 주세요',
                    ),
                    onSubmitted: (_) => unawaited(_postComment()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _posting ? null : () => unawaited(_postComment()),
                  icon: _posting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _contactTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    Widget? extra,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      onTap: onTap,
      trailing: extra,
    );
  }

  int _memoCount(BusinessCard card) =>
      (card.memo.trim().isEmpty ? 0 : 1) + _comments.length;

  Widget _memoTile({
    required String author,
    required DateTime at,
    required String body,
    required ColorScheme scheme,
    Widget? actions,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatSeoulMemoStamp(at)}  $author',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 14, height: 1.4)),
            ?actions,
          ],
        ),
      ),
    );
  }

  Widget _commentTile(
    BusinessCardComment comment,
    AppUser? user,
    ColorScheme scheme,
  ) {
    Widget? actions;
    if (canEditBusinessCardComment(user: user, comment: comment) ||
        canDeleteBusinessCardComment(user: user, comment: comment)) {
      actions = Row(
        children: [
          if (canEditBusinessCardComment(user: user, comment: comment))
            TextButton(
              onPressed: () => unawaited(_editComment(comment)),
              child: const Text('수정'),
            ),
          if (canDeleteBusinessCardComment(user: user, comment: comment))
            TextButton(
              onPressed: () => unawaited(_deleteComment(comment)),
              child: Text('삭제', style: TextStyle(color: scheme.error)),
            ),
        ],
      );
    }
    return _memoTile(
      author: comment.createdByName,
      at: comment.createdAt,
      body: comment.body + (comment.edited ? ' (수정됨)' : ''),
      scheme: scheme,
      actions: actions,
    );
  }
}
