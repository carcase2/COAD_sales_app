import 'dart:async';
import 'dart:io';

import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/ux_action_dock.dart';
import 'package:coad_customer_calls/data/mes_repository.dart';
import 'package:coad_customer_calls/features/customer_support/kakao_address_field.dart';
import 'package:coad_customer_calls/features/mes/mes_order_models.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_source_sheet.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class MesOrderScreen extends ConsumerStatefulWidget {
  const MesOrderScreen({super.key, this.initialDraftId, this.initialInstallDate});

  final String? initialDraftId;
  final String? initialInstallDate;

  @override
  ConsumerState<MesOrderScreen> createState() => _MesOrderScreenState();
}

class _MesOrderScreenState extends ConsumerState<MesOrderScreen> {
  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  String _msg = '';
  String _error = '';

  String _siteMode = 'search';
  String _custQ = '';
  bool _searching = false;
  List<Map<String, dynamic>> _siteHits = [];
  Timer? _searchTimer;

  String _customerId = '';
  String _siteId = '';
  final _siteName = TextEditingController();
  final _address = TextEditingController();
  final _addressDetail = TextEditingController();
  final _managerName = TextEditingController();
  List<MesPhoneRow> _phones = [MesPhoneRow()];
  String _locationType = '1';
  String _branchCode = '';
  String _salesUserId = '';
  String _salesUserName = '';

  List<MesInstallDay> _installDays = [];
  List<Map<String, dynamic>> _crews = [];

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<MesCatOptionDef> _catOptions = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _locationTypes = [];
  List<Map<String, dynamic>> _photoCats = [];
  List<Map<String, dynamic>> _drafts = [];

  List<MesItemRow> _items = [MesItemRow()];
  List<MesMatRow> _mats = [];
  List<MesPayRow> _pays = [MesPayRow(kind: 'DEPOSIT'), MesPayRow(kind: 'BALANCE')];
  List<MesPhotoRef> _photos = [];
  final _amount = TextEditingController();
  bool _vat = false;
  List<String> _contractTypes = ['3'];
  final _mfgNote = TextEditingController();
  final _installNote = TextEditingController();
  final _remark = TextEditingController();
  String? _draftId;
  List<Map<String, dynamic>> _shortage = [];

