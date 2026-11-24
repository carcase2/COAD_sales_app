import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:coad_customer_calls/data/auth_controller.dart';
import 'package:coad_customer_calls/features/contract/contract_request_model.dart';
import 'package:coad_customer_calls/features/contract/contract_request_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 계약서 작성 요청 목록 (영업 → 총무). 인트라넷 발급요청 '계약서' 탭과 같은 데이터.
class ContractRequestPage extends ConsumerStatefulWidget {
  const ContractRequestPage({super.key, this.openCreate = false});

  /// 열자마자 새 요청 작성 화면을 띄운다.
  final bool openCreate;

  @override
  ConsumerState<ContractRequestPage> createState() =>
      _ContractRequestPageState();
}

class _ContractRequestPageState extends ConsumerState<ContractRequestPage> {
  ContractViewer? _viewer;
  List<ContractRequest> _rows = const [];
  bool _loading = true;
  String? _error;
  String _filter = '요청';
  String _query = '';

  String get _userId => ref.read(authControllerProvider)?.id ?? '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    if (widget.openCreate) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openForm()),
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref.read(contractRequestRepositoryProvider).list(_userId);
      if (!mounted) return;
      setState(() {
        _viewer = r.viewer;
        _rows = r.requests;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    }
  }

  static String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _replace(ContractRequest r) {
    setState(() {
      final i = _rows.indexWhere((x) => x.id == r.id);
      _rows = i < 0 ? [r, ..._rows] : ([..._rows]..[i] = r);
    });
  }

