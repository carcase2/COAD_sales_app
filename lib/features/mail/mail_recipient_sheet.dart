import 'dart:async';

import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<BusinessCard?> showMailRecipientCardSheet(
  BuildContext context, {
  required AppUser user,
  required BusinessCardRepository repo,
}) {
  return showModalBottomSheet<BusinessCard>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _MailRecipientSheet(user: user, repo: repo),
  );
}

class _MailRecipientSheet extends StatefulWidget {
  const _MailRecipientSheet({required this.user, required this.repo});

  final AppUser user;
  final BusinessCardRepository repo;

  @override
  State<_MailRecipientSheet> createState() => _MailRecipientSheetState();
}

class _MailRecipientSheetState extends State<_MailRecipientSheet> {
  final _q = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<BusinessCard> _items = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_load(raw));
    });
  }

  Future<void> _load(String raw) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repo.list(
        user: widget.user,
        query: raw.trim(),
        limit: 40,
      );
      if (!mounted) return;
      setState(() {
        _items = businessCardsForMailRecipient(raw, result.items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _items = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.mailAccent(scheme);
    final h = MediaQuery.sizeOf(context).height * 0.78;

    return SizedBox(
      height: h,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '명함에서 고르기',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '이메일이 있는 명함만 표시됩니다.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _q,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '이름 · 회사 · 이메일 검색',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(scheme, accent)),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme, Color accent) {
    if (_loading && _items.isEmpty) {
      return const AppLoading(message: '명함을 찾는 중…', compact: true);
    }
    if (_error != null && _items.isEmpty) {
      return AppEmpty(
        icon: Icons.cloud_off_rounded,
        message: '명함을 불러오지 못했습니다.',
        detail: _error,
        actionLabel: '다시 시도',
        onAction: () => unawaited(_load(_q.text)),
      );
    }
    if (_items.isEmpty) {
      return AppEmpty(
        icon: Icons.badge_outlined,
        message: _q.text.trim().isEmpty
            ? '이메일이 있는 명함이 없습니다.'
            : '검색된 명함에 이메일이 없습니다.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, i) {
        final card = _items[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: accent.withValues(alpha: 0.14),
            foregroundColor: accent,
            child: Text(
              card.initials,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          title: Text(
            card.displayName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            [
              if (card.company.trim().isNotEmpty) card.company.trim(),
              card.email.trim(),
            ].join(' · '),
          ),
          trailing: Icon(
            Icons.north_east_rounded,
            color: scheme.onSurfaceVariant,
          ),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context, card);
          },
        );
      },
    );
  }
}
