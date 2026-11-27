import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_site_rules.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_choice_chip.dart';
import 'package:coad_customer_calls/models/gosu_site.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// 홈페이지 문의(고수) 상세. 접수중이면 N차 통화 기록, 접수취소면 취소 사유를 남긴다.
/// 저장하고 나가면 `true` 를 돌려준다.
class GosuSiteDetailScreen extends ConsumerStatefulWidget {
  const GosuSiteDetailScreen({super.key, required this.initial});

  final GosuSite initial;

  @override
  ConsumerState<GosuSiteDetailScreen> createState() =>
      _GosuSiteDetailScreenState();
}

class _GosuSiteDetailScreenState extends ConsumerState<GosuSiteDetailScreen> {
  late GosuSite _site = widget.initial;
  List<GosuSiteFollowup> _followups = [];
  bool _loading = true;
  Object? _error;
  bool _changed = false;

  // 입력
  String? _choice;
  final _content = TextEditingController();
  String? _nextCallYmd;
  DateTime? _visitAt; // 한국 시간 벽시계
  bool _saving = false;
  String? _formError;
  bool _showHandoff = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(gosuSitesRepositoryProvider);
    try {
      final site = await repo.fetchSite(_site.gosuId);
      final followups = await repo.fetchFollowups(_site.gosuId);
      if (!mounted) return;
      setState(() {
        if (site != null) _site = site;
        _followups = followups;
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

  bool get _isCall => _site.workerStatus == kGosuSiteReceiving;
  bool get _isCancel => _site.workerStatus == kGosuSiteCanceled;
  int get _round => nextGosuSiteRound(_followups);

  /// 날짜 선택기 결과(기기 로컬 자정) → `yyyy-MM-dd` 그대로.
  String _ymdOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _visitLabel(DateTime v) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    final hh = v.hour.toString().padLeft(2, '0');
    final mm = v.minute.toString().padLeft(2, '0');
    return '${v.month}/${v.day}(${wd[v.weekday - 1]}) $hh:$mm';
  }

  Future<void> _pickNextDate() async {
    final today = DateTime.parse(todayYmdSeoul());
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextCallYmd != null
          ? DateTime.parse(_nextCallYmd!)
          : today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() => _nextCallYmd = _ymdOf(picked));
    }
  }

  Future<void> _pickVisit() async {
    final today = DateTime.parse(todayYmdSeoul());
    final d = await showDatePicker(
      context: context,
      initialDate: _visitAt ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      locale: const Locale('ko', 'KR'),
      helpText: '방문 날짜',
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: '방문 시간',
    );
    if (!mounted) return;
    setState(() {
      _visitAt = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
      // 방문일이 정해지면 그날을 다음 통화(확인) 예정일로 기본 설정
      _nextCallYmd ??= _ymdOf(d);
    });
  }