  Future<void> _openForm([ContractRequest? editing]) async {
    final saved = await Navigator.of(context).push<ContractRequest>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ContractRequestFormPage(editing: editing),
      ),
    );
    if (saved == null) return;
    _replace(saved);
    if (editing == null) setState(() => _filter = '요청');
    _snack(editing == null ? '계약서 작성을 요청했습니다.' : '계약서요청을 저장했습니다.');
  }

  Future<void> _act(ContractRequest r, String action) async {
    final repo = ref.read(contractRequestRepositoryProvider);
    try {
      switch (action) {
        case 'complete':
          final note = await _askNote(r);
          if (note == null) return;
          _replace(await repo.complete(_userId, r.id, note));
          _snack('완료로 바꿨습니다.');
        case 'cancel':
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('요청을 취소할까요?'),
              content: Text('${r.requestNo} ${r.siteName}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('아니요'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('요청 취소'),
                ),
              ],
            ),
          );
          if (ok != true) return;
          _replace(await repo.cancel(_userId, r.id));
          _snack('요청을 취소했습니다.');
        case 'reopen':
          _replace(await repo.reopen(_userId, r.id));
          _snack('요청 상태로 되돌렸습니다.');
      }
    } catch (e) {
      _snack(_msg(e));
    }
  }

  Future<String?> _askNote(ContractRequest r) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r.sendMethod == '메일' ? '메일 발송 완료' : '직접발송 완료'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '완료 메모 (선택) — 예: 등기 발송, 송장번호',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('완료'),
          ),
        ],
      ),
    );
  }

  void _openDetail(ContractRequest r) {
    final viewer = _viewer;
    final mine = r.requesterUserId == _userId;
    final canHandle = viewer?.canHandle ?? false;
    final open = r.status == '요청';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        void run(String a) {
          Navigator.pop(ctx);
          if (a == 'edit') {
            unawaited(_openForm(r));
          } else if (a == 'document') {
            unawaited(_document(r));
          } else {
            unawaited(_act(r, a));
          }
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Row(
                children: [
                  _StatusChip(status: r.status),
                  const SizedBox(width: 8),
                  Text(r.requestNo, style: Theme.of(ctx).textTheme.labelLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: '글 복사',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: contractRequestText(r)),
                      );
                      _snack('요청 내용을 복사했습니다.');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                r.siteName,
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _kv(
                '발주자',
                [
                  '${r.clientName}${r.clientType == '개인' ? ' (개인)' : ''}',
                  if (r.clientType != '개인' && r.clientBizNo.isNotEmpty)
                    r.clientBizNo,
                  if (r.clientType != '개인' && r.clientRep.isNotEmpty)
                    '대표 ${r.clientRep}',
                  if (r.clientType == '개인' && r.clientPhone.isNotEmpty)
                    r.clientPhone,
                ].where((e) => e.trim().isNotEmpty).join(' · '),
              ),
              if (r.clientAddress.isNotEmpty) _kv('발주자 주소', r.clientAddress),
              _kv(
                '수급인',
                contractContractors
                        .where((c) => c.value == r.contractor)
                        .firstOrNull
                        ?.label ??
                    r.contractor,
              ),
              _kv('공사장소', r.siteAddress.isEmpty ? '주소 미입력' : r.siteAddress),
              _kv('품목/수량', r.items),
              _kv('공사기간', contractPeriodText(r)),
              _kv(
                '계약금액',
                r.supplyAmount == null
                    ? ''
                    : '공급가 ${formatWon(r.supplyAmount)}',
              ),
              _kv('선급금', _rateText(r.advanceRate, dotDate(r.advancePayWhen))),
              _kv('기성금', _rateText(r.progressRate, r.progressPayWhen)),
              _kv('선급금 증권', r.advanceBond ? '필요' : '없음'),
              _kv(
                '계약이행보증금',
                r.performanceBond
                    ? '필요${r.performanceBondRate != null ? ' ${r.performanceBondRate}%' : ''}'
                    : '없음',
              ),
              _kv(
                '하자보증금',
                r.defectBond
                    ? '필요${r.defectBondRate != null ? ' ${r.defectBondRate}%' : ''}'
                    : '없음',
              ),
              _kv('무상보증기간', r.warranty),
              _kv(
                '보내는 방법',
                r.sendMethod == '메일' && r.mailTo.isNotEmpty
                    ? '메일 (${r.mailTo})'
                    : r.sendMethod,
              ),
              _kv('통장사본', r.withBankbook ? '함께 보내기' : '안 보냄'),
              _kv(
                '요청자',
                '${r.requesterName}${r.createdAt != null ? ' · ${_dt(r.createdAt!)}' : ''}',
              ),
              if (r.note.isNotEmpty) _kv('메모', r.note),
              for (final k in contractAttachmentKinds)
                _files(k.label, [
                  for (final f in r.files)
                    if (f.kind == k.kind) f,
                ], r),
              if (r.status == '완료')
                _kv(
                  '처리',
                  [
                    r.handledBy,
                    if (r.handledAt != null) _dt(r.handledAt!),
                    r.handledNote,
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (open && canHandle)
                    FilledButton.icon(
                      onPressed: () => run('complete'),
                      icon: const Icon(Icons.task_alt_rounded),
                      label: Text(
                        r.sendMethod == '메일' ? '메일 발송 완료' : '직접발송 완료',
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => run('document'),
                    icon: const Icon(Icons.table_view_rounded),
                    label: const Text('계약서 엑셀'),
                  ),
                  if (open && (mine || canHandle))
                    OutlinedButton.icon(
                      onPressed: () => run('edit'),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('고치기'),
                    ),
                  if (open && (mine || canHandle))
                    OutlinedButton.icon(
                      onPressed: () => run('cancel'),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('요청 취소'),
                    ),
                  if ((r.status == '완료' && canHandle) ||
                      (r.status == '취소' && (mine || canHandle)))
                    OutlinedButton.icon(
                      onPressed: () => run('reopen'),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('요청으로 되돌리기'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _document(ContractRequest r) async {
    _snack('계약서 엑셀을 만드는 중…');
    try {
      final f = await ref
          .read(contractRequestRepositoryProvider)
          .downloadDocument(_userId, r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path)], subject: f.uri.pathSegments.last),
      );
    } catch (e) {
      _snack(_msg(e));
    }
  }

  Future<void> _openFile(ContractRequest r, ContractFile f) async {
    try {
      final url = await ref
          .read(contractRequestRepositoryProvider)
          .fileUrl(_userId, r.id, f.id);
      if (url.isEmpty) throw Exception('파일 주소를 만들지 못했습니다.');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack(_msg(e));
    }
  }

  Widget _files(String label, List<ContractFile> files, ContractRequest r) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: files.isEmpty
                  ? const Text('-')
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final f in files)
                          ActionChip(
                            avatar: Icon(
                              f.isImage
                                  ? Icons.image_outlined
                                  : Icons.picture_as_pdf_outlined,
                              size: 18,
                            ),
                            label: Text(
                              f.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => unawaited(_openFile(r, f)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );

  static String _rateText(int? rate, String when) {
    if (rate == null && when.isEmpty) return '';
    return '${rate ?? '-'}%${when.isNotEmpty ? ' · $when' : ' · 시기 미정'}';
  }

  static String _dt(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            k,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: SelectableText(v.trim().isEmpty ? '-' : v)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final shown = _rows.where((r) => r.matches(_filter, _query)).toList();
    final counts = {
      for (final f in contractListFilters)
        f: _rows.where((r) => r.matches(f, '')).length,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('계약서 작성 요청'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_openForm()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('요청하기'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: '현장명·품목·요청자 검색',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final f in contractListFilters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('$f ${counts[f]}'),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading && _rows.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _rows.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                      ],
                    )
                  : shown.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _rows.isEmpty
                                ? '아직 계약서요청이 없습니다.\n아래 "요청하기"로 요청하세요.'
                                : '조건에 맞는 요청이 없습니다.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _RequestCard(
                        r: shown[i],
                        onTap: () => _openDetail(shown[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      '완료' => (Colors.green.withValues(alpha: 0.15), Colors.green.shade800),
      '취소' => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      _ => (Colors.orange.withValues(alpha: 0.18), Colors.orange.shade900),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.r, required this.onTap});

  final ContractRequest r;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sub = [
      if (r.clientName.isNotEmpty) r.clientName,
      if (r.items.isNotEmpty) r.items,
      if (r.supplyAmount != null) formatWon(r.supplyAmount),
      if (contractPeriodText(r).isNotEmpty) contractPeriodText(r),
    ].join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(status: r.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.siteName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(r.requestNo, style: t.labelSmall),
                ],
              ),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${r.requesterName} · ${r.sendMethod == '메일' ? '메일' : '직접'}${r.withBankbook ? ' · 통장사본' : ''}',
                style: t.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아직 서버에 올리지 않은 첨부 (저장할 때 올린다)
class _PendingFile {
  _PendingFile(this.kind, this.file, this.contentType);
  final String kind;
  final File file;
  final String contentType;
  String get name => file.uri.pathSegments.last;
  bool get isImage => contentType.startsWith('image/');
}

String _contentTypeOf(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' || 'heif' => 'image/heic',
    _ => 'image/jpeg',
  };
}

/// 새 요청 / 고치기 화면. 저장하면 서버가 돌려준 요청을 pop 한다.
class ContractRequestFormPage extends ConsumerStatefulWidget {
  const ContractRequestFormPage({super.key, this.editing});

  final ContractRequest? editing;

  @override
  ConsumerState<ContractRequestFormPage> createState() =>
      _ContractRequestFormPageState();
}

class _ContractRequestFormPageState
    extends ConsumerState<ContractRequestFormPage> {
  late ContractFields _f;
  final _c = <String, TextEditingController>{};
  bool _saving = false;
  bool _dirty = false;
  final _pending = <_PendingFile>[];
  final _removed = <String>{};
  int _recognizing = 0;
  List<CatalogCategory>? _catalog;

  String get _uid => ref.read(authControllerProvider)?.id ?? '';
  List<ContractFile> get _existing => [
    for (final f in widget.editing?.files ?? const <ContractFile>[])
      if (!_removed.contains(f.id)) f,
  ];

  TextEditingController _ctl(String key) =>
      _c.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    _f = widget.editing?.copy() ?? ContractFields();
    _syncControllers();
  }

  void _syncControllers() {
    _ctl('cname').text = _f.clientName;
    _ctl('bizno').text = _f.clientBizNo;
    _ctl('crep').text = _f.clientRep;
    _ctl('cphone').text = _f.clientPhone;
    _ctl('caddr').text = _f.clientAddress;
    _ctl('site').text = _f.siteName;
    _ctl('addr').text = _f.siteAddress;
    _ctl('items').text = _f.items;
    _ctl('amount').text = _f.supplyAmount == null ? '' : '${_f.supplyAmount}';
    _ctl('adv').text = _f.advanceRate == null ? '' : '${_f.advanceRate}';
    _ctl('prog').text = _f.progressRate == null ? '' : '${_f.progressRate}';
    _ctl('progWhen').text = _f.progressPayWhen;
    _ctl('perfRate').text = _f.performanceBondRate == null
        ? ''
        : '${_f.performanceBondRate}';
    _ctl('defRate').text = _f.defectBondRate == null
        ? ''
        : '${_f.defectBondRate}';
    _ctl('warranty').text = _f.warranty;
    _ctl('mail').text = _f.mailTo;
    _ctl('note').text = _f.note;
  }

  void _readControllers() {
    int? n(String k) =>
        int.tryParse(_ctl(k).text.replaceAll(RegExp(r'[,\s원%]'), ''));
    _f
      ..clientName = _ctl('cname').text
      ..clientBizNo = formatBizNo(_ctl('bizno').text)
      ..clientRep = _ctl('crep').text
      ..clientPhone = _ctl('cphone').text
      ..clientAddress = _ctl('caddr').text
      ..siteName = _ctl('site').text
      ..siteAddress = _ctl('addr').text
      ..items = _ctl('items').text
      ..supplyAmount = _ctl('amount').text.trim().isEmpty
          ? null
          : (n('amount') ?? parseWon(_ctl('amount').text) ?? -1)
      ..advanceRate = n('adv')
      ..progressRate = n('prog')
      ..progressPayWhen = _ctl('progWhen').text
      ..performanceBondRate = n('perfRate')
      ..defectBondRate = n('defRate')
      ..warranty = _ctl('warranty').text
      ..mailTo = _ctl('mail').text
      ..note = _ctl('note').text;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _paste() async {
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!mounted) return;
    final c = TextEditingController(text: clip.contains('계약') ? clip : '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('요청 글 붙여 넣기'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: c,
            maxLines: 12,
            minLines: 6,
            decoration: const InputDecoration(
              helperText: '단톡방에 올리던 [계약서 작성 요청] 글을 붙여 넣으면 칸을 채웁니다.',
              helperMaxLines: 2,
              hintText:
                  '[계약서 작성 요청]\n*현장명: ...\n*공사장소: ...\n*품목/ 수량: ...\n*공사기간: 26/12/1-26/12/12\n*계약금액: 공급가 550만원',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('칸 채우기'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    _readControllers();
    final hits = applyContractRequestText(_f, text);
    if (hits == 0) {
      _snack('읽을 수 있는 항목이 없습니다. 양식을 확인해 주세요.');
      return;
    }
    setState(() {
      _dirty = true;
      _syncControllers();
    });
    _snack('$hits개 항목을 채웠습니다.');
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<String?> _askDate(String? current, [String? fallback]) async {
    final d = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(current ?? '') ??
          DateTime.tryParse(fallback ?? '') ??
          DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    return d == null ? null : _ymd(d);
  }

  Future<void> _pickDate(bool start) async {
    final s = await _askDate(
      start ? _f.periodStart : _f.periodEnd,
      _f.periodStart,
    );
    if (s == null) return;
    setState(() {
      _dirty = true;
      if (start) {
        // 종료일이 시작일을 따라온다
        _f.periodEnd = followStart(_f.periodStart, _f.periodEnd, s);
        _f.periodStart = s;
      } else {
        _f.periodEnd = s;
      }
    });
  }

  Future<void> _pickAdvanceDate() async {
    final s = await _askDate(_f.advancePayWhen, _f.periodStart);
    if (s == null) return;
    setState(() {
      _dirty = true;
      _f.advancePayWhen = s;
    });
  }

  /* ---------- 품목: NEW MES 목록에서 고르기 ---------- */

  Future<void> _pickProduct() async {
    final catalog = _catalog ??= await ref
        .read(contractRequestRepositoryProvider)
        .catalog(_uid);
    if (!mounted) return;
    if (catalog.isEmpty) {
      _snack('제품 목록을 불러오지 못했습니다. 직접 입력해 주세요.');
      return;
    }
    final picked = await showModalBottomSheet<({String name, int qty})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ProductPicker(catalog: catalog),
    );
    if (picked == null) return;
    setState(() {
      _dirty = true;
      _ctl('items').text = addContractItem(
        _ctl('items').text,
        picked.name,
        picked.qty,
      );
    });
  }

  /* ---------- 첨부 + 자동 인식 ---------- */

  int _countOf(String kind) =>
      _existing.where((f) => f.kind == kind).length +
      _pending.where((p) => p.kind == kind).length;

  Future<void> _addFile(String kind) async {
    if (_countOf(kind) >= contractMaxFilesPerKind) {
      _snack(
        '${contractAttachmentLabel(kind)}은 $contractMaxFilesPerKind개까지 올릴 수 있습니다.',
      );
      return;
    }
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('사진 찍기'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 고르기'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('파일(PDF·사진) 고르기'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    String? path;
    try {
      if (source == 'file') {
        final r = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const [
            'pdf',
            'jpg',
            'jpeg',
            'png',
            'webp',
            'heic',
          ],
        );
        path = r?.files.single.path;
      } else {
        // 인식(5MB 상한)에도 쓰도록 긴 변 2000px 로 줄인다
        final x = await ImagePicker().pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 2000,
          maxHeight: 2000,
          imageQuality: 85,
        );
        path = x?.path;
      }
    } catch (e) {
      _snack('파일을 고르지 못했습니다: $e');
      return;
    }
    if (path == null || !mounted) return;
    final file = File(path);
    if (await file.length() > contractMaxFileBytes) {
      _snack('파일은 20MB 이하만 올릴 수 있습니다.');
      return;
    }
    final p = _PendingFile(kind, file, _contentTypeOf(path));
    setState(() {
      _dirty = true;
      _pending.add(p);
    });
    unawaited(_recognize(p));
  }

  /// 첨부한 사업자등록증·명함을 읽어 발주자 칸을 채운다
  Future<void> _recognize(_PendingFile p) async {
    final label = contractAttachmentLabel(p.kind);
    if (p.contentType == 'image/heic') return; // 서버 인식은 JPG·PNG·WEBP·PDF 만
    setState(() => _recognizing++);
    try {
      final doc = await ref
          .read(contractRequestRepositoryProvider)
          .recognize(_uid, p.kind, p.file, p.contentType);
      if (!mounted) return;
      _readControllers();
      final suggestions = contractSuggestions(doc, p.kind, _f);
      final fill = suggestions.where((s) => s.status == 'fill').toList();
      final differs = suggestions.where((s) => s.status == 'differs').toList();
      final contact = doc.docType == 'business_card' ? doc.contactLine : '';
      setState(() {
        _f.clientType = '기업';
        for (final s in fill) {
          setContractField(_f, s.key, s.value);
        }
        if (contact.isNotEmpty && !_f.note.contains(contact)) {
          _f.note = [
            _f.note,
            contact,
          ].where((e) => e.trim().isNotEmpty).join('\n');
        }
        _syncControllers();
      });
      if (doc.docType == 'other') {
        _snack('${p.name}: 사업자등록증이나 명함으로 보이지 않습니다. 내용을 확인해 주세요.');
      } else if (doc.docType == 'business_card' &&
          p.kind == 'business_license') {
        _snack('${p.name} 은 명함으로 보입니다. 첨부 칸을 확인해 주세요.');
      } else if (doc.docType == 'business_license' &&
          p.kind == 'business_card') {
        _snack('${p.name} 은 사업자등록증으로 보입니다. 첨부 칸을 확인해 주세요.');
      } else {
        final names = [
          ...fill.map((s) => s.label),
          if (contact.isNotEmpty) '담당자(메모)',
        ];
        if (names.isNotEmpty) {
          _snack('$label에서 ${names.join('·')}을(를) 채웠습니다. 맞는지 확인해 주세요.');
        } else if (differs.isEmpty) {
          _snack('$label을(를) 읽었지만 새로 채울 칸이 없습니다.');
        }
      }
      if (differs.isNotEmpty) await _reviewDiffers(label, differs);
    } catch (e) {
      _snack(
        '$label 자동 인식 실패 — 직접 입력해 주세요. (${e.toString().replaceFirst('Exception: ', '')})',
      );
    } finally {
      if (mounted) setState(() => _recognizing--);
    }
  }

  /// 이미 다른 값이 있는 칸은 사람이 고른다
  Future<void> _reviewDiffers(
    String from,
    List<ContractSuggestion> items,
  ) async {
    final pick = {for (final s in items) s.key: false};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('$from 인식 결과'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('입력된 값과 다릅니다. 바꿀 칸을 고르세요.'),
              for (final s in items)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: pick[s.key],
                  onChanged: (v) => setD(() => pick[s.key] = v ?? false),
                  title: Text(s.label),
                  subtitle: Text(
                    '${contractFieldValue(_f, s.key)}\n→ ${s.value}',
                  ),
                  isThreeLine: true,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('그대로 두기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('바꾸기'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    _readControllers();
    setState(() {
      for (final s in items) {
        if (pick[s.key] == true) setContractField(_f, s.key, s.value);
      }
      _dirty = true;
      _syncControllers();
    });
  }

  Future<void> _save() async {
    _readControllers();
    final err = validateContractFields(_f);
    if (err != null) {
      _snack(err);
      return;
    }
    final missing = missingContractAttachments({
      for (final k in contractAttachmentKinds) k.kind: _countOf(k.kind),
    });
    if (missing.isNotEmpty) {
      _snack('${missing.join(', ')}을 첨부해 주세요.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(contractRequestRepositoryProvider);
    final uid = _uid;
    ContractRequest saved;
    try {
      saved = widget.editing == null
          ? await repo.create(uid, _f)
          : await repo.update(uid, widget.editing!.id, _f);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    // 요청은 저장됐다. 첨부가 하나라도 실패하면 알리고 닫는다 (고치기에서 다시 올릴 수 있다)
    final failed = <String>[];
    for (final id in _removed) {
      try {
        saved = await repo.removeFile(uid, saved.id, id);
      } catch (_) {
        failed.add('삭제');
      }
    }
    for (final p in _pending) {
      try {
        saved = await repo.upload(uid, saved.id, p.kind, p.file, p.contentType);
      } catch (e) {
        failed.add(p.name);
      }
    }
    if (!mounted) return;
    if (failed.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('첨부 일부를 저장하지 못했습니다'),
          content: Text('요청은 저장됐습니다. 고치기에서 다시 첨부해 주세요.\n${failed.join(', ')}'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      if (!mounted) return;
    }
    Navigator.of(context).pop(saved);
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    TextInputType? type,
    int maxLines = 1,
    String? suffix,
    Widget? suffixIcon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _ctl(key),
      keyboardType: type,
      maxLines: maxLines,
      minLines: 1,
      onChanged: (_) => _dirty = true,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _yesNo(
    String label,
    bool value,
    ValueChanged<bool> on, {
    String? rateKey,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('없음')),
                ButtonSegment(value: true, label: Text('필요')),
              ],
              selected: {value},
              onSelectionChanged: (s) => setState(() {
                _dirty = true;
                on(s.first);
              }),
            ),
          ],
        ),
        if (value && rateKey != null) ...[
          const SizedBox(height: 8),
          _field(
            rateKey,
            '$label 비율 (선택)',
            type: TextInputType.number,
            suffix: '%',
          ),
        ],
      ],
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
  );

  Widget _attachments() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final k in contractAttachmentKinds)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${k.label} *',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => unawaited(_addFile(k.kind)),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('첨부'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in _existing.where((f) => f.kind == k.kind))
                      InputChip(
                        avatar: Icon(
                          f.isImage
                              ? Icons.image_outlined
                              : Icons.picture_as_pdf_outlined,
                          size: 18,
                        ),
                        label: Text(f.name, overflow: TextOverflow.ellipsis),
                        onDeleted: _saving
                            ? null
                            : () => setState(() {
                                _dirty = true;
                                _removed.add(f.id);
                              }),
                      ),
                    for (final p in _pending.where((p) => p.kind == k.kind))
                      InputChip(
                        avatar: Icon(
                          p.isImage
                              ? Icons.image_outlined
                              : Icons.picture_as_pdf_outlined,
                          size: 18,
                        ),
                        label: Text(
                          '${p.name} (새로)',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: _saving
                            ? null
                            : () => setState(() => _pending.remove(p)),
                      ),
                    if (_countOf(k.kind) == 0)
                      Text(
                        '아직 없음',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (_recognizing > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  '첨부를 읽어 발주자 칸을 채우는 중…',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '사업자등록증·명함을 올리면 자동으로 읽어 발주자 칸을 채웁니다.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    final company = _f.clientType != '개인';
    String dateLabel(String? d) => d == null || d.isEmpty ? '선택' : d;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('작성 중인 내용을 버릴까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('계속 작성'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('버리기'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing ? '계약서요청 고치기' : '계약서 작성 요청'),
          actions: [
            TextButton.icon(
              onPressed: _saving ? null : _paste,
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('글 붙여 넣기'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _section('첨부 서류'),
            _attachments(),
            _section('발주자'),
            SegmentedButton<String>(
              segments: [
                for (final t in contractClientTypes)
                  ButtonSegment(value: t, label: Text(t)),
              ],
              selected: {_f.clientType},
              onSelectionChanged: (s) => setState(() {
                _dirty = true;
                _f.clientType = s.first;
              }),
            ),
            const SizedBox(height: 12),
            _field('cname', company ? '상호 *' : '성명 *'),
            if (company) ...[
              _field(
                'bizno',
                '사업자등록번호',
                hint: '000-00-00000',
                type: TextInputType.number,
              ),
              _field('crep', '대표자'),
            ] else
              _field('cphone', '전화번호', type: TextInputType.phone),
            _field('caddr', '주소'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _f.contractor,
                decoration: const InputDecoration(
                  labelText: '수급인 (코아드)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in contractContractors)
                    DropdownMenuItem(value: c.value, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() {
                  _dirty = true;
                  _f.contractor = v ?? _f.contractor;
                }),
              ),
            ),
            _section('공사'),
            _field('site', '현장명 *', hint: '예: 비렉스테크'),
            _field('addr', '공사장소', hint: '주소'),
            _field(
              'items',
              '품목 / 수량',
              hint: '예: COAD-1 (기본형자동문) 1대',
              maxLines: 3,
              suffixIcon: IconButton(
                tooltip: '제품 목록에서 추가',
                onPressed: _saving ? null : () => unawaited(_pickProduct()),
                icon: const Icon(Icons.playlist_add_rounded),
              ),
            ),
            Text('공사기간', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(true),
                    child: Text(dateLabel(_f.periodStart)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('~'),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(false),
                    child: Text(dateLabel(_f.periodEnd)),
                  ),
                ),
                if (_f.periodStart != null || _f.periodEnd != null)
                  IconButton(
                    tooltip: '기간 지우기',
                    onPressed: () => setState(() {
                      _f.periodStart = null;
                      _f.periodEnd = null;
                    }),
                    icon: const Icon(Icons.clear_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _section('대금'),
            _field(
              'amount',
              '계약금액 (공급가, 원)',
              hint: '예: 5500000 또는 550만원',
              suffix: '원',
            ),
            Row(
              children: [
                Expanded(
                  child: _field(
                    'adv',
                    '선급금 비율',
                    type: TextInputType.number,
                    suffix: '%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    'prog',
                    '기성금 비율',
                    type: TextInputType.number,
                    suffix: '%',
                  ),
                ),
              ],
            ),
            Text('선급금 지급시기', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickAdvanceDate,
                    child: Text(dateLabel(_f.advancePayWhen)),
                  ),
                ),
                if (_f.advancePayWhen.isNotEmpty)
                  IconButton(
                    tooltip: '지우기',
                    onPressed: () => setState(() => _f.advancePayWhen = ''),
                    icon: const Icon(Icons.clear_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _field('progWhen', '기성금 지급시기', hint: '예: 공사완료 후 20일 이내'),
            _yesNo('선급금 증권', _f.advanceBond, (v) => _f.advanceBond = v),
            _yesNo(
              '계약이행보증금',
              _f.performanceBond,
              (v) => _f.performanceBond = v,
              rateKey: 'perfRate',
            ),
            _yesNo(
              '하자보증금',
              _f.defectBond,
              (v) => _f.defectBond = v,
              rateKey: 'defRate',
            ),
            const SizedBox(height: 4),
            _field('warranty', '무상보증기간', hint: '예: 하드웨어 1년(구동부 3년)'),
            _section('보내기'),
            SegmentedButton<String>(
              segments: [
                for (final m in contractSendMethods)
                  ButtonSegment(value: m, label: Text(m)),
              ],
              selected: {_f.sendMethod},
              onSelectionChanged: (s) => setState(() {
                _dirty = true;
                _f.sendMethod = s.first;
              }),
            ),
            const SizedBox(height: 12),
            if (_f.sendMethod == '메일')
              _field(
                'mail',
                '받는 사람 이메일 (여럿이면 쉼표로)',
                type: TextInputType.emailAddress,
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _f.withBankbook,
              onChanged: (v) => setState(() {
                _dirty = true;
                _f.withBankbook = v ?? false;
              }),
              title: const Text('통장사본 함께 보내기'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            _field('note', '요청 메모', maxLines: 5),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving || _recognizing > 0 ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(
                _saving
                    ? '저장 중…'
                    : (_recognizing > 0
                          ? '첨부 읽는 중…'
                          : (editing ? '저장' : '요청하기')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// NEW MES 대분류 → 제품 고르기 + 수량
class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.catalog});
  final List<CatalogCategory> catalog;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  late CatalogCategory _cat = widget.catalog.first;
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (_, sc) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  '제품 고르기',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_qty대',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => setState(() => _qty++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final c in widget.catalog)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(c.name),
                      selected: c == _cat,
                      onSelected: (_) => setState(() => _cat = c),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: sc,
              children: [
                for (final p in _cat.products)
                  ListTile(
                    title: Text(p.name),
                    subtitle: p.code.isNotEmpty && !p.name.contains(p.code)
                        ? Text(p.code)
                        : null,
                    trailing: const Icon(Icons.add_rounded),
                    onTap: () =>
                        Navigator.pop(context, (name: p.name, qty: _qty)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
