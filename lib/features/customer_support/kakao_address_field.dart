import 'dart:async';

import 'package:coad_customer_calls/core/config/env.dart';
import 'package:coad_customer_calls/data/kakao_local_client.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';

class KakaoAddressField extends StatefulWidget {
  const KakaoAddressField({
    super.key,
    required this.controller,
    this.onSelected,
    this.client,
  });

  final TextEditingController controller;
  final ValueChanged<KakaoPlaceHit>? onSelected;
  final KakaoLocalClient? client;

  @override
  State<KakaoAddressField> createState() => _KakaoAddressFieldState();
}

class _KakaoAddressFieldState extends State<KakaoAddressField> {
  late final KakaoLocalClient _client;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? KakaoLocalClient();
  }

  Future<void> _openSearch() async {
    final hit = await showModalBottomSheet<KakaoPlaceHit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => _KakaoAddressSearchSheet(
        client: _client,
        initialQuery: widget.controller.text,
      ),
    );
    if (!mounted || hit == null) return;
    widget.controller.value = TextEditingValue(
      text: hit.suggestionLabel,
      selection: TextSelection.collapsed(offset: hit.suggestionLabel.length),
    );
    widget.onSelected?.call(hit);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return TextField(
      controller: widget.controller,
      readOnly: true,
      showCursor: false,
      decoration: InputDecoration(
        labelText: '주소',
        suffixIcon: IconButton(
          tooltip: '주소 검색',
          onPressed: _openSearch,
          icon: Icon(Icons.search_rounded, color: accent),
        ),
      ),
      onTap: _openSearch,
    );
  }
}

class _KakaoAddressSearchSheet extends StatefulWidget {
  const _KakaoAddressSearchSheet({
    required this.client,
    required this.initialQuery,
  });

  final KakaoLocalClient client;
  final String initialQuery;

  @override
  State<_KakaoAddressSearchSheet> createState() =>
      _KakaoAddressSearchSheetState();
}

class _KakaoAddressSearchSheetState extends State<_KakaoAddressSearchSheet> {
  late final TextEditingController _queryCtrl;
  Timer? _debounce;
  List<KakaoPlaceHit> _hits = const [];
  bool _busy = false;
  String? _error;
  String _lookedUp = '';

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController(text: widget.initialQuery);
    final q = widget.initialQuery.trim();
    if (q.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_search(q));
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _hits = const [];
        _busy = false;
        _error = q.isEmpty ? null : '두 글자 이상 입력해 주세요.';
        _lookedUp = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_search(q));
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _busy = true;
      _error = null;
      _lookedUp = query;
    });
    try {
      final hits = await widget.client.search(query);
      if (!mounted || _lookedUp != query) return;
      setState(() {
        _hits = hits;
        _busy = false;
        _error = hits.isEmpty ? '검색 결과가 없습니다.' : null;
      });
    } catch (e) {
      if (!mounted || _lookedUp != query) return;
      setState(() {
        _hits = const [];
        _busy = false;
        _error = e is StateError ? e.message : '주소 검색에 실패했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _queryCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: '주소',
                  hintText: '예: 교동 219-17',
                  suffixIcon: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          onPressed: () {
                            final q = _queryCtrl.text.trim();
                            if (q.length >= 2) unawaited(_search(q));
                          },
                          icon: Icon(Icons.search_rounded, color: accent),
                        ),
                ),
                onChanged: _onChanged,
                onSubmitted: (v) {
                  final q = v.trim();
                  if (q.length >= 2) unawaited(_search(q));
                },
              ),
            ),
            if (kakaoRestApiKey.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '카카오 API 키가 없습니다. 앱을 완전히 종료한 뒤 다시 실행해 주세요.',
                  style: TextStyle(color: scheme.error, fontSize: 13),
                ),
              ),
            Expanded(
              child: _hits.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _busy
                              ? '검색 중…'
                              : (_error ?? '주소를 입력하면 비슷한 주소가 나옵니다.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      itemCount: _hits.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final hit = _hits[i];
                        final sub =
                            hit.roadAddress != null &&
                                hit.address != hit.roadAddress
                            ? hit.address
                            : null;
                        return ListTile(
                          leading: Icon(Icons.place_outlined, color: accent),
                          title: Text(
                            hit.suggestionLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: sub == null || sub == hit.suggestionLabel
                              ? null
                              : Text(sub),
                          onTap: () => Navigator.pop(context, hit),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
