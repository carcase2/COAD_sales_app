import 'dart:async';

import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/utils/support_map_distance.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/kakao_local_client.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class SupportSitesMapScreen extends ConsumerStatefulWidget {
  const SupportSitesMapScreen({
    super.key,
    this.focusLog,
    this.pendingOnly = false,
  });

  final SupportCallLog? focusLog;
  final bool pendingOnly;

  @override
  ConsumerState<SupportSitesMapScreen> createState() =>
      _SupportSitesMapScreenState();
}

class _Pin {
  const _Pin({required this.log, required this.point});

  final SupportCallLog log;
  final LatLng point;
}

class _SupportSitesMapScreenState extends ConsumerState<SupportSitesMapScreen> {
  final _map = MapController();
  final _kakao = KakaoLocalClient();
  List<_Pin> _pins = const [];
  bool _loading = true;
  Object? _error;
  String _filter = 'pending';
  SupportCallLog? _selected;

  static const _korea = LatLng(36.35, 127.7);

  @override
  void initState() {
    super.initState();
    _filter = widget.pendingOnly ? 'pending' : 'open';
    _selected = widget.focusLog;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  bool _isOpen(SupportCallLog log) {
    final s = log.serviceStatusId;
    return isSupportServiceStatusPending(s) ||
        s == kSupportStatusInProgress ||
        s == kSupportStatusVisitScheduled;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(supportCallLogRepositoryProvider)
          .listForMap();
      final focus = widget.focusLog;
      final withFocus = [
        ...rows,
        if (focus != null && rows.every((e) => e.id != focus.id)) focus,
      ];
      final pins = <_Pin>[];
      var geocoded = 0;
      for (final log in withFocus) {
        var lat = log.latitude;
        var lng = log.longitude;
        final isFocus = log.id == widget.focusLog?.id;
        if (!log.hasCoords) {
          final addr = (log.address ?? '').trim();
          if (addr.isEmpty) continue;
          if (!isFocus && geocoded >= 30) continue;
          try {
            final hits = await _kakao.search(addr);
            if (hits.isEmpty) continue;
            lat = hits.first.lat;
            lng = hits.first.lng;
            geocoded += 1;
            unawaited(
              ref
                  .read(supportCallLogRepositoryProvider)
                  .saveCoords(id: log.id, latitude: lat, longitude: lng),
            );
          } catch (_) {
            continue;
          }
        }
        if (lat == null || lng == null) continue;
        pins.add(
          _Pin(
            log: log.hasCoords
                ? log
                : log.copyWith(latitude: lat, longitude: lng),
            point: LatLng(lat, lng),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _pins = pins;
        _loading = false;
      });
      _fit();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<_Pin> get _visible {
    final rows = _pins.where((p) {
      final keepFocus = p.log.id == widget.focusLog?.id;
      return keepFocus ||
          switch (_filter) {
            'pending' => p.log.isPending,
            'progress' => p.log.serviceStatusId == kSupportStatusInProgress,
            'visit' => p.log.serviceStatusId == kSupportStatusVisitScheduled,
            _ => _isOpen(p.log),
          };
    }).toList();
    final focus = widget.focusLog;
    if (focus == null ||
        !focus.hasCoords && rows.where((p) => p.log.id == focus.id).isEmpty) {
      return rows;
    }
    rows.sort((a, b) {
      final fa = a.log.id == focus.id;
      final fb = b.log.id == focus.id;
      if (fa != fb) return fa ? -1 : 1;
      final da = supportDistanceKm(
        fromLat: focus.latitude ?? _pinOf(focus.id)?.point.latitude,
        fromLng: focus.longitude ?? _pinOf(focus.id)?.point.longitude,
        toLat: a.point.latitude,
        toLng: a.point.longitude,
      );
      final db = supportDistanceKm(
        fromLat: focus.latitude ?? _pinOf(focus.id)?.point.latitude,
        fromLng: focus.longitude ?? _pinOf(focus.id)?.point.longitude,
        toLat: b.point.latitude,
        toLng: b.point.longitude,
      );
      return (da ?? 1e9).compareTo(db ?? 1e9);
    });
    return rows;
  }

  _Pin? _pinOf(String id) {
    for (final p in _pins) {
      if (p.log.id == id) return p;
    }
    return null;
  }

  void _fit() {
    final vis = _visible;
    if (vis.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        if (vis.length == 1) {
          _map.move(vis.first.point, 14);
          return;
        }
        _map.fitCamera(
          CameraFit.coordinates(
            coordinates: vis.map((e) => e.point).toList(),
            padding: const EdgeInsets.fromLTRB(40, 80, 40, 180),
          ),
        );
      } catch (_) {}
    });
  }

  Color _pinColor(SupportCallLog log, ColorScheme scheme) {
    if (log.id == widget.focusLog?.id) {
      return AppTokens.customerSupportAccent(scheme);
    }
    if (log.isPending) return scheme.error;
    if (log.serviceStatusId == kSupportStatusVisitScheduled) {
      return scheme.tertiary;
    }
    return scheme.primary;
  }

  Future<void> _openLog(SupportCallLog log) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerSupportReceptionDetailScreen(log: log),
      ),
    );
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vis = _visible;
    final focus = widget.focusLog;
    final focusPin = focus == null ? null : _pinOf(focus.id);
    final nearby = vis
        .where((p) => p.log.id != focus?.id && p.log.isPending)
        .take(8)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(focus == null ? '현장 지도' : '가까운 미처리'),
        actions: [
          IconButton(
            tooltip: '카카오맵',
            onPressed: () {
              final addr = (_selected ?? focus)?.address ?? '';
              if (addr.trim().isEmpty) return;
              LauncherUtils.openAddressMap(addr);
            },
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: _loading && _pins.isEmpty
          ? const AppLoading(message: '지도를 불러오는 중…')
          : _error != null && _pins.isEmpty
          ? AppEmpty(
              icon: Icons.map_outlined,
              message: '지도를 불러오지 못했습니다.',
              detail: koreanErrorMessage(_error!),
              actionLabel: '다시 시도',
              onAction: () => unawaited(_load()),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      _chip('미처리', 'pending', scheme.error),
                      _chip('진행중', 'progress', scheme.primary),
                      _chip('방문예정', 'visit', scheme.tertiary),
                      _chip(
                        '미완료 전체',
                        'open',
                        AppTokens.customerSupportAccent(scheme),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: focusPin?.point ?? _korea,
                          initialZoom: focusPin == null ? 7 : 13,
                          onTap: (_, _) => setState(() => _selected = null),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'coad_customer_calls',
                          ),
                          MarkerLayer(
                            markers: [
                              for (final pin in vis)
                                Marker(
                                  point: pin.point,
                                  width: pin.log.id == focus?.id ? 44 : 36,
                                  height: pin.log.id == focus?.id ? 44 : 36,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _selected = pin.log),
                                    child: Icon(
                                      Icons.location_on,
                                      size: pin.log.id == focus?.id ? 42 : 34,
                                      color: _pinColor(pin.log, scheme),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (vis.isEmpty)
                        const Align(
                          alignment: Alignment.center,
                          child: Material(
                            color: Colors.white70,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('이 필터에 지도에 찍을 현장이 없습니다.'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Material(
                  elevation: 8,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_selected != null)
                            _SelectedTile(
                              log: _selected!,
                              km: supportDistanceKm(
                                fromLat: focusPin?.point.latitude,
                                fromLng: focusPin?.point.longitude,
                                toLat: _pinOf(_selected!.id)?.point.latitude,
                                toLng: _pinOf(_selected!.id)?.point.longitude,
                              ),
                              onOpen: () => unawaited(_openLog(_selected!)),
                            )
                          else if (focus != null) ...[
                            Text(
                              '${focus.customerName.isEmpty ? '이 현장' : focus.customerName} 근처 미처리',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (nearby.isEmpty)
                              Text(
                                '근처에 찍힌 미처리가 없습니다. 주소가 있는 접수만 지도에 올라갑니다.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            else
                              SizedBox(
                                height: 88,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: nearby.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    final pin = nearby[i];
                                    final km = supportDistanceKm(
                                      fromLat: focusPin?.point.latitude,
                                      fromLng: focusPin?.point.longitude,
                                      toLat: pin.point.latitude,
                                      toLng: pin.point.longitude,
                                    );
                                    return ActionChip(
                                      label: Text(
                                        '${pin.log.customerName.isEmpty ? '(이름 없음)' : pin.log.customerName} · ${supportDistanceLabel(km)}',
                                      ),
                                      onPressed: () {
                                        setState(() => _selected = pin.log);
                                        _map.move(pin.point, 14);
                                      },
                                    );
                                  },
                                ),
                              ),
                          ] else
                            Text(
                              '핀 ${vis.length}개 · 미처리부터 한눈에 보고, 가까운 순으로 고를 수 있습니다.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.22),
      side: BorderSide(color: selected ? color : color.withValues(alpha: 0.35)),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: selected ? color : null,
      ),
      onSelected: (_) {
        setState(() => _filter = value);
        _fit();
      },
    );
  }
}

class _SelectedTile extends StatelessWidget {
  const _SelectedTile({required this.log, required this.onOpen, this.km});

  final SupportCallLog log;
  final VoidCallback onOpen;
  final double? km;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.place_rounded, color: scheme.primary),
      title: Text(
        log.customerName.isEmpty ? '(이름 없음)' : log.customerName,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        [
          supportCallLogProgressLabel(log.serviceStatusId),
          if (supportDistanceLabel(km).isNotEmpty) supportDistanceLabel(km),
          log.address ?? '',
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: FilledButton(onPressed: onOpen, child: const Text('상세')),
    );
  }
}
