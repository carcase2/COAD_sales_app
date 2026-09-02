import 'dart:async';

import 'package:coad_customer_calls/core/utils/business_card_permissions.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_fill_sheet.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_export.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price_lookup_sheet.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price_photo.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 고객지원팀 전용 견적서. 영업 셔터 견적서 작성과 별개.
class SupportQuoteWriterScreen extends ConsumerStatefulWidget {
  const SupportQuoteWriterScreen({
    super.key,
    this.site,
    this.callLogId,
    this.startNew = false,
    this.openDoc,
  });

  final SupportSiteSample? site;
  final String? callLogId;
  final bool startNew;
  final SupportQuoteDocument? openDoc;

  @override
  ConsumerState<SupportQuoteWriterScreen> createState() =>
      _SupportQuoteWriterScreenState();
}

class _SupportQuoteWriterScreenState
    extends ConsumerState<SupportQuoteWriterScreen> {
  final _queryCtrl = TextEditingController();
  late SupportQuoteStore _store;
  List<SupportQuoteDocument> _items = const [];
  String _query = '';
  final _won = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _store = SupportQuoteStore(ref.read(appDependenciesProvider).prefs);
    _items = _store.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reload());
      if (widget.openDoc != null) {
        unawaited(_edit(existing: widget.openDoc));
      } else if (widget.startNew) {
        unawaited(_edit());
      }
    });
  }

  Future<void> _reload() async {
    try {
      final remote = await ref.read(supportAsQuoteRepositoryProvider).list();
      if (!mounted) return;
      await _persist(remote, remoteOnly: true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<SupportQuoteDocument> get _visible {
    var rows = _items.where((e) => supportQuoteMatches(e, _query));
    final site = widget.site;
    if (site != null) {
      rows = rows.where((e) => supportQuoteBelongsToSample(e, site));
    }
    return rows.toList();
  }

  Future<void> _persist(
    List<SupportQuoteDocument> next, {
    bool remoteOnly = false,
  }) async {
    setState(() => _items = next);
    await _store.save(next);
    if (remoteOnly) return;
  }

  Future<void> _edit({SupportQuoteDocument? existing}) async {
    final saved = await Navigator.of(context).push<SupportQuoteDocument>(
      MaterialPageRoute(
        builder: (_) => _SupportQuoteEditorPage(
          existing: existing,
          site: widget.site,
          callLogId: widget.callLogId,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    SupportQuoteDocument stored = saved;
    try {
      stored = await ref.read(supportAsQuoteRepositoryProvider).upsert(saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
      }
    }
    final next = [..._items];
    final i = next.indexWhere((e) => e.id == stored.id);
    if (i >= 0) {
      next[i] = stored;
    } else {
      next.insert(0, stored);
    }
    await _persist(next);
    if (!mounted) return;
    final sent = await showSupportQuoteExportSheet(context, doc: stored);
    if (sent == true && mounted) {
      final marked = stored.copyWith(sentYmd: todayYmdSeoul());
      try {
        await ref.read(supportAsQuoteRepositoryProvider).upsert(marked);
      } catch (_) {}
      final markedList = [..._items];
      final mi = markedList.indexWhere((e) => e.id == marked.id);
      if (mi >= 0) markedList[mi] = marked;
      await _persist(markedList);
    }
  }

  Future<void> _delete(SupportQuoteDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('견적서 삭제'),
        content: Text('${doc.customerName} 견적서를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(supportAsQuoteRepositoryProvider).delete(doc.id);
    } catch (_) {}
    await _persist(_items.where((e) => e.id != doc.id).toList());
  }

  Future<void> _openSite(SupportQuoteSiteGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SupportQuoteWriterScreen(
          site: group.toSiteSample(),
          callLogId: widget.callLogId,
        ),
      ),
    );
    if (mounted) unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final site = widget.site;
    final rows = _visible;
    final groups = site == null ? supportQuoteSiteGroups(rows) : const <SupportQuoteSiteGroup>[];
    final title = site == null ? 'A/S 견적서' : '${site.name} 견적서';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.edit_document),
        label: const Text('견적서 작성'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: site == null
                  ? '현장 · 고객 · 전화 · 품목 검색'
                  : '이 현장 견적 검색',
              leading: const Icon(Icons.search_rounded, size: 20),
              onChanged: (v) => setState(() => _query = v),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              ),
            ),
          ),
          if (site != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '이 현장 견적 ${rows.length}건',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Expanded(
            child: rows.isEmpty
                ? AppEmpty(
                    icon: Icons.request_quote_outlined,
                    message: _query.trim().isEmpty
                        ? (site == null
                              ? '작성한 A/S 견적서가 없습니다.'
                              : '이 현장 견적서가 없습니다.')
                        : '검색 결과가 없습니다.',
                    detail: _query.trim().isEmpty
                        ? '저장하면 이 현장 목록에서 다시 열어 확인할 수 있습니다.'
                        : null,
                    actionLabel: _query.trim().isEmpty ? '견적서 작성' : null,
                    onAction: _query.trim().isEmpty ? () => _edit() : null,
                  )
                : site == null
                ? ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final group = groups[i];
                      final latest = group.quotes.first;
                      return Material(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.42,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          title: Text(
                            group.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [
                              '${group.quotes.length}건',
                              if (latest.ymd.trim().isNotEmpty)
                                '최근 ${latest.ymd}',
                              if (group.phone.trim().isNotEmpty) group.phone,
                            ].join(' · '),
                          ),
                          trailing: Text(
                            group.total <= 0
                                ? '-'
                                : '${_won.format(group.total)}원',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                          onTap: () => _openSite(group),
                        ),
                      );
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final doc = rows[i];
                      return Material(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.42,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          title: Text(
                            [
                              if (doc.quoteNo.trim().isNotEmpty)
                                doc.quoteNo.trim(),
                              doc.ymd,
                            ].join(' · '),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(supportQuoteHistoryLine(doc)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 96),
                                child: Text(
                                  doc.total <= 0
                                      ? '-'
                                      : '${_won.format(doc.total)}원',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: accent,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '이미지 · PDF · 이메일',
                                icon: const Icon(Icons.ios_share_rounded),
                                onPressed: () => showSupportQuoteExportSheet(
                                  context,
                                  doc: doc,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _edit(existing: doc),
                          onLongPress: () => _delete(doc),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupportQuoteEditorPage extends ConsumerStatefulWidget {
  const _SupportQuoteEditorPage({this.existing, this.site, this.callLogId});

  final SupportQuoteDocument? existing;
  final SupportSiteSample? site;
  final String? callLogId;

  @override
  ConsumerState<_SupportQuoteEditorPage> createState() =>
      _SupportQuoteEditorPageState();
}

class _SupportQuoteEditorPageState
    extends ConsumerState<_SupportQuoteEditorPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _siteCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _workCtrl;
  late String _ymd;
  late String _quoteNo;
  List<SupportQuoteLine> _lines = [];
  final _won = NumberFormat('#,###');
  Timer? _nameLookupDebounce;
  bool _nameLookupBusy = false;
  bool _applyingName = false;
  bool _fromCard = false;
  String? _lookedUpName;
  BusinessCard? _matchedCard;
  List<BusinessCardFill> _nameFillChoices = const [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final site = widget.site;
    _nameCtrl = TextEditingController(
      text: e?.customerName ?? site?.name ?? '',
    );
    _phoneCtrl = TextEditingController(text: e?.phone ?? site?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _siteCtrl = TextEditingController(text: e?.site ?? site?.name ?? '');
    _addressCtrl = TextEditingController(
      text: e?.address ?? site?.address ?? '',
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _workCtrl = TextEditingController(
      text: e?.workName ?? (site == null ? '' : 'A/S 공사'),
    );
    _ymd = (e?.ymd ?? '').trim().isNotEmpty ? e!.ymd : todayYmdSeoul();
    _quoteNo = e?.quoteNo ?? '';
    _lines = List.of(e?.lines ?? const []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_quoteNo.trim().isEmpty) unawaited(_ensureQuoteNo());
      _scheduleNameLookup(_nameCtrl.text);
    });
  }

  @override
  void dispose() {
    _nameLookupDebounce?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _siteCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _workCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureQuoteNo() async {
    try {
      final no = await ref.read(supportAsQuoteRepositoryProvider).nextQuoteNo();
      if (!mounted || _quoteNo.trim().isNotEmpty) return;
      setState(() => _quoteNo = no);
    } catch (_) {}
  }

  int get _total => _lines.fold(0, (sum, e) => sum + e.amount);

  void _setCtrl(TextEditingController ctrl, String value) {
    ctrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _onNameChanged(String value) {
    if (_applyingName) return;
    _fromCard = false;
    _scheduleNameLookup(value);
  }

  void _scheduleNameLookup(String value) {
    _nameLookupDebounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      if (_matchedCard != null || _nameLookupBusy) {
        setState(() {
          _matchedCard = null;
          _nameLookupBusy = false;
          _lookedUpName = null;
          _nameFillChoices = const [];
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
      final choices = businessCardFillChoices(name, found);
      setState(() {
        _nameFillChoices = choices;
        _nameLookupBusy = false;
      });
      if (choices.isEmpty) {
        setState(() => _matchedCard = null);
        return;
      }
      final pick = await resolveBusinessCardFill(
        context,
        query: name,
        found: found,
      );
      if (!mounted || _lookedUpName != name) return;
      if (pick == null) {
        setState(() => _matchedCard = null);
        return;
      }
      _applyFillFromCard(pick);
    } catch (_) {
      if (!mounted || _lookedUpName != name) return;
      setState(() {
        _matchedCard = null;
        _nameLookupBusy = false;
      });
    }
  }

  void _applyFillFromCard(BusinessCardFill pick) {
    setState(() {
      _matchedCard = pick.card;
      _fromCard = true;
    });
    _applyingName = true;
    final cardName = pick.card.name.trim();
    if (cardName.isNotEmpty) _setCtrl(_nameCtrl, cardName);
    if (pick.phone.isNotEmpty) {
      _setCtrl(_phoneCtrl, formatKoreanPhoneHyphenated(pick.phone));
    }
    if (pick.card.email.trim().isNotEmpty) {
      _setCtrl(_emailCtrl, pick.card.email.trim());
    }
    if (_addressCtrl.text.trim().isEmpty &&
        pick.card.address.trim().isNotEmpty) {
      _setCtrl(_addressCtrl, pick.card.address.trim());
    }
    if (_siteCtrl.text.trim().isEmpty && pick.card.company.trim().isNotEmpty) {
      _setCtrl(_siteCtrl, pick.card.company.trim());
    }
    _applyingName = false;
  }

  Future<void> _repickFromNameMatches() async {
    if (_nameFillChoices.length < 2) return;
    final pick = await showBusinessCardFillSheet(
      context,
      choices: _nameFillChoices,
    );
    if (!mounted || pick == null) return;
    _applyFillFromCard(pick);
  }

  Future<void> _pickYmd() async {
    final initial = DateTime.tryParse(_ymd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _ymd =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _addFromPriceList() async {
    await showSupportUnitPriceLookupSheet(
      context,
      insertLabel: '넣기',
      closeOnInsert: false,
      quoteTotal: () => _total,
      onInsert: (item) {
        if (!mounted) return;
        setState(
          () => _lines = [..._lines, SupportQuoteLine.fromUnitPrice(item)],
        );
      },
    );
  }

  Future<void> _addLine() async {
    final line = await showModalBottomSheet<SupportQuoteLine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _SupportQuoteLineSheet(),
    );
    if (line == null || !mounted) return;
    setState(() => _lines = [..._lines, line]);
  }

  Future<void> _editLine(int index) async {
    final line = await showModalBottomSheet<SupportQuoteLine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _SupportQuoteLineSheet(existing: _lines[index]),
    );
    if (line == null || !mounted) return;
    setState(() {
      final next = [..._lines];
      next[index] = line;
      _lines = next;
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('고객명을 입력해 주세요.')));
      return;
    }
    final user = ref.read(authControllerProvider);
    Navigator.of(context).pop(
      SupportQuoteDocument(
        id:
            widget.existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        customerName: name,
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        site: _siteCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        workName: _workCtrl.text.trim(),
        quoteNo: _quoteNo.trim(),
        ymd: _ymd,
        lines: List.of(_lines),
        note: _noteCtrl.text.trim(),
        createdBy: user?.name ?? user?.id,
        callLogId: widget.callLogId ?? widget.existing?.callLogId,
        createdAt:
            widget.existing?.createdAt ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '견적서 작성' : '견적서 수정'),
        actions: [TextButton(onPressed: _save, child: const Text('저장하고 보내기'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: '고객명',
              hintText: '이름 넣으면 명함에서 전화·이메일을 채웁니다',
              filled: true,
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
                  : Icon(Icons.contact_page_rounded, color: accent),
            ),
            textInputAction: TextInputAction.next,
            onChanged: _onNameChanged,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: '전화',
              filled: true,
              helperText: _fromCard ? '명함에서 자동 입력됨' : null,
            ),
            onChanged: (value) {
              final formatted = formatKoreanPhoneHyphenated(value);
              if (formatted != value) _setCtrl(_phoneCtrl, formatted);
            },
          ),
          if (_matchedCard != null) ...[
            const SizedBox(height: 8),
            Material(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: Icon(Icons.contact_page_rounded, color: accent),
                title: Text(
                  '명함 있음 · ${_matchedCard!.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  [
                    if (_fromCard) '전화·이메일 자동 입력',
                    if (_matchedCard!.company.trim().isNotEmpty)
                      _matchedCard!.company.trim(),
                  ].join(' · '),
                ),
                trailing: _nameFillChoices.length > 1
                    ? TextButton(
                        onPressed: _repickFromNameMatches,
                        child: const Text('번호 바꾸기'),
                      )
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '이메일',
              hintText: '견적서 받을 주소 (선택)',
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _siteCtrl,
            decoration: const InputDecoration(labelText: '현장명', filled: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _workCtrl,
            decoration: const InputDecoration(
              labelText: '공사명',
              hintText: '예: 스피드도어 A/S 공사',
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: '주소', filled: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('견적번호'),
            subtitle: Text(_quoteNo.trim().isEmpty ? '저장 시 자동 부여' : _quoteNo),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('견적일'),
            subtitle: Text(_ymd),
            trailing: const Icon(Icons.event_rounded),
            onTap: _pickYmd,
          ),
          const SizedBox(height: 8),
          Text(
            '품목',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 0,
            children: [
              TextButton.icon(
                onPressed: _addFromPriceList,
                icon: const Icon(Icons.grid_on_rounded),
                label: const Text('단가표에서 넣기'),
              ),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add_rounded),
                label: const Text('직접 입력'),
              ),
            ],
          ),
          if (_lines.isEmpty)
            Text(
              '부품·인건비는 A/S 단가표에서 고르고, 장비대는 직접 넣을 수 있습니다.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            for (var i = 0; i < _lines.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _lines[i].name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  [
                    supportQuoteKindLabel(_lines[i].kind),
                    if (_lines[i].spec.trim().isNotEmpty) _lines[i].spec.trim(),
                    if (_lines[i].unit.trim().isNotEmpty) _lines[i].unit.trim(),
                    '수량 ${_lines[i].qty}',
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        _lines[i].amount <= 0
                            ? '-'
                            : '${_won.format(_lines[i].amount)}원',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        final next = [..._lines]..removeAt(i);
                        _lines = next;
                      }),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                onTap: () => _editLine(i),
              ),
          const Divider(height: 28),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '합계 ${_total <= 0 ? '-' : '${_won.format(_total)}원'}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '비고', filled: true),
          ),
        ],
      ),
    );
  }
}

class _SupportQuoteLineSheet extends ConsumerStatefulWidget {
  const _SupportQuoteLineSheet({this.existing});

  final SupportQuoteLine? existing;

  @override
  ConsumerState<_SupportQuoteLineSheet> createState() =>
      _SupportQuoteLineSheetState();
}

class _SupportQuoteLineSheetState
    extends ConsumerState<_SupportQuoteLineSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _specCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late String _kind;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _specCtrl = TextEditingController(text: e?.spec ?? '');
    _unitCtrl = TextEditingController(text: e?.unit ?? '');
    _qtyCtrl = TextEditingController(text: '${e?.qty ?? 1}');
    _priceCtrl = TextEditingController(
      text: e?.unitPrice == null ? '' : '${e!.unitPrice}',
    );
    _kind = e?.kind ?? kSupportQuoteKindPart;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specCtrl.dispose();
    _unitCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromPriceList() async {
    List<SupportUnitPriceItem> prices;
    try {
      prices = await ref.read(supportUnitPriceRepositoryProvider).list();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
      return;
    }
    if (!mounted) return;
    if (prices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A/S 단가표에 품목이 없습니다. 먼저 단가를 입력해 주세요.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<SupportUnitPriceItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var q = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final rows = prices
                .where((e) => supportUnitPriceMatches(e, q))
                .toList();
            return SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '단가표 검색',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) => setLocal(() => q = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final item = rows[i];
                        return ListTile(
                          leading: SupportUnitPricePhoto(
                            url: item.primaryImageUrl,
                            width: 48,
                            height: 48,
                          ),
                          title: SearchHighlightText(
                            text: item.name,
                            query: q,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: SearchHighlightText(
                            text: [
                              if (supportUnitPriceSubtitle(item).isNotEmpty)
                                supportUnitPriceSubtitle(item),
                              if (item.price != null) '${item.price}원',
                            ].join(' · '),
                            query: q,
                          ),
                          onTap: () => Navigator.pop(ctx, item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    final line = SupportQuoteLine.fromUnitPrice(picked);
    setState(() {
      _nameCtrl.text = line.name;
      if (line.spec.trim().isNotEmpty) _specCtrl.text = line.spec;
      if (line.unit.trim().isNotEmpty) _unitCtrl.text = line.unit;
      if (line.unitPrice != null) _priceCtrl.text = '${line.unitPrice}';
      _kind = line.kind;
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('품명을 입력해 주세요.')));
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final price = int.tryParse(_priceCtrl.text.replaceAll(',', '').trim());
    Navigator.pop(
      context,
      SupportQuoteLine(
        name: name,
        spec: _specCtrl.text.trim(),
        unit: _unitCtrl.text.trim(),
        qty: qty <= 0 ? 1 : qty,
        unitPrice: (price ?? 0) > 0 ? price : null,
        kind: _kind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '품목',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickFromPriceList,
              icon: const Icon(Icons.grid_on_rounded),
              label: const Text('A/S 단가표에서 고르기'),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in kSupportQuoteKindOrder)
                FilterChip(
                  label: Text(supportQuoteKindLabel(kind)),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: '품명', filled: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _specCtrl,
            decoration: const InputDecoration(labelText: '규격', filled: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _unitCtrl,
                  decoration: const InputDecoration(
                    labelText: '단위',
                    hintText: 'EA / SET / 식',
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '수량',
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '단가',
                    filled: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _save, child: const Text('확인')),
          ),
        ],
      ),
    );
  }
}
