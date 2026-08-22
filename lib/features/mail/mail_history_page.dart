import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/features/mail/mail_helpers.dart';
import 'package:coad_customer_calls/features/mail/mail_models.dart';
import 'package:coad_customer_calls/features/mail/mail_providers.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

enum _HistoryFilter { all, mine, failed }

class MailHistoryPage extends ConsumerStatefulWidget {
  const MailHistoryPage({super.key});

  @override
  ConsumerState<MailHistoryPage> createState() => _MailHistoryPageState();
}

class _MailHistoryPageState extends ConsumerState<MailHistoryPage> {
  final _searchCtrl = TextEditingController();
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reuse(MailSendRecord row, {bool includeFiles = true}) {
    HapticFeedback.selectionClick();
    ref.read(mailReuseProvider.notifier).state = MailReuseRequest(
      toEmail: row.toEmail.trim(),
      attachments: includeFiles ? row.attachments : const [],
    );
    DefaultTabController.of(context).animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mailSendsProvider);
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.mailAccent(scheme);
    final me = ref.watch(authControllerProvider)?.id;
    final timeFmt = DateFormat('HH:mm');

    return async.when(
      loading: () => const AppLoading(message: '보낸 메일을 불러오는 중…'),
      error: (e, _) => AppEmpty(
        icon: Icons.cloud_off_rounded,
        message: '보낸 메일을 불러오지 못했습니다.',
        detail: '$e',
        actionLabel: '다시 시도',
        onAction: () => ref.invalidate(mailSendsProvider),
      ),
      data: (rows) {
        final q = _searchCtrl.text.trim().toLowerCase();
        final filtered = rows.where((r) {
          if (_filter == _HistoryFilter.mine &&
              me != null &&
              me.isNotEmpty &&
              r.senderUserId != me) {
            return false;
          }
          if (_filter == _HistoryFilter.failed && !r.isFailed) return false;
          if (q.isEmpty) return true;
          final atts = r.attachments.map((a) => a.name.toLowerCase()).join(' ');
          return r.toEmail.toLowerCase().contains(q) ||
              (r.senderUserName ?? '').toLowerCase().contains(q) ||
              r.subject.toLowerCase().contains(q) ||
              atts.contains(q) ||
              (r.body ?? '').toLowerCase().contains(q);
        }).toList();

        final sections = <String, List<MailSendRecord>>{};
        final now = DateTime.now();
        for (final r in filtered) {
          final label = mailHistoryDayLabel(r.sortAt.toLocal(), now);
          sections.putIfAbsent(label, () => []).add(r);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '받는 사람 · 파일 · 담당자',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _FilterChip(
                        label: '내 발송',
                        selected: _filter == _HistoryFilter.mine,
                        onTap: () =>
                            setState(() => _filter = _HistoryFilter.mine),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: '전체',
                        selected: _filter == _HistoryFilter.all,
                        onTap: () =>
                            setState(() => _filter = _HistoryFilter.all),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: '실패',
                        selected: _filter == _HistoryFilter.failed,
                        onTap: () =>
                            setState(() => _filter = _HistoryFilter.failed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const AppEmpty(message: '보낸 메일이 없습니다.')
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(mailSendsProvider);
                        await ref.read(mailSendsProvider.future);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: sections.length,
                        itemBuilder: (context, sectionIndex) {
                          final label = sections.keys.elementAt(sectionIndex);
                          final list = sections[label]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  top: sectionIndex == 0 ? 4 : 16,
                                  bottom: 8,
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              for (final r in list)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _HistoryCard(
                                    row: r,
                                    query: _searchCtrl.text,
                                    accent: accent,
                                    timeLabel: timeFmt.format(
                                      r.sortAt.toLocal(),
                                    ),
                                    onOpen: () => _showDetail(r),
                                    onReuse: () => _reuse(r),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showDetail(MailSendRecord row) {
    final fmt = DateFormat('yyyy.MM.dd HH:mm');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final accent = AppTokens.mailAccent(scheme);
        final maxH = MediaQuery.sizeOf(ctx).height * 0.86;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    Text(
                      row.toEmail,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${row.senderUserName ?? '미지정'} · ${fmt.format(row.sortAt.toLocal())}'
                      '${row.isFailed ? ' · 실패' : ''}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    if (row.errorMessage != null &&
                        row.errorMessage!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          row.errorMessage!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    if (row.attachments.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        '첨부 ${row.attachments.length}개',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      for (final a in row.attachments)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(
                            Icons.attach_file_rounded,
                            color: accent,
                          ),
                          title: Text(a.name),
                          onTap: a.url.isEmpty
                              ? null
                              : () => launchUrl(
                                  Uri.parse(a.url),
                                  mode: LaunchMode.externalApplication,
                                ),
                        ),
                    ],
                    if ((row.body ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '메일 내용',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(row.body!, style: const TextStyle(height: 1.45)),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _reuse(row);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('이대로 다시 보내기'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _reuse(row, includeFiles: false);
                        },
                        child: const Text('이 주소만 다시'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.row,
    required this.query,
    required this.accent,
    required this.timeLabel,
    required this.onOpen,
    required this.onReuse,
  });

  final MailSendRecord row;
  final String query;
  final Color accent;
  final String timeLabel;
  final VoidCallback onOpen;
  final VoidCallback onReuse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fileLine = row.attachments.map((a) => a.name).join(', ');
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: row.isFailed
                      ? scheme.error
                      : (row.isSuccess ? accent : scheme.outline),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchHighlightText(
                      text: row.toEmail,
                      query: query,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (fileLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        fileLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      '$timeLabel · ${row.senderUserName ?? '미지정'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onReuse, child: const Text('다시')),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.mailAccent(scheme);
    return Material(
      color: selected ? accent.withValues(alpha: 0.16) : scheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? accent.withValues(alpha: 0.45)
              : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? accent : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