  MesRepository get _repo => ref.read(mesRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _draftId = widget.initialDraftId;
    _salesUserId = ref.read(authControllerProvider)?.id ?? '';
    _salesUserName = ref.read(authControllerProvider)?.name ?? '';
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _siteName.dispose();
    _address.dispose();
    _addressDetail.dispose();
    _managerName.dispose();
    _amount.dispose();
    _mfgNote.dispose();
    _installNote.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await _repo.me();
      final user = me?['user'] as Map?;
      if (user != null) {
        _salesUserId = '${user['id'] ?? _salesUserId}';
        _salesUserName = '${user['name'] ?? _salesUserName}';
        final branch = '${user['branchCode'] ?? user['branch_code'] ?? ''}';
        if (branch.isNotEmpty) _branchCode = branch;
      }
      final results = await Future.wait([
        _repo.get('/api/products'),
        _repo.get('/api/materials'),
        _repo.get('/api/branches'),
        _repo.get('/api/location-types'),
        _repo.get('/api/photo-categories'),
        _repo.get('/api/orders?status=DRAFT'),
        _repo.get('/api/crews/week'),
      ]);
      _products = _list(results[0], 'products');
      _materials = _list(results[1], 'materials');
      _branches = _list(results[2], 'branches').where((b) => b['is_active'] != false).toList();
      _locationTypes = _list(results[3], 'locationTypes');
      if (_locationTypes.isEmpty) {
        _locationTypes = [
          {'code': '1', 'name': '공장'},
          {'code': '2', 'name': '상가'},
          {'code': '3', 'name': '주택'},
          {'code': '4', 'name': '공공기관'},
          {'code': '99', 'name': '기타'},
        ];
      }
      _photoCats = _list(results[4], 'sales');
      if (_photoCats.isEmpty) _photoCats = _list(results[4], 'categories');
      _drafts = _list(results[5], 'orders');
      _crews = _crewsOf(results[6]);
      _categories = _list(results[0], 'categories');
      if (_categories.isEmpty) {
        final seen = <String>{};
        for (final p in _products) {
          final c = p['mes_product_categories'] as Map? ?? {};
          final id = '${p['category_id'] ?? c['id'] ?? ''}';
          if (id.isEmpty || !seen.add(id)) continue;
          _categories.add({'id': id, 'name': '${c['name'] ?? id}'});
        }
      }
      _catOptions = [
        for (final raw in _list(results[0], 'categoryOptions'))
          MesCatOptionDef(
            categoryId: '${raw['category_id'] ?? ''}',
            name: '${raw['name'] ?? ''}',
            fieldType: '${raw['field_type'] ?? 'TEXT'}',
            required: raw['required'] == true,
            defaultValue: raw['default_value']?.toString(),
            choices: [
              if (raw['choices'] is List) ...((raw['choices'] as List).map((e) => '$e')),
            ],
            isActive: raw['is_active'] != false,
          ),
      ];
      if (_branchCode.isEmpty && _branches.isNotEmpty) {
        _branchCode = '${_branches.first['code'] ?? ''}';
      }
      _locationType = '${_locationTypes.first['code'] ?? '1'}';
      if (_draftId != null) await _hydrateDraft(_draftId!);
      final seed = widget.initialInstallDate ?? '';
      if (_installDays.isEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(seed)) {
        _installDays = [MesInstallDay(date: seed, slots: const [1])];
      }
    } catch (e) {
      _error = '마스터를 불러오지 못했습니다.';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is! List) return [];
    return [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)];
  }

  List<Map<String, dynamic>> _crewsOf(Map<String, dynamic> data) {
    final week = data['week'];
    final branches = week is Map ? week['branches'] : data['branches'];
    if (branches is! List || _branchCode.isEmpty) {
      return [
        for (var i = 1; i <= 4; i++) {'slot': i, 'name': '팀$i'},
      ];
    }
    final branchId = _branches.cast<Map?>().firstWhere(
      (b) => '${b?['code']}' == _branchCode,
      orElse: () => null,
    )?['id'];
    for (final b in branches) {
      if (b is! Map) continue;
      if (branchId != null && '${b['branchId']}' != '$branchId') continue;
      final crews = b['crews'];
      if (crews is List && crews.isNotEmpty) {
        return [
          for (final c in crews)
            if (c is Map) {'slot': c['slot'] ?? 0, 'name': '${c['name'] ?? '팀${c['slot']}'}'},
        ];
      }
    }
    return [
      for (var i = 1; i <= 4; i++) {'slot': i, 'name': '팀$i'},
    ];
  }

  Future<void> _searchSites(String q) async {
    final keyword = q.trim();
    if (keyword.isEmpty) {
      setState(() => _siteHits = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final data = await _repo.get('/api/customers?q=${Uri.encodeQueryComponent(keyword)}');
      final seen = <String>{};
      final hits = <Map<String, dynamic>>[];
      void add(Map<String, dynamic> s) {
        final name = '${s['name'] ?? ''}';
        final id = '${s['id'] ?? ''}';
        final key = id.isNotEmpty ? id : 'name:$name';
        if (name.isEmpty || seen.contains(key) || seen.contains(name)) return;
        seen.add(key);
        seen.add(name);
        hits.add(s);
      }

      for (final s in _list(data, 'sites')) {
        add(s);
      }
      for (final c in _list(data, 'customers')) {
        final sites = c['mes_sites'];
        if (sites is! List) continue;
        for (final raw in sites) {
          if (raw is! Map) continue;
          add({
            ...Map<String, dynamic>.from(raw),
            'customers': [
              {'id': c['id'], 'name': c['name'], 'phone': c['phone']},
            ],
          });
        }
      }
      if (mounted) setState(() => _siteHits = hits);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onQuery(String q) {
    _custQ = q;
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 280), () => _searchSites(q));
    setState(() {});
  }

  void _pickSite(Map<String, dynamic> s) {
    final id = '${s['id'] ?? ''}';
    _siteId = id.startsWith('name:') ? '' : id;
    _siteName.text = '${s['name'] ?? ''}';
    _address.text = '${s['address'] ?? ''}';
    _addressDetail.text = '${s['address_detail'] ?? ''}';
    _managerName.text = '${s['manager_name'] ?? ''}';
    final customers = s['customers'];
    _customerId = customers is List && customers.isNotEmpty ? '${customers.first['id'] ?? ''}' : '';
    final loc = '${s['location_type'] ?? ''}';
    if (loc.isNotEmpty) _locationType = loc;
    _siteMode = 'existing';
    _siteHits = [];
    _custQ = '';
    setState(() {});
  }

  void _startNewSite() {
    _siteId = '';
    _customerId = '';
    _siteName.text = _custQ.trim();
    _address.clear();
    _addressDetail.clear();
    _managerName.clear();
    _phones = [MesPhoneRow()];
    _siteMode = 'new';
    _siteHits = [];
    setState(() {});
  }

  List<MesCatOptionDef> _defsFor(String categoryId) {
    return _catOptions.where((d) => d.categoryId == categoryId && d.isActive).toList();
  }

  List<Map<String, dynamic>> _modelsFor(String categoryId) {
    if (categoryId.isEmpty) return _products;
    return _products.where((p) {
      final cid = '${p['category_id'] ?? p['mes_product_categories']?['id'] ?? ''}';
      return cid == categoryId;
    }).toList();
  }

  void _applyBom() {
    final merged = <String, MesMatRow>{};
    for (final it in _items) {
      final p = _products.cast<Map?>().firstWhere((x) => '${x?['id']}' == it.productId, orElse: () => null);
      final qty = int.tryParse(it.qty) ?? 0;
      final boms = p?['mes_boms'];
      final lines = boms is Map ? boms['mes_bom_lines'] : null;
      if (lines is! List) continue;
      for (final line in lines) {
        if (line is! Map) continue;
        final mat = line['mes_materials'];
        if (mat is! Map) continue;
        final id = '${mat['id'] ?? ''}';
        if (id.isEmpty) continue;
        final add = ((line['qty'] as num?)?.toDouble() ?? 0) * qty;
        final prev = merged[id];
        merged[id] = MesMatRow(
          materialId: id,
          qty: '${(double.tryParse(prev?.qty ?? '0') ?? 0) + add}',
          fromBom: true,
          label: '${mat['code'] ?? ''} ${mat['name'] ?? ''}'.trim(),
        );
      }
    }
    final extras = _mats.where((m) => !m.fromBom).toList();
    _mats = [...merged.values, ...extras];
  }

  bool get _canNext {
    if (_step == 0) return mesCanNextSite(siteMode: _siteMode, siteName: _siteName.text);
    if (_step == 1) {
      if (_items.isEmpty) return false;
      for (final it in _items) {
        if (it.productId.isEmpty || mesParseMm(it.widthMm) <= 0 || mesParseMm(it.heightMm) <= 0) return false;
        if ((int.tryParse(it.qty) ?? 0) <= 0) return false;
        for (final d in _defsFor(it.categoryId).where((d) => d.required)) {
          final hit = it.options.where((o) => o.name == d.name);
          if (hit.isEmpty || hit.first.value.trim().isEmpty) return false;
        }
      }
      return true;
    }
    return true;
  }

  Map<String, dynamic> _payload({bool draft = false, bool confirmShortage = false}) {
    _pays = mesSyncBalance(_pays, mesWonDigits(_amount.text));
    return mesBuildOrderPayload(
      draft: draft,
      draftId: _draftId,
      customerId: _customerId,
      siteId: _siteId,
      siteName: _siteName.text.trim(),
      siteAddress: _address.text.trim(),
      siteAddressDetail: _addressDetail.text.trim(),
      locationType: _locationType,
      managerName: _managerName.text.trim(),
      phones: _phones,
      branchCode: _branchCode,
      salesUserId: _salesUserId,
      installDays: _installDays,
      contractAmount: mesWonDigits(_amount.text),
      vatIncluded: _vat,
      contractTypes: _contractTypes,
      mfgNote: _mfgNote.text,
      installNote: _installNote.text,
      remark: _remark.text,
      items: _items,
      materials: _mats,
      payments: _pays,
      photos: _photos,
      confirmShortage: confirmShortage,
    );
  }

  Future<bool> _save({required bool draft, bool confirmShortage = false}) async {
    setState(() {
      _saving = true;
      _error = '';
      _msg = '';
    });
    try {
      var res = await _repo.post('/api/orders', _payload(draft: draft, confirmShortage: confirmShortage));
      final status = res['_status'] as int? ?? 0;
      if (status == 409 && res['shortage'] is List) {
        _shortage = _list(res, 'shortage');
        if (!confirmShortage && !draft) {
          setState(() => _error = '센서가 부족합니다. 확인 후 다시 저장할 수 있습니다.');
          return false;
        }
        res = await _repo.post('/api/orders', _payload(draft: draft, confirmShortage: true));
      }
      if ((res['_status'] as int? ?? 0) >= 400) {
        setState(() => _error = res['error']?.toString() ?? '저장에 실패했습니다.');
        return false;
      }
      final order = res['order'] as Map?;
      _draftId = '${order?['id'] ?? _draftId ?? ''}';
      await _flushPendingPhotos();
      if (draft) {
        _msg = '임시저장했습니다.';
        final drafts = await _repo.get('/api/orders?status=DRAFT');
        _drafts = _list(drafts, 'orders');
      } else {
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 ${order?['inquiry_no'] ?? '완료'}')),
        );
        Navigator.of(context).pop(true);
      }
      return true;
    } catch (_) {
      setState(() => _error = '저장 중 오류가 발생했습니다.');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _flushPendingPhotos() async {
    final id = _draftId;
    if (id == null || id.isEmpty) return;
    for (var i = 0; i < _photos.length; i++) {
      final p = _photos[i];
      final path = p.localPath;
      if (path == null || !p.id.startsWith('pending:')) continue;
      final res = await _repo.uploadOrderPhoto(filePath: path, orderId: id, category: p.category, label: p.label);
      final photo = res['photo'] as Map? ?? res['attachment'] as Map? ?? res;
      final newId = '${photo['id'] ?? ''}';
      if (newId.isNotEmpty) {
        _photos[i] = MesPhotoRef(id: newId, category: p.category, label: p.label);
      }
    }
  }

  Future<void> _hydrateDraft(String id) async {
    final data = await _repo.get('/api/orders/$id');
    final o = data['order'];
    if (o is! Map || o['status'] != 'DRAFT') return;
    _draftId = '${o['id']}';
    _customerId = '${o['customer_id'] ?? o['mes_customers']?['id'] ?? ''}';
    _siteId = '${o['site_id'] ?? ''}';
    _siteName.text = '${o['site_name'] ?? ''}';
    final site = o['mes_sites'] as Map? ?? {};
    _address.text = '${site['address'] ?? o['site_address'] ?? ''}';
    _addressDetail.text = '${site['address_detail'] ?? ''}';
    _managerName.text = '${site['manager_name'] ?? ''}';
    _locationType = '${site['location_type'] ?? _locationType}';
    _siteMode = _siteId.isNotEmpty ? 'existing' : (_siteName.text.isEmpty ? 'search' : 'new');
    _branchCode = '${(o['mes_branches'] as Map?)?['code'] ?? _branchCode}';
    _amount.text = mesWonDigits('${o['contract_amount'] ?? 0}') > 0 ? '${o['contract_amount']}' : '';
    _vat = o['vat_included'] == true;
    final types = o['contract_types'];
    if (types is List && types.isNotEmpty) _contractTypes = types.map((e) => '$e').toList();
    _mfgNote.text = '${o['mfg_note'] ?? ''}';
    _installNote.text = '${o['install_note'] ?? ''}';
    _remark.text = '${o['remark'] ?? ''}';
    final plan = o['install_plan'] ?? o['installPlan'];
    if (plan is List) {
      _installDays = [
        for (final d in plan)
          if (d is Map)
            MesInstallDay(
              date: '${d['date'] ?? ''}',
              slots: [
                if (d['slots'] is List) ...((d['slots'] as List).map((e) => int.tryParse('$e') ?? 0).where((n) => n > 0)),
              ],
            ),
      ];
    }
    final items = o['mes_order_items'];
    if (items is List && items.isNotEmpty) {
      _items = [
        for (final it in items)
          if (it is Map)
            MesItemRow(
              productId: '${it['product_id'] ?? ''}',
              categoryId: '${_products.cast<Map?>().firstWhere((p) => '${p?['id']}' == '${it['product_id']}', orElse: () => null)?['category_id'] ?? ''}',
              qty: '${it['qty'] ?? 1}',
              widthMm: mesFormatMm(it['width_mm']),
              heightMm: mesFormatMm(it['height_mm']),
              motor: '${it['motor'] ?? 'L'}',
              color: '${it['color'] ?? ''}',
              remark: '${it['remark'] ?? ''}',
            ),
      ];
      for (final it in _items) {
        it.options = mesMergeOptions(_defsFor(it.categoryId), it.options);
      }
    }
    _applyBom();
    _msg = '임시저장 건을 불러왔습니다.';
  }

  Future<void> _addPhotos(String category) async {
    final src = await showSalesCallImageSourceSheet(context, includeFiles: false);
    if (src == null) return;
    final picker = ImagePicker();
    final files = <XFile>[];
    if (src == SalesCallImageSource.camera) {
      final shot = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (shot != null) files.add(shot);
    } else {
      files.addAll(await picker.pickMultiImage(imageQuality: 85));
    }
    if (files.isEmpty) return;
    if (_draftId == null || _draftId!.isEmpty) {
      await _save(draft: true);
    }
    for (final f in files) {
      _photos.add(MesPhotoRef(id: 'pending:${f.path}', category: category, localPath: f.path));
    }
    await _flushPendingPhotos();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MES 영업 등록'),
        actions: [
          TextButton(
            onPressed: _drafts.isEmpty ? null : _pickDraft,
            child: Text('이어서 작성${_drafts.isEmpty ? '' : ' (${_drafts.length})'}'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < mesOrderSteps.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: i == _step
                                    ? Theme.of(context).colorScheme.primary
                                    : i < _step
                                        ? Theme.of(context).colorScheme.primaryContainer
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                foregroundColor: i == _step ? Theme.of(context).colorScheme.onPrimary : null,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                if (i > 0 && !mesCanNextSite(siteMode: _siteMode, siteName: _siteName.text)) return;
                                setState(() => _step = i);
                              },
                              child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(mesOrderSteps[_step], style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (_msg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(_msg, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(_error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (_step == 0) ..._siteStep(),
                      if (_step == 1) ..._productStep(),
                      if (_step == 2) ..._sensorStep(),
                      if (_step == 3) ..._photoStep(),
                      if (_step == 4) ..._payStep(),
                    ],
                  ),
                ),
                UxActionDock(
                  flexes: const [1, 1, 1, 2],
                  children: [
                    UxDockButton(
                      icon: Icons.chevron_left,
                      label: '이전',
                      enabled: _step > 0 && !_saving,
                      onPressed: () => setState(() => _step -= 1),
                    ),
                    UxDockButton(
                      icon: Icons.save_outlined,
                      label: '임시저장',
                      enabled: !_saving,
                      onPressed: () => _save(draft: true),
                    ),
                    UxDockButton(
                      icon: Icons.note_add_outlined,
                      label: '신규작성',
                      enabled: !_saving,
                      onPressed: _reset,
                    ),
                    UxDockButton(
                      icon: _step < 4 ? Icons.chevron_right : Icons.check,
                      label: _saving
                          ? '저장 중'
                          : _step < 4
                              ? '다음'
                              : (_shortage.isNotEmpty ? '부족 확인 후 저장' : '수주 등록'),
                      emphasized: true,
                      enabled: !_saving && (_step < 4 ? _canNext : _canNext),
                      onPressed: () {
                        if (_step < 4) {
                          setState(() => _step += 1);
                        } else {
                          _save(draft: false, confirmShortage: _shortage.isNotEmpty);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _pickDraft() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('이어서 작성')),
            for (final d in _drafts)
              ListTile(
                title: Text('${d['site_name'] ?? '임시'}'),
                subtitle: Text('${d['inquiry_no'] ?? ''}'),
                onTap: () => Navigator.pop(ctx, '${d['id']}'),
              ),
          ],
        ),
      ),
    );
    if (id == null) return;
    setState(() => _loading = true);
    await _hydrateDraft(id);
    if (mounted) setState(() => _loading = false);
  }

  void _reset() {
    _draftId = null;
    _step = 0;
    _siteMode = 'search';
    _custQ = '';
    _siteHits = [];
    _customerId = '';
    _siteId = '';
    _siteName.clear();
    _address.clear();
    _addressDetail.clear();
    _managerName.clear();
    _phones = [MesPhoneRow()];
    _installDays = [];
    _items = [MesItemRow()];
    _mats = [];
    _pays = [MesPayRow(kind: 'DEPOSIT'), MesPayRow(kind: 'BALANCE')];
    _photos = [];
    _amount.clear();
    _vat = false;
    _contractTypes = ['3'];
    _mfgNote.clear();
    _installNote.clear();
    _remark.clear();
    _shortage = [];
    _msg = '새 영업 등록입니다.';
    _error = '';
    setState(() {});
  }

  List<Widget> _siteStep() {
    if (_siteMode == 'search') {
      return [
        TextField(
          decoration: const InputDecoration(
            labelText: '현장 찾기',
            hintText: '현장명으로 검색',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: _onQuery,
        ),
        if (_searching) const Padding(padding: EdgeInsets.all(12), child: Text('검색 중…')),
        if (_custQ.trim().isNotEmpty && !_searching && _siteHits.isEmpty) ...[
          const SizedBox(height: 16),
          Text('‘${_custQ.trim()}’ 현장이 없습니다.'),
          const SizedBox(height: 8),
          FilledButton(onPressed: _startNewSite, child: const Text('새 현장으로 등록')),
        ],
        for (final s in _siteHits)
          ListTile(
            leading: const Icon(Icons.apartment),
            title: Text('${s['name'] ?? ''}'),
            subtitle: Text('${s['address'] ?? ''}'),
            onTap: () => _pickSite(s),
          ),
        if (_custQ.trim().isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('현장명을 입력하면 목록이 나옵니다.', textAlign: TextAlign.center),
          ),
      ];
    }
    return [
      Card(
        color: _siteMode == 'existing' ? const Color(0xFFECFDF5) : Colors.blue.shade50,
        child: ListTile(
          title: Text(_siteMode == 'existing' ? '기존 현장' : '신규 현장'),
          subtitle: Text(_siteName.text),
          trailing: TextButton(onPressed: () => setState(() => _siteMode = 'search'), child: const Text('다시 검색')),
        ),
      ),
      TextField(
        controller: _siteName,
        readOnly: _siteMode == 'existing',
        decoration: const InputDecoration(labelText: '현장명 *'),
        onChanged: (_) => setState(() {}),
      ),
      DropdownButtonFormField<String>(
        value: _locationTypes.any((l) => '${l['code']}' == _locationType) ? _locationType : null,
        items: [
          for (final l in _locationTypes)
            DropdownMenuItem(value: '${l['code']}', child: Text('${l['name']}')),
        ],
        onChanged: (v) => setState(() => _locationType = v ?? _locationType),
        decoration: const InputDecoration(labelText: '설치장소 유형'),
      ),
      KakaoAddressField(
        controller: _address,
        onSelected: (hit) => _address.text = hit.displayAddress,
      ),
      TextField(controller: _addressDetail, decoration: const InputDecoration(labelText: '상세주소')),
      TextField(controller: _managerName, decoration: const InputDecoration(labelText: '현장담당자')),
      const SizedBox(height: 8),
      const Text('담당자 전화번호', style: TextStyle(fontWeight: FontWeight.w700)),
      for (var i = 0; i < _phones.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              SizedBox(
                width: 108,
                child: DropdownButtonFormField<String>(
                  value: _phones[i].kind,
                  items: [
                    for (final k in mesPhoneKinds) DropdownMenuItem(value: k.$1, child: Text(k.$2)),
                  ],
                  onChanged: (v) => setState(() => _phones[i].kind = v ?? 'mobile'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: ValueKey('phone-$i'),
                  initialValue: _phones[i].phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(hintText: _phones[i].kind == 'mobile' ? '010-0000-0000' : '031-000-0000'),
                  onChanged: (v) => _phones[i].phone = formatKoreanPhoneHyphenated(v),
                ),
              ),
              if (_phones.length > 1)
                IconButton(onPressed: () => setState(() => _phones.removeAt(i)), icon: const Icon(Icons.delete_outline)),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _phones.add(MesPhoneRow(kind: _phones.any((p) => p.kind == 'home') ? 'office' : 'home'))),
          icon: const Icon(Icons.add),
          label: const Text('번호 추가'),
        ),
      ),
      DropdownButtonFormField<String>(
        value: _branches.any((b) => '${b['code']}' == _branchCode) ? _branchCode : null,
        items: [
          for (final b in _branches) DropdownMenuItem(value: '${b['code']}', child: Text('${b['name']}')),
        ],
        onChanged: (v) => setState(() {
          _branchCode = v ?? _branchCode;
          _crews = _crewsOf({'week': {'branches': []}});
        }),
        decoration: const InputDecoration(labelText: '지점 *'),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('영업 담당자'),
        subtitle: Text(_salesUserName.isEmpty ? _salesUserId : _salesUserName),
      ),
      const Text('희망 시공일', style: TextStyle(fontWeight: FontWeight.w700)),
      const Text('날짜마다 팀을 다르게 넣을 수 있습니다.', style: TextStyle(fontSize: 12)),
      for (var i = 0; i < _installDays.length; i++) _installDayTile(i),
      TextButton.icon(
        onPressed: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: now,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 3),
          );
          if (picked == null) return;
          final ymd = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          setState(() => _installDays.add(MesInstallDay(date: ymd, slots: [1])));
        },
        icon: const Icon(Icons.calendar_month),
        label: const Text('시공일 추가'),
      ),
    ];
  }

  Widget _installDayTile(int i) {
    final day = _installDays[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(day.date, style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(onPressed: () => setState(() => _installDays.removeAt(i)), icon: const Icon(Icons.close)),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final c in _crews)
                  FilterChip(
                    label: Text('${c['name']}'),
                    selected: day.slots.contains(c['slot']),
                    onSelected: (on) => setState(() {
                      final slot = int.tryParse('${c['slot']}') ?? 0;
                      if (on) {
                        if (!day.slots.contains(slot)) day.slots.add(slot);
                      } else {
                        day.slots.remove(slot);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _productStep() {
    return [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => setState(() => _items.add(MesItemRow())),
          icon: const Icon(Icons.add),
          label: const Text('행 추가'),
        ),
      ),
      for (var i = 0; i < _items.length; i++) _itemCard(i),
      TextField(controller: _mfgNote, maxLines: 3, decoration: const InputDecoration(labelText: '제조 특이사항')),
      TextField(controller: _installNote, maxLines: 3, decoration: const InputDecoration(labelText: '시공 특이사항')),
    ];
  }

  Widget _itemCard(int i) {
    final it = _items[i];
    final models = _modelsFor(it.categoryId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text('${i + 1}')),
                const Spacer(),
                IconButton(
                  tooltip: '복사',
                  onPressed: () => setState(() => _items.insert(i + 1, it.copy())),
                  icon: const Icon(Icons.copy),
                ),
                if (_items.length > 1)
                  IconButton(
                    onPressed: () => setState(() {
                      _items.removeAt(i);
                      _applyBom();
                    }),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const Text('카테고리 *'),
            Wrap(
              spacing: 8,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    label: Text('${c['name']}'),
                    selected: it.categoryId == '${c['id']}',
                    onSelected: (_) {
                      it.categoryId = '${c['id']}';
                      it.productId = '';
                      it.options = mesMergeOptions(_defsFor(it.categoryId), []);
                      _applyBom();
                      setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('모델 *'),
            if (it.categoryId.isEmpty && _categories.isNotEmpty)
              const Text('카테고리를 먼저 고르세요.', style: TextStyle(fontSize: 12))
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final p in models)
                    ChoiceChip(
                      label: Text('${p['name'] ?? p['code']}'),
                      selected: it.productId == '${p['id']}',
                      onSelected: (_) {
                        it.productId = '${p['id']}';
                        it.categoryId = '${p['category_id'] ?? p['mes_product_categories']?['id'] ?? it.categoryId}';
                        it.options = mesMergeOptions(_defsFor(it.categoryId), it.options);
                        final colors = p['mes_product_colors'];
                        if (colors is List && colors.isNotEmpty && it.color.isEmpty) {
                          it.color = '${colors.first['color'] ?? colors.first['name'] ?? ''}';
                        }
                        _applyBom();
                        setState(() {});
                      },
                    ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: it.qty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '수량'),
                    onChanged: (v) {
                      it.qty = v;
                      _applyBom();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: it.widthMm,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: '너비 mm'),
                    onChanged: (v) => it.widthMm = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: it.heightMm,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: '높이 mm'),
                    onChanged: (v) => it.heightMm = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in mesMotorOptions)
                  ChoiceChip(
                    label: Text(m.$2),
                    selected: it.motor == m.$1,
                    onSelected: (_) => setState(() => it.motor = m.$1),
                  ),
              ],
            ),
            for (final d in _defsFor(it.categoryId))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextFormField(
                  initialValue: () {
                    for (final o in it.options) {
                      if (o.name == d.name) return o.value;
                    }
                    return d.fallback;
                  }(),
                  decoration: InputDecoration(labelText: d.required ? '${d.name} *' : d.name),
                  onChanged: (v) {
                    final row = it.options.where((o) => o.name == d.name);
                    if (row.isEmpty) {
                      it.options.add(MesOptionRow(name: d.name, value: v));
                    } else {
                      row.first.value = v;
                    }
                  },
                ),
              ),
            TextFormField(
              initialValue: it.remark,
              decoration: const InputDecoration(labelText: '품목 비고'),
              onChanged: (v) => it.remark = v,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sensorStep() {
    final sensors = _mats.where((m) => mesIsSensor(label: m.label)).toList();
    return [
      const Text('모델에 포함된 센서가 자동으로 들어옵니다. 수량을 바꾸거나 센서를 더 넣을 수 있습니다.'),
      if (sensors.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('선택한 센서가 없습니다.'))),
      for (final m in _mats)
        if (mesIsSensor(label: m.label))
          ListTile(
            title: Text(m.label),
            subtitle: m.fromBom ? const Text('기본') : null,
            trailing: SizedBox(
              width: 168,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: m.qty,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => m.qty = v,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _mats.remove(m)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      DropdownButtonFormField<String>(
        hint: const Text('센서 추가…'),
        items: [
          for (final m in _materials.where((m) => mesIsSensor(kind: '${m['kind']}', code: '${m['code']}', name: '${m['name']}') && !_mats.any((x) => x.materialId == '${m['id']}')))
            DropdownMenuItem(value: '${m['id']}', child: Text('${m['code']} ${m['name']}')),
        ],
        onChanged: (id) {
          if (id == null) return;
          final m = _materials.cast<Map?>().firstWhere((x) => '${x?['id']}' == id, orElse: () => null);
          if (m == null) return;
          setState(() {
            _mats.add(MesMatRow(materialId: id, qty: '1', fromBom: false, label: '${m['code']} ${m['name']}'));
          });
        },
      ),
      TextButton(onPressed: _precheck, child: const Text('재고 확인')),
      for (final s in _shortage)
        Text('${s['code']} ${s['name']} — 필요 ${s['requiredQty']} / 재고 ${s['availableQty']}', style: const TextStyle(color: Colors.red)),
    ];
  }

  Future<void> _precheck() async {
    final res = await _repo.post('/api/orders/precheck', {
      'materials': [
        for (final m in _mats) {'materialId': m.materialId, 'qty': int.tryParse(m.qty) ?? 0},
      ],
    });
    setState(() => _shortage = _list(res, 'shortage'));
  }

  List<Widget> _photoStep() {
    return [
      const Text('현장도면, 시공전 사진 등을 종류별로 올립니다.'),
      for (final cat in _photoCats) ...[
        ListTile(
          title: Text('${cat['name'] ?? cat['code']}'),
          trailing: IconButton(onPressed: () => _addPhotos('${cat['code']}'), icon: const Icon(Icons.add_a_photo_outlined)),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final p in _photos.where((p) => p.category == '${cat['code']}'))
              Stack(
                children: [
                  if (p.localPath != null)
                    Image.file(File(p.localPath!), width: 88, height: 88, fit: BoxFit.cover)
                  else
                    Container(width: 88, height: 88, color: Colors.black12, child: const Icon(Icons.image)),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _photos.remove(p)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _payStep() {
    final contract = mesWonDigits(_amount.text);
    _pays = mesSyncBalance(_pays, contract);
    final total = _pays.fold<int>(0, (s, p) => s + mesWonDigits(p.amount));
    return [
      TextField(
        controller: _amount,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '계약 금액'),
        onChanged: (_) => setState(() {}),
      ),
      SwitchListTile(
        title: const Text('VAT 포함'),
        value: _vat,
        onChanged: (v) => setState(() => _vat = v),
      ),
      const Text('계약 서류'),
      Wrap(
        spacing: 8,
        children: [
          for (final c in mesContractTypes)
            FilterChip(
              label: Text(c.$2),
              selected: _contractTypes.contains(c.$1),
              onSelected: (on) => setState(() {
                if (on) {
                  _contractTypes.add(c.$1);
                } else {
                  _contractTypes.remove(c.$1);
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text('수금 합계 ${mesFormatWon(total)}원 · 계약금액 ${mesFormatWon(contract)}원'),
      for (var i = 0; i < _pays.length; i++) _payCard(i),
      TextButton.icon(
        onPressed: () => setState(() => _pays.insert(_pays.length - 1, MesPayRow(kind: 'INTERIM', payBank: _branchCode))),
        icon: const Icon(Icons.add),
        label: const Text('중도금 추가'),
      ),
      TextField(controller: _remark, maxLines: 2, decoration: const InputDecoration(labelText: '비고')),
    ];
  }

  Widget _payCard(int i) {
    final p = _pays[i];
    final isBalance = p.kind == 'BALANCE';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (isBalance)
              const Align(alignment: Alignment.centerLeft, child: Text('잔금', style: TextStyle(fontWeight: FontWeight.w800)))
            else
              DropdownButtonFormField<String>(
                value: p.kind,
                items: [
                  for (final k in mesPayKinds.where((k) => k.$1 != 'BALANCE')) DropdownMenuItem(value: k.$1, child: Text(k.$2)),
                ],
                onChanged: (v) => setState(() => p.kind = v ?? p.kind),
              ),
            TextFormField(
              initialValue: p.amount.isEmpty ? '' : mesFormatWon(mesWonDigits(p.amount)),
              enabled: !isBalance,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '금액'),
              onChanged: (v) => setState(() {
                p.amount = '${mesWonDigits(v)}';
                _pays = mesSyncBalance(_pays, mesWonDigits(_amount.text));
              }),
            ),
            if (!isBalance)
              Wrap(
                spacing: 6,
                children: [
                  for (final pct in mesPayPercentPresets)
                    ActionChip(
                      label: Text('$pct%'),
                      onPressed: () => setState(() {
                        p.amount = mesAmountFromPercent(mesWonDigits(_amount.text), pct);
                        _pays = mesSyncBalance(_pays, mesWonDigits(_amount.text));
                      }),
                    ),
                ],
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.dueDate.isEmpty ? '예정일 선택' : p.dueDate),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 3));
                if (picked == null) return;
                setState(() {
                  p.dueDate =
                      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                });
              },
            ),
            DropdownButtonFormField<String>(
              value: p.payType,
              items: [for (final t in mesPayTypes) DropdownMenuItem(value: t.$1, child: Text(t.$2))],
              onChanged: (v) => setState(() => p.payType = v ?? p.payType),
              decoration: const InputDecoration(labelText: '결제 유형'),
            ),
          ],
        ),
      ),
    );
  }
}