  Future<void> _save() async {
    final user = ref.read(authControllerProvider);
    final author = (user?.name ?? '').trim();
    setState(() => _formError = null);
    if (author.isEmpty) {
      setState(() => _formError = '로그인 정보가 없습니다. 다시 로그인해 주세요.');
      return;
    }
    if (_choice == null) {
      setState(
        () => _formError = _isCall ? '통화 결과를 선택해 주세요' : '취소 사유를 선택해 주세요',
      );
      return;
    }
    final content = _content.text.trim();
    if (_isCall) {
      if (content.isEmpty) {
        setState(() => _formError = '통화 내용을 적어 주세요');
        return;
      }
      if (_nextCallYmd == null) {
        setState(() => _formError = '${_round + 1}차 통화 예정일을 입력해 주세요');
        return;
      }
    } else if (_choice == '기타' && content.isEmpty) {
      setState(() => _formError = '기타 사유는 내용을 적어 주세요');
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(gosuSitesRepositoryProvider);
    final round = _round;
    final wasVisit = _isCall && _choice == kGosuSiteVisitConfirmed;
    try {
      if (_isCall) {
        await repo.insertCall(
          site: _site,
          round: round,
          outcome: _choice!,
          content: content,
          author: author,
          nextCallYmd: _nextCallYmd!,
          visitLabel: wasVisit && _visitAt != null
              ? _visitLabel(_visitAt!)
              : null,
        );
      } else {
        await repo.insertCancelReason(
          site: _site,
          reason: _choice!,
          note: content,
          author: author,
        );
      }
      if (!mounted) return;
      _changed = true;
      setState(() {
        _choice = null;
        _content.clear();
        _nextCallYmd = null;
        _visitAt = null;
        _showHandoff = wasVisit;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isCall ? '$round차 통화를 저장했습니다' : '취소 사유를 저장했습니다'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = koreanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openGosu() async {
    final uri = Uri.parse(gosuSiteWorkerUrl(_site.estimateId));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.gosuAccent(scheme);
    final stale = gosuSiteStaleReason(_site);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_site.displayName),
          backgroundColor: accent,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: '고수에서 열기',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: _openGosu,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    koreanErrorMessage(_error!),
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              if (stale != null) _banner(context, '⚠ $stale', scheme.error),
              if (_showHandoff || _pendingVisitHandoff())
                _handoff(context, accent),
              _info(context),
              const SizedBox(height: 16),
              _history(context),
              const SizedBox(height: 16),
              if (_isCall || _isCancel)
                _form(context, accent)
              else
                Text(
                  '고수 진행상황이 "${gosuSiteStatusLabel(_site.workerStatus)}" 입니다. 이후 진행은 고수 사이트에서 관리합니다.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 예전에 방문일 확정을 기록했는데 고수가 아직 접수중이면 계속 안내.
  bool _pendingVisitHandoff() {
    if (!_isCall || _followups.isEmpty) return false;
    final last = _followups.first; // 최신순
    return parseGosuSiteCall(last.result)?.outcome == kGosuSiteVisitConfirmed;
  }

  Widget _banner(BuildContext context, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _handoff(BuildContext context, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '고수에 주소와 방문일을 등록해 주세요',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text('고수에서 이 문의에 주소와 방문 예정일을 넣어야 ‘접수완료’로 바뀝니다.'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _openGosu,
            style: FilledButton.styleFrom(backgroundColor: accent),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('고수 작업자 화면 열기'),
          ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
    Text t(String s) =>
        Text(s, style: const TextStyle(fontWeight: FontWeight.w700));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${gosuSiteStatusLabel(_site.workerStatus)} · 접수 ${formatSeoulMonthDayTime(_site.receivedAt)}',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 6),
        row(
          '연락처',
          Row(
            children: [
              Expanded(child: t(_site.displayPhone)),
              if (_site.customerPhone != null) ...[
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  tooltip: '전화',
                  icon: const Icon(Icons.call_rounded, size: 18),
                  onPressed: () =>
                      LauncherUtils.makePhoneCall(_site.customerPhone!),
                ),
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  tooltip: '문자',
                  icon: const Icon(Icons.sms_rounded, size: 18),
                  onPressed: () => LauncherUtils.sendSMS(_site.customerPhone!),
                ),
              ],
            ],
          ),
        ),
        row(
          '담당',
          Text(
            _site.workerName ?? '미배정',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: _site.workerName == null
                  ? scheme.error
                  : AppTokens.gosuAccent(scheme),
            ),
          ),
        ),
        row('지역', t(gosuSiteRegion(_site))),
        row('제품', t(_site.productLabel)),
        row(
          _isCancel ? '취소일' : '방문예정',
          t(
            formatSeoulMonthDayTime(
              _isCancel ? _site.canceledAt : _site.onsiteAt,
            ).ifEmpty('-'),
          ),
        ),
        row(
          '주소',
          _site.address == null
              ? Text(
                  '고수에 아직 주소 없음 — 고수에서 입력하면 다음 동기화 때 들어옵니다',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              : t(_site.address!),
        ),
        if (_site.gosuMemo != null) row('고수 메모', Text(_site.gosuMemo!)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_site.requestText ?? '문의 내용 없음'),
        ),
        if (_site.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '고객 첨부 사진 ${_site.imageUrls.length}장',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _site.imageUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final url = _site.imageUrls[i];
                return GestureDetector(
                  onTap: () => _showImage(context, url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 84,
                        height: 84,
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _showImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }

  Widget _history(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _followups.isEmpty ? '기록' : '기록 (${_followups.length})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        if (_followups.isEmpty && !_loading)
          Text(
            _isCall ? '아직 통화 기록이 없습니다. 아래에서 1차 통화를 기록하세요.' : '기록이 없습니다.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        for (final f in _followups)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.stage == kGosuSiteCancelStage
                      ? '취소 사유 · ${f.result}'
                      : f.result,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (f.reason != null) ...[
                  const SizedBox(height: 4),
                  Text(f.reason!),
                ],
                if (f.nextAction != null || f.nextActionAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (f.nextAction != null) f.nextAction!,
                      if (f.nextActionAt != null)
                        '예정 ${formatSeoulDate(f.nextActionAt)}',
                    ].join(' · '),
                    style: TextStyle(color: AppTokens.gosuAccent(scheme)),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${f.author} · ${formatSeoulMonthDayTime(f.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _form(BuildContext context, Color accent) {
    final scheme = Theme.of(context).colorScheme;
    final options = _isCall ? kGosuSiteCallResults : kGosuSiteCancelReasons;
    final isVisit = _isCall && _choice == kGosuSiteVisitConfirmed;
    final today = todayYmdSeoul();
    final quick = <(String, String)>[
      ('내일', addDaysToYmd(today, 1)),
      ('3일 뒤', addDaysToYmdSkippingWeekends(today, 3)),
      ('다음 주', nextMondayYmd(today)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isCall ? '$_round차 통화 기록' : '접수취소 사유',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                GosuChoiceChip(
                  label: o,
                  selected: _choice == o,
                  selectedColor: accent,
                  onSelected: (_) => setState(() => _choice = o),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: _isCall ? '통화 내용' : '내용 (선택, 기타는 필수)',
              border: const OutlineInputBorder(),
            ),
          ),
          if (isVisit) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _pickVisit,
              icon: const Icon(Icons.event_rounded),
              label: Text(
                _visitAt == null
                    ? '방문 일시 (선택)'
                    : '방문 ${_visitLabel(_visitAt!)}',
              ),
            ),
          ],
          if (_isCall) ...[
            const SizedBox(height: 10),
            Text(
              '${_round + 1}차 통화 예정일',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in quick)
                  ChoiceChip(
                    label: Text(q.$1),
                    selected: _nextCallYmd == q.$2,
                    onSelected: (_) => setState(() => _nextCallYmd = q.$2),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    _nextCallYmd == null ||
                            quick.any((q) => q.$2 == _nextCallYmd)
                        ? '날짜 선택'
                        : formatSeoulDate(_nextCallYmd),
                  ),
                  onPressed: _pickNextDate,
                ),
              ],
            ),
            if (_nextCallYmd != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '예정 ${formatSeoulDate(_nextCallYmd)} (${formatDayOffsetFromTodayKo(_nextCallYmd!)})',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
          if (_formError != null) ...[
            const SizedBox(height: 8),
            Text(_formError!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_saving ? '저장 중…' : '저장'),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

/// 푸시처럼 id 만 있을 때: 불러온 뒤 상세를 보여 준다.
class GosuSiteDetailLoader extends ConsumerWidget {
  const GosuSiteDetailLoader({super.key, required this.gosuId});

  final String gosuId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<GosuSite?>(
      future: ref.read(gosuSitesRepositoryProvider).fetchSite(gosuId),
      builder: (context, snap) {
        final site = snap.data;
        if (site != null) return GosuSiteDetailScreen(initial: site);
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: const Text('홈페이지 문의'),
            backgroundColor: AppTokens.gosuAccent(scheme),
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: snap.connectionState != ConnectionState.done
                ? const CircularProgressIndicator()
                : Text(
                    snap.hasError
                        ? koreanErrorMessage(snap.error!)
                        : '문의를 찾을 수 없습니다.',
                  ),
          ),
        );
      },
    );
  }
}
